#!/bin/sh
# Pick a region, then record it. slurp must run outside the shell process.
g=$(slurp) || exit 0
exec qs ipc call recorder geometry "$g"
