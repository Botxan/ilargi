#!/usr/bin/env python3
"""Google Calendar + Tasks for the Almanac (standard library only).

    gcal2json.py --auth      one-time browser authorisation
    gcal2json.py             fetch into ~/.cache/ilargi/calendar.json
    gcal2json.py add-event | save-event | delete-event | add-task | save-task | set-task | delete-task

Needs a Desktop-app OAuth client from Google Cloud Console saved as
~/.local/state/ilargi/google-oauth-client.json; --auth writes the token next to it.
"""
import base64
import hashlib
import http.server
import json
import os
import secrets
import subprocess
import sys
import threading
import urllib.error
import urllib.parse
import urllib.request
from datetime import date, datetime, timedelta

HOME = os.path.expanduser("~")
STATE = os.path.join(os.environ.get("XDG_STATE_HOME") or os.path.join(HOME, ".local/state"), "ilargi")
CACHE = os.path.join(os.environ.get("XDG_CACHE_HOME") or os.path.join(HOME, ".cache"), "ilargi")
CLIENT = os.path.join(STATE, "google-oauth-client.json")
TOKEN = os.path.join(STATE, "google-token.json")
OUT = os.path.join(CACHE, "calendar.json")

SCOPE = " ".join([
    "https://www.googleapis.com/auth/calendar.readonly",
    "https://www.googleapis.com/auth/calendar.events",
    "https://www.googleapis.com/auth/tasks",
])
AUTH_URL = "https://accounts.google.com/o/oauth2/v2/auth"
TOKEN_URL = "https://oauth2.googleapis.com/token"
API = "https://www.googleapis.com/calendar/v3"
TASKS = "https://tasks.googleapis.com/tasks/v1"

BACK_DAYS = 45
FWD_DAYS = 120


def emit(events, ok, note, tasks=None, calendars=None):
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    tmp = OUT + ".tmp"
    with open(tmp, "w") as fh:
        json.dump({"updated": datetime.now().strftime("%Y-%m-%dT%H:%M:%S"),
                   "ok": ok, "note": note, "events": events,
                   "tasks": tasks or [], "calendars": calendars or [],
                   "taskLists": TASK_LISTS}, fh)
    os.replace(tmp, OUT)   # atomic, so a watching FileView never sees half a file


def write_private(path, obj):
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w") as fh:
        json.dump(obj, fh)
    os.chmod(path, 0o600)


def client():
    with open(CLIENT) as fh:
        c = json.load(fh)
    c = c.get("installed") or c.get("web") or c
    return c["client_id"], c["client_secret"]


def post(url, fields):
    data = urllib.parse.urlencode(fields).encode()
    req = urllib.request.Request(url, data=data, method="POST",
                                 headers={"Content-Type": "application/x-www-form-urlencoded"})
    with urllib.request.urlopen(req, timeout=25) as resp:
        return json.load(resp)


def authorise():
    cid, csecret = client()
    verifier = secrets.token_urlsafe(64)
    challenge = base64.urlsafe_b64encode(hashlib.sha256(verifier.encode()).digest()).rstrip(b"=").decode()
    state = secrets.token_urlsafe(16)
    got = {}

    class Handler(http.server.BaseHTTPRequestHandler):
        def do_GET(self):
            q = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query)
            if q.get("state", [""])[0] == state:
                got.update({k: v[0] for k, v in q.items()})
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.end_headers()
            msg = "Done, you can close this tab." if "code" in got else "No authorisation received."
            self.wfile.write(("<html><body style='font-family:sans-serif;background:#0c0e0f;color:#edeff0'>"
                              "<h2>%s</h2></body></html>" % msg).encode())

        def log_message(self, *a):
            pass

    srv = http.server.HTTPServer(("127.0.0.1", 0), Handler)
    redirect = "http://127.0.0.1:%d" % srv.server_port
    url = AUTH_URL + "?" + urllib.parse.urlencode({
        "client_id": cid, "redirect_uri": redirect, "response_type": "code",
        "scope": SCOPE, "access_type": "offline", "prompt": "consent",
        "code_challenge": challenge, "code_challenge_method": "S256", "state": state,
    })
    print("Opening the browser to authorise Google Calendar and Google Tasks.")
    print("If it does not open, visit:\n" + url, flush=True)
    subprocess.Popen(["xdg-open", url], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    t = threading.Thread(target=srv.handle_request)
    t.start()
    t.join(timeout=300)
    srv.server_close()
    if "code" not in got:
        print("No authorisation code received (%s)." % got.get("error", "timed out"))
        return 1
    tok = post(TOKEN_URL, {"code": got["code"], "client_id": cid, "client_secret": csecret,
                           "redirect_uri": redirect, "grant_type": "authorization_code",
                           "code_verifier": verifier})
    if "refresh_token" not in tok:
        print("Google returned no refresh_token: %s" % tok)
        return 1
    write_private(TOKEN, {"refresh_token": tok["refresh_token"]})
    print("Authorised. Token saved to %s (mode 600)." % TOKEN)
    return 0


def access_token():
    cid, csecret = client()
    with open(TOKEN) as fh:
        refresh = json.load(fh)["refresh_token"]
    tok = post(TOKEN_URL, {"client_id": cid, "client_secret": csecret,
                           "refresh_token": refresh, "grant_type": "refresh_token"})
    return tok["access_token"]


def get(path, token, params=None, base=API):
    url = base + path + ("?" + urllib.parse.urlencode(params) if params else "")
    req = urllib.request.Request(url, headers={"Authorization": "Bearer " + token})
    with urllib.request.urlopen(req, timeout=25) as resp:
        return json.load(resp)


def send(method, url, token, body=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method,
                                 headers={"Authorization": "Bearer " + token,
                                          "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=25) as resp:
            raw = resp.read()
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as exc:
        try:
            msg = json.load(exc).get("error", {}).get("message", "")
        except Exception:
            msg = ""
        sys.stderr.write("Google %d: %s\n" % (exc.code, msg or exc.reason))
        sys.exit(1)


def local(ts):
    """RFC 3339 with offset -> local wall-clock string."""
    dt = datetime.fromisoformat(ts.replace("Z", "+00:00"))
    return dt.astimezone().strftime("%Y-%m-%dT%H:%M:%S")


RRULE_DAYS = ["MO", "TU", "WE", "TH", "FR", "SA", "SU"]


def parse_repeat(rules):
    """Google recurrence lines -> the editor's simple shape.

    {"freq": "DAILY|WEEKLY|MONTHLY|YEARLY|WEEKDAYS|custom", "count": n,
     "until": "YYYY-MM-DD", "raw": [...]}. Anything the editor cannot express
    (BYSETPOS, INTERVAL>1, EXDATE...) is "custom" and is left untouched on save
    unless the user picks another repeat.
    """
    rr = [r for r in rules if r.startswith("RRULE:")]
    out = {"freq": "custom", "count": 0, "until": "", "raw": rules}
    if len(rr) != 1:
        return out
    parts = dict(p.split("=", 1) for p in rr[0][6:].split(";") if "=" in p)
    freq = parts.pop("FREQ", "")
    if "COUNT" in parts:
        out["count"] = int(parts.pop("COUNT"))
    if "UNTIL" in parts:
        u = parts.pop("UNTIL")
        out["until"] = "%s-%s-%s" % (u[0:4], u[4:6], u[6:8])
    parts.pop("WKST", None)
    if parts.get("INTERVAL") == "1":
        parts.pop("INTERVAL")
    byday = parts.pop("BYDAY", None)
    if freq == "WEEKLY" and byday == "MO,TU,WE,TH,FR":
        freq = "WEEKDAYS"
    elif freq == "WEEKLY" and byday and "," not in byday:
        pass                                 # weekly on the start's own weekday
    elif byday:
        return out
    if parts or freq not in ("DAILY", "WEEKLY", "MONTHLY", "YEARLY", "WEEKDAYS"):
        return out
    out["freq"] = freq
    return out


def reminder_minutes(ev, cal, all_day=False):
    """Popup reminders as minutes-before, resolving 'use the calendar default'.

    All-day events follow Google's separate all-day defaults, which the API
    does not expose, so those resolve to nothing rather than to a guess."""
    r = ev.get("reminders") or {}
    if r.get("useDefault", True):
        if all_day:
            return [], True
        src = cal.get("defaultReminders", []) if cal else []
        return sorted({x["minutes"] for x in src if x.get("method") == "popup"}), True
    return sorted({x["minutes"] for x in r.get("overrides", []) if x.get("method") == "popup"}), False


def convert(ev, source, cal_id="", cal=None, masters=None):
    s, e = ev.get("start", {}), ev.get("end", {})
    if "date" in s:                      # all-day; end date is exclusive
        sd = date.fromisoformat(s["date"])
        ed = date.fromisoformat(e.get("date", s["date"]))
        if ed <= sd:
            ed = sd + timedelta(days=1)
        start = sd.strftime("%Y-%m-%dT00:00:00")
        end = ed.strftime("%Y-%m-%dT00:00:00")
        day, all_day = sd.strftime("%Y-%m-%d"), True
    else:
        start = local(s["dateTime"])
        end = local(e.get("dateTime", s["dateTime"]))
        day, all_day = start[:10], False
    mins, use_default = reminder_minutes(ev, cal, all_day)
    rid = ev.get("recurringEventId", "")
    master = (masters or {}).get(rid)
    repeat = parse_repeat(master.get("recurrence", [])) if master else None
    writable = bool(cal) and cal.get("accessRole") in ("owner", "writer")
    return {"title": ev.get("summary", "(untitled)"), "start": start, "end": end,
            "day": day, "allDay": all_day, "location": ev.get("location", ""),
            "description": ev.get("description", ""),
            "source": source, "color": "",
            "id": ev.get("id", ""), "calendar": cal_id,
            "recurringId": rid, "repeat": repeat,
            "reminders": mins, "remindersDefault": use_default,
            "writable": writable, "link": ev.get("htmlLink", "")}


def main():
    if "--auth" in sys.argv:
        return authorise()
    if not os.path.exists(CLIENT) or not os.path.exists(TOKEN):
        emit([], False, "no config: see README (Google Calendar)")
        return 0
    try:
        token = access_token()
    except urllib.error.HTTPError as exc:
        emit([], False, "auth failed (%s): run scripts/gcal2json.py --auth" % exc.code)
        return 0
    except Exception as exc:
        emit([], False, "auth failed: %s" % exc)
        return 0

    now = datetime.now().astimezone()
    lo = (now - timedelta(days=BACK_DAYS)).isoformat()
    hi = (now + timedelta(days=FWD_DAYS)).isoformat()
    events, problems, calendars = [], [], []
    try:
        cals = get("/users/me/calendarList", token, {"minAccessRole": "reader"}).get("items", [])
    except Exception as exc:
        emit([], False, "calendar list: %s" % exc)
        return 0
    for cal in cals:
        if not cal.get("selected", True) or cal.get("hidden"):
            continue
        name = cal.get("summaryOverride") or cal.get("summary", "Calendar")
        if cal.get("primary") and "@" in name:
            name = "Personal"          # Google names the primary calendar after the address
        calendars.append({"id": cal["id"], "name": name, "primary": bool(cal.get("primary")),
                          "writable": cal.get("accessRole") in ("owner", "writer"),
                          "timeZone": cal.get("timeZone", ""),
                          "defaultReminders": sorted({x["minutes"] for x in cal.get("defaultReminders", [])
                                                      if x.get("method") == "popup"})})
        page = None
        try:
            masters, mpage = {}, None
            while True:
                mp = {"timeMin": lo, "timeMax": hi, "singleEvents": "false", "maxResults": "2500"}
                if mpage:
                    mp["pageToken"] = mpage
                mres = get("/calendars/%s/events" % urllib.parse.quote(cal["id"], safe=""), token, mp)
                for m in mres.get("items", []):
                    if m.get("recurrence"):
                        masters[m["id"]] = m
                mpage = mres.get("nextPageToken")
                if not mpage:
                    break
            while True:
                params = {"timeMin": lo, "timeMax": hi, "singleEvents": "true",
                          "orderBy": "startTime", "maxResults": "2500"}
                if page:
                    params["pageToken"] = page
                res = get("/calendars/%s/events" % urllib.parse.quote(cal["id"], safe=""), token, params)
                for ev in res.get("items", []):
                    if ev.get("status") == "cancelled":
                        continue
                    events.append(convert(ev, name, cal["id"], cal, masters))
                page = res.get("nextPageToken")
                if not page:
                    break
        except Exception as exc:
            problems.append("%s: %s" % (name, exc))
    events.sort(key=lambda e: (e["start"], e["title"]))
    tasks = []
    try:
        tasks = fetch_tasks(token)
    except Exception as exc:
        problems.append("tasks: %s" % exc)
    emit(events, not problems, "; ".join(problems), tasks, calendars)
    return 0


TASK_LISTS = []


def fetch_tasks(token):
    """Open tasks, plus ones completed in the last day so a tick can be undone."""
    out = []
    since = (datetime.now().astimezone() - timedelta(days=1)).isoformat()
    lists = get("/users/@me/lists", token, {"maxResults": "100"}, TASKS).get("items", [])
    TASK_LISTS[:] = [{"id": l["id"], "title": l.get("title", "")} for l in lists]
    for lst in lists:
        for completed in (False, True):
            page = None
            while True:
                p = {"showCompleted": "true" if completed else "false",
                     "showHidden": "true", "maxResults": "100"}
                if completed:
                    p["completedMin"] = since
                if page:
                    p["pageToken"] = page
                res = get("/lists/%s/tasks" % urllib.parse.quote(lst["id"], safe=""), token, p, TASKS)
                for t in res.get("items", []):
                    if completed != (t.get("status") == "completed"):
                        continue
                    if not t.get("title", "").strip():
                        continue
                    out.append({"id": t["id"], "list": lst["id"], "listTitle": lst.get("title", ""),
                                "parent": t.get("parent", ""),
                                "title": t.get("title", ""), "notes": t.get("notes", ""),
                                "due": (t.get("due") or "")[:10],
                                "done": t.get("status") == "completed",
                                "position": t.get("position", "")})
                page = res.get("nextPageToken")
                if not page:
                    break
    out.sort(key=lambda t: (t["done"], t["due"] or "9999", t["position"]))
    return out


def save_task(p, token):
    """Create or edit a Google Task. p: list, id ("" = new), title, notes,
    due ("YYYY-MM-DD" or "" for none), parent (new subtask), toList (move)."""
    q = lambda x: urllib.parse.quote(x, safe="")
    lst = p.get("list") or "@default"
    body = {"title": p.get("title", ""), "notes": p.get("notes", "")}
    body["due"] = (p["due"] + "T00:00:00.000Z") if p.get("due") else None
    tid = p.get("id", "")
    if not tid:
        url = TASKS + "/lists/%s/tasks" % q(lst)
        if p.get("parent"):
            url += "?parent=" + q(p["parent"])
        if body["due"] is None:
            del body["due"]
        send("POST", url, token, body)
        return
    send("PATCH", TASKS + "/lists/%s/tasks/%s" % (q(lst), q(tid)), token, body)
    dest = p.get("toList", "")
    if dest and dest != lst:
        send("POST", TASKS + "/lists/%s/tasks/%s/move?destinationTasklist=%s" % (q(lst), q(tid), q(dest)), token)


def build_rrule(rep, all_day):
    """The editor's repeat shape -> a recurrence list ([] = does not repeat)."""
    freq = rep.get("freq", "none")
    if freq in ("none", "", None):
        return []
    rule = "RRULE:FREQ=" + ("WEEKLY;BYDAY=MO,TU,WE,TH,FR" if freq == "WEEKDAYS" else freq)
    if rep.get("count"):
        rule += ";COUNT=%d" % int(rep["count"])
    elif rep.get("until"):
        u = date.fromisoformat(rep["until"])
        if all_day:
            rule += ";UNTIL=" + u.strftime("%Y%m%d")
        else:                              # the end of that local day, in UTC
            end = datetime(u.year, u.month, u.day, 23, 59, 59).astimezone()
            from datetime import timezone
            rule += ";UNTIL=" + end.astimezone(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    return [rule]


def save_event(p, token):
    """Create or edit one event. p is the Almanac editor's JSON:

    calendar, origCalendar, id, recurringId, scope ("this"|"all"), title,
    location, description, allDay, date, endDate (all-day, inclusive),
    start/end "HH:MM", origStart (local ISO of the occurrence being edited),
    repeat ({freq,count,until} or null = leave as is), reminders ([min] or
    null = calendar default).
    """
    q = lambda x: urllib.parse.quote(x, safe="")
    cal = p.get("calendar") or "primary"
    try:
        entry = get("/users/me/calendarList/%s" % q(cal), token)
    except Exception:
        entry = {}
    tz = entry.get("timeZone", "")
    day = date.fromisoformat(p["date"])

    def when(d, hm):
        h, m = map(int, hm.split(":"))
        o = {"dateTime": datetime(d.year, d.month, d.day, h, m).strftime("%Y-%m-%dT%H:%M:%S")}
        if tz:
            o["timeZone"] = tz
        else:
            o["dateTime"] = datetime(d.year, d.month, d.day, h, m).astimezone().isoformat()
        return o

    if p.get("allDay"):
        last = date.fromisoformat(p.get("endDate") or p["date"])
        if last < day:
            last = day
        start, end = {"date": day.isoformat()}, {"date": (last + timedelta(days=1)).isoformat()}
    else:
        start = when(day, p["start"])
        sh, sm = map(int, p["start"].split(":")); eh, em = map(int, p["end"].split(":"))
        end = when(day + timedelta(days=1) if eh * 60 + em <= sh * 60 + sm else day, p["end"])
    body = {"summary": p.get("title", ""), "location": p.get("location", ""),
            "description": p.get("description", ""), "start": start, "end": end}
    rem = p.get("reminders")
    if rem is None and p.get("recurringId") and p.get("scope", "this") == "this":
        rem = [x["minutes"] for x in entry.get("defaultReminders", []) if x.get("method") == "popup"]
    body["reminders"] = ({"useDefault": True, "overrides": []} if rem is None else
                         {"useDefault": False,
                          "overrides": [{"method": "popup", "minutes": int(m)} for m in rem[:5]]})
    rep = p.get("repeat")

    eid, series, scope = p.get("id", ""), p.get("recurringId", ""), p.get("scope", "this")
    orig_cal = p.get("origCalendar") or cal

    if not eid:                                       # new event
        if rep is not None:
            rr = build_rrule(rep, p.get("allDay"))
            if rr:
                body["recurrence"] = rr
        send("POST", API + "/calendars/%s/events" % q(cal), token, body)
        return

    target = series if (series and scope == "all") else eid
    if orig_cal != cal and not (series and scope == "this"):
        send("POST", API + "/calendars/%s/events/%s/move?destination=%s"
             % (q(orig_cal), q(target), q(cal)), token)

    if series and scope == "all":
        master = get("/calendars/%s/events/%s" % (q(cal), q(series)), token)
        ms = master.get("start", {})
        o = datetime.fromisoformat(p.get("origStart") or (p["date"] + "T00:00:00"))
        if p.get("allDay") and "date" in ms:
            md = date.fromisoformat(ms["date"]) + (day - o.date())
            span = (date.fromisoformat(end["date"]) - day)
            body["start"], body["end"] = {"date": md.isoformat()}, {"date": (md + span).isoformat()}
        elif not p.get("allDay") and "dateTime" in ms:
            n = datetime.fromisoformat(start["dateTime"][:19])
            ne = datetime.fromisoformat(end["dateTime"][:19])
            mloc = datetime.fromisoformat(local(ms["dateTime"]))
            ns = mloc + (n - o)
            body["start"] = {"dateTime": ns.strftime("%Y-%m-%dT%H:%M:%S")}
            body["end"] = {"dateTime": (ns + (ne - n)).strftime("%Y-%m-%dT%H:%M:%S")}
            if tz:
                body["start"]["timeZone"] = body["end"]["timeZone"] = tz
            else:
                body["start"]["dateTime"] = ns.astimezone().isoformat()
                body["end"]["dateTime"] = (ns + (ne - n)).astimezone().isoformat()
        else:                                          # all-day <-> timed: keep the series' first day
            first = date.fromisoformat(ms.get("date") or local(ms["dateTime"])[:10])
            if p.get("allDay"):
                span = date.fromisoformat(end["date"]) - day
                body["start"], body["end"] = {"date": first.isoformat()}, {"date": (first + span).isoformat()}
            else:
                body["start"] = when(first, p["start"])
                body["end"] = when(first + (date.fromisoformat(end["dateTime"][:10]) - day), p["end"])
        if rep is not None:
            body["recurrence"] = build_rrule(rep, p.get("allDay"))
    elif not series and rep is not None:
        rr = build_rrule(rep, p.get("allDay"))
        if rr:
            body["recurrence"] = rr                    # a single event becomes a series
    send("PATCH", API + "/calendars/%s/events/%s" % (q(cal), q(target)), token, body)


def write(argv):
    import argparse
    ap = argparse.ArgumentParser(prog="gcal2json.py")
    sub = ap.add_subparsers(dest="cmd", required=True)
    a = sub.add_parser("add-event")
    a.add_argument("--title", required=True); a.add_argument("--date", required=True)
    a.add_argument("--start"); a.add_argument("--end")
    a.add_argument("--calendar", default="primary")
    se = sub.add_parser("save-event")
    se.add_argument("--json", required=True)
    d = sub.add_parser("delete-event")
    d.add_argument("--calendar", default="primary"); d.add_argument("--id", required=True)
    d.add_argument("--series", default="")   # recurringEventId: delete the whole series
    t = sub.add_parser("add-task")
    t.add_argument("--title", required=True); t.add_argument("--due"); t.add_argument("--list", default="@default")
    sv = sub.add_parser("save-task")
    sv.add_argument("--json", required=True)
    st = sub.add_parser("set-task")
    st.add_argument("--list", required=True); st.add_argument("--id", required=True)
    st.add_argument("--done", required=True, choices=["0", "1"])
    dt = sub.add_parser("delete-task")
    dt.add_argument("--list", required=True); dt.add_argument("--id", required=True)
    args = ap.parse_args(argv)

    token = access_token()
    q = lambda x: urllib.parse.quote(x, safe="")
    if args.cmd == "add-event":
        day = date.fromisoformat(args.date)
        if args.start:
            sh, sm = map(int, args.start.split(":"))
            s_dt = datetime(day.year, day.month, day.day, sh, sm).astimezone()
            if args.end:
                eh, em = map(int, args.end.split(":"))
                e_dt = datetime(day.year, day.month, day.day, eh, em).astimezone()
                if e_dt <= s_dt:
                    e_dt += timedelta(days=1)       # ends after midnight
            else:
                e_dt = s_dt + timedelta(hours=1)
            body = {"summary": args.title,
                    "start": {"dateTime": s_dt.isoformat()}, "end": {"dateTime": e_dt.isoformat()}}
        else:
            body = {"summary": args.title, "start": {"date": day.isoformat()},
                    "end": {"date": (day + timedelta(days=1)).isoformat()}}
        send("POST", API + "/calendars/%s/events" % q(args.calendar), token, body)
    elif args.cmd == "save-event":
        save_event(json.loads(args.json), token)
    elif args.cmd == "delete-event":
        target = args.series or args.id
        send("DELETE", API + "/calendars/%s/events/%s" % (q(args.calendar), q(target)), token)
    elif args.cmd == "add-task":
        body = {"title": args.title}
        if args.due:
            body["due"] = args.due + "T00:00:00.000Z"
        send("POST", TASKS + "/lists/%s/tasks" % q(args.list), token, body)
    elif args.cmd == "save-task":
        save_task(json.loads(args.json), token)
    elif args.cmd == "set-task":
        body = {"status": "completed"} if args.done == "1" else {"status": "needsAction", "completed": None}
        send("PATCH", TASKS + "/lists/%s/tasks/%s" % (q(args.list), q(args.id)), token, body)
    elif args.cmd == "delete-task":
        send("DELETE", TASKS + "/lists/%s/tasks/%s" % (q(args.list), q(args.id)), token)
    return main()


if __name__ == "__main__":
    if len(sys.argv) > 1 and not sys.argv[1].startswith("--"):
        sys.exit(write(sys.argv[1:]))
    sys.exit(main())
