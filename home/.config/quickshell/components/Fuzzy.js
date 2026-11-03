.pragma library

function score(query, text) {
    if (!query) return { score: 0, positions: [] };
    if (!text) return null;

    var q = query.toLowerCase();
    var t = text.toLowerCase();

    var positions = [];
    var ti = 0;
    var total = 0;
    var streak = 0;

    for (var qi = 0; qi < q.length; qi++) {
        var ch = q[qi];
        var found = -1;
        while (ti < t.length) {
            if (t[ti] === ch) { found = ti; break; }
            ti++;
        }
        if (found < 0) return null;

        var pts = 1;

        var prev = found > 0 ? t[found - 1] : " ";
        if (found === 0 || prev === " " || prev === "-" || prev === "_"
            || prev === "/" || prev === "." || prev === ":") {
            pts += 6;
        }

        if (positions.length > 0 && found === positions[positions.length - 1] + 1) {
            streak++;
            pts += 3 + streak;
        } else {
            streak = 0;
        }

        pts += Math.max(0, 4 - Math.floor(found / 8));

        if (text[found] === query[qi]) pts += 1;

        total += pts;
        positions.push(found);
        ti = found + 1;
    }

    total += Math.max(0, 12 - Math.floor(text.length / 6));

    return { score: total, positions: positions };
}

function highlight(text, positions, color) {
    if (!positions || positions.length === 0) return escapeHtml(text);
    var set = {};
    for (var i = 0; i < positions.length; i++) set[positions[i]] = true;

    var out = "";
    var open = false;
    for (var c = 0; c < text.length; c++) {
        var want = set[c] === true;
        if (want && !open) { out += '<span style="color:' + color + '">'; open = true; }
        else if (!want && open) { out += "</span>"; open = false; }
        out += escapeHtml(text[c]);
    }
    if (open) out += "</span>";
    return out;
}

function escapeHtml(s) {
    return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}

function highlightClamped(text, positions, color, maxLen) {
    if (text.length <= maxLen) return highlight(text, positions, color);

    var cut = text.substring(0, maxLen - 1);
    var kept = [];
    if (positions) {
        for (var i = 0; i < positions.length; i++) {
            if (positions[i] < cut.length) kept.push(positions[i]);
        }
    }
    return highlight(cut, kept, color) + "…";
}
