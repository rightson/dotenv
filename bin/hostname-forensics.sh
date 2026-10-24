#!/bin/bash
# hostname-forensics.sh — find when/why macOS hostname (LocalHostName / ComputerName / HostName) changed.
# Usage: hostname-forensics.sh [lookback, default 2d]   e.g. 12h, 3d
set -u
LOOKBACK="${1:-2d}"
LOG=/usr/bin/log   # zsh has a `log` builtin; always call the real binary

hr() { printf '\n==== %s ====\n' "$1"; }

hr "Current names"
for k in HostName LocalHostName ComputerName; do
  printf '%-14s %s\n' "$k:" "$(scutil --get "$k" 2>&1)"
done
printf '%-14s %s\n' "hostname:" "$(hostname)"
printf '%-14s %s\n' "plist mtime:" "$(stat -f '%Sm' /Library/Preferences/SystemConfiguration/preferences.plist)"

hr "Name changes in last $LOOKBACK (who set what, when)"
"$LOG" show --last "$LOOKBACK" --style compact --predicate '
  process != "log" AND (
       eventMessage CONTAINS "attempting to set the local host name"
    OR eventMessage CONTAINS "attempting to set the computer name"
    OR eventMessage CONTAINS "attempting to set the host name"
    OR (process == "configd" AND eventMessage CONTAINS "setting hostname to"))' 2>/dev/null \
  | grep -v '^Timestamp' \
  | sed -E 's/^([0-9-]+ [0-9:.]+) +[A-Za-z]+ +([^[]+)\[[0-9:]+\] \[[^]]*\] /\1  \2  /'

FIRST=$("$LOG" show --last "$LOOKBACK" --style compact \
  --predicate 'process == "mDNSResponder" AND eventMessage CONTAINS "attempting to set the"' 2>/dev/null \
  | grep -v '^Timestamp' | head -1 | awk '{print $1" "$2}' | cut -d. -f1)

if [ -z "$FIRST" ]; then
  echo "(no automatic rename found in last $LOOKBACK)"
  echo "Note: mDNSResponder rename messages are rotated out of the unified log within hours."
  echo "Run this soon after noticing the change, or check names manually above."
  exit 0
fi

# Compute a window: 3 min before first rename → first rename
START=$(date -j -v-3M -f '%Y-%m-%d %H:%M:%S' "$FIRST" '+%Y-%m-%d %H:%M:%S')

TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT

hr "Bonjour conflict evidence ($START → $FIRST)"
"$LOG" show --start "$START" --end "$FIRST" --style compact --predicate '
  process == "mDNSResponder" AND (
       eventMessage CONTAINS[c] "conflict"
    OR eventMessage CONTAINS "Resetting to Probing"
    OR eventMessage CONTAINS "Received from"
    OR eventMessage CONTAINS "Network Configuration Change")' 2>/dev/null \
  | grep -v '^Timestamp' > "$TMP"

echo "conflict-related lines: $(wc -l < "$TMP")"
echo "-- conflicting responders (redacted IP token → count):"
grep -o 'Received from <private> <ip:[^>]*>' "$TMP" | sed 's/.*<ip:/ip:/; s/>//' | sort | uniq -c | sort -rn
echo "-- samples:"
grep -E 'conflict|Resetting to Probing|Network Configuration Change' "$TMP" | awk '!seen[$0]++' | head -8 | cut -c1-200

hr "Network changes ($START → $FIRST)"
"$LOG" show --start "$START" --end "$FIRST" --style compact --predicate '
  process == "configd" AND eventMessage CONTAINS "network changed"' 2>/dev/null | grep -v '^Timestamp' | cut -c1-200

hr "Sleep/wake around that time"
pmset -g log | grep -E "^${FIRST%% *} ${FIRST:11:2}:" | grep -E ' (Sleep|Wake|DarkWake) ' | head -10

hr "Bonjour Sleep Proxies on this LAN (common cause)"
( dns-sd -B _sleep-proxy._udp local. & PID=$!; sleep 3; kill $PID ) 2>/dev/null | awk 'NR>3' | grep -v '^$' || true

hr "Who else answers for the original name right now"
BASE=$(scutil --get LocalHostName | sed -E 's/-[0-9]+$//')
( dns-sd -G v4v6 "$BASE.local" & PID=$!; sleep 3; kill $PID ) 2>/dev/null | awk 'NR>1' || true
echo
echo "Your IPs:"; ifconfig | awk '/inet /&&!/127.0.0.1/{print "  "$2}'
echo
echo "Hint: if '$BASE.local' resolves to an IP that is NOT yours, that device (or a"
echo "sleep proxy holding a stale record) is the conflicting party."
echo "To reveal redacted IPs:  sudo log config --mode 'private_data:on'  (turn off afterwards)"
