#!/bin/zsh
# usage: frames.sh DIR SECONDS — capture the CrossOver original's game window every 3 s.
D=$1; mkdir -p $D; end=$(( $(date +%s) + $2 )); i=0
while [ $(date +%s) -lt $end ]; do
  ids=$(~/.local/bin/cua-driver call list_windows '{}' | python3 -c "
import sys,json
for w in json.load(sys.stdin)['windows']:
  if w['app_name']=='NTSD 2.4.exe' and w['title']=='Little Fighter 2' and w['is_on_screen']: print(w['pid'], w['window_id']); break")
  [ -z "$ids" ] && { echo "no window"; break; }
  pid=${ids%% *}; wid=${ids##* }
  ~/.local/bin/cua-driver call get_window_state "{\"pid\":$pid,\"window_id\":$wid,\"include_accessibility_tree\":false,\"max_image_dimension\":800,\"screenshot_out_file\":\"$PWD/$D/$(printf %04d $i).png\",\"session\":\"${CUA_SESSION:-crossplay}\"}" >/dev/null
  echo "$(printf %04d $i) $(date -u +%T)" >> $D/index.txt; i=$((i+1)); sleep 3
done
