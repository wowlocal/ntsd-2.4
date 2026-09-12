#!/bin/zsh
set -euo pipefail
prototype_root="${0:A:h:h:h}"
prototype_app="$prototype_root/build/l2df-prototype/presentation-20260912/native-01/NTSD L2DF Native.app"
if [[ ! -x "$prototype_app/Contents/MacOS/love" ]]; then
  print -u2 "Prototype app is missing. See prototypes/l2df/README.md."
  exit 1
fi
exec "$prototype_app/Contents/MacOS/love" "$@"
