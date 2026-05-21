#!/bin/bash
# Claude Code Status Line
# Format: 📁 CWD | 🌿 branch | 🧠 mode | ⚡ effort | 📊 ctx% | 📈 5hr% | ⏱️ 5hr-reset | 📅 7day-reset

INPUT=$(cat)

IFS=$'\t' read -r CWD MODE_NAME EFFORT CTX_PCT RATE_5H_PCT RATE_5H_RESET RATE_7D_RESET < <(
  echo "$INPUT" | jq -rj '
    [
      (.cwd // ""),
      (.output_style.name // ""),
      (.effort.level // ""),
      (.context_window.used_percentage // 0 | floor | tostring),
      (.rate_limits.five_hour.used_percentage // 0 | floor | tostring),
      (.rate_limits.five_hour.resets_at // 0 | tostring),
      (.rate_limits.seven_day.resets_at // 0 | tostring)
    ] | join("\t") + "\n"
  '
)

# Git branch (cached 5s, no lock contention)
CACHE="/tmp/.claude-sl-cache"
NOW=${EPOCHSECONDS:-$(printf '%(%s)T' -1 2>/dev/null || date +%s)}
if [[ -f "$CACHE" ]]; then
  IFS=$'\t' read -r CACHED_TIME CACHED_DIR BRANCH < "$CACHE"
  if (( NOW - CACHED_TIME > 5 )) || [[ "$CACHED_DIR" != "$CWD" ]]; then
    BRANCH=$(git --no-optional-locks -C "$CWD" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
    printf '%s\t%s\t%s' "$NOW" "$CWD" "$BRANCH" > "$CACHE"
  fi
else
  BRANCH=$(git --no-optional-locks -C "$CWD" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
  printf '%s\t%s\t%s' "$NOW" "$CWD" "$BRANCH" > "$CACHE"
fi

# Format Unix timestamp as HH:MM countdown
fmt_reset() {
  local ts=$1
  [[ "$ts" == "0" || -z "$ts" ]] && { echo "--:--"; return; }
  # handle millisecond timestamps
  (( ts > 9999999999 )) && ts=$(( ts / 1000 ))
  local diff=$(( ts - NOW ))
  (( diff <= 0 )) && { echo "00:00"; return; }
  printf '%02d:%02d' $(( diff / 3600 )) $(( (diff % 3600) / 60 ))
}

RESET_5H=$(fmt_reset "$RATE_5H_RESET")
RESET_7D=$(fmt_reset "$RATE_7D_RESET")
BASENAME_CWD=$(basename "${CWD}")

PARTS=()
PARTS+=("📁 \033[32m${BASENAME_CWD}\033[0m")
[[ -n "$BRANCH" ]]    && PARTS+=("🌿 \033[36m${BRANCH}\033[0m")
[[ -n "$MODE_NAME" ]] && PARTS+=("🧠 \033[33m${MODE_NAME}\033[0m")
[[ -n "$EFFORT" ]]    && PARTS+=("⚡ \033[33m${EFFORT}\033[0m")
if   (( CTX_PCT < 25 )); then CTX_ICON="🟢"
elif (( CTX_PCT < 50 )); then CTX_ICON="🟡"
elif (( CTX_PCT < 75 )); then CTX_ICON="🟠"
else                          CTX_ICON="🔴"
fi
PARTS+=("${CTX_ICON} \033[35m${CTX_PCT}%\033[0m ctx")
PARTS+=("📈 \033[33m${RATE_5H_PCT}%\033[0m 5h")
PARTS+=("⏱️ \033[36m${RESET_5H}\033[0m 5h")
PARTS+=("📅 \033[36m${RESET_7D}\033[0m 7d")

OUT=""
for part in "${PARTS[@]}"; do
  [[ -n "$OUT" ]] && OUT+=" | "
  OUT+="$part"
done

printf '%b\n' "$OUT"
