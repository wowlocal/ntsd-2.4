#!/bin/sh
# Steam's launcher for the game on the Deck (the non-Steam shortcut's target).
# The game writes its events to stdout; the last run's go to ~/ntsd/last-run.log.
cd "$(dirname "$0")/ntsd-linux-x86_64" || exit 1
exec ./NTSDSDL "$@" > "$HOME/ntsd/last-run.log" 2>&1
