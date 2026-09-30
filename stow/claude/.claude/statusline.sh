#!/usr/bin/env bash
# Claude Code statusline: reads session JSON on stdin, prints 2 lines.
in=$(cat)
j() { jq -r "$1 // empty" <<<"$in" 2>/dev/null; }

R=$'\033[0m'; D=$'\033[2m'; B=$'\033[1m'
C=$'\033[36m'; G=$'\033[32m'; Y=$'\033[33m'; RD=$'\033[31m'; M=$'\033[35m'; BL=$'\033[34m'
SEP="${D} │ ${R}"

pct_color() { # $1 = integer percent
  if   [ "$1" -ge 80 ]; then printf '%s' "$RD"
  elif [ "$1" -ge 50 ]; then printf '%s' "$Y"
  else printf '%s' "$G"; fi
}
bar() { # $1 = percent, $2 = width
  local p=$1 w=$2 f i s=""
  f=$(( (p * w + 50) / 100 )); [ "$f" -gt "$w" ] && f=$w
  for ((i = 0; i < w; i++)); do [ "$i" -lt "$f" ] && s+="█" || s+="░"; done
  printf '%s' "$s"
}
fmt_dur() { # $1 = ms
  local s=$(( $1 / 1000 ))
  if   [ "$s" -ge 3600 ]; then printf '%dh%02dm' $((s / 3600)) $((s % 3600 / 60))
  elif [ "$s" -ge 60 ];   then printf '%dm%02ds' $((s / 60)) $((s % 60))
  else printf '%ds' "$s"; fi
}
fmt_tok() { # $1 = tokens
  awk -v n="$1" 'BEGIN{ if (n>=1000000) printf "%.1fM", n/1000000; else if (n>=1000) printf "%.0fk", n/1000; else printf "%d", n }'
}

model=$(j .model.display_name)
cwd=$(j .workspace.current_dir); [ -z "$cwd" ] && cwd=$(j .cwd)
dir="${cwd/#$HOME/~}"
ver=$(j .version)
style=$(j .output_style.name)
effort=$(j .effort.level)
vim=$(j .vim.mode)
agent=$(j .agent.name)

# ---- line 1: model / dir / git / pr ----
l1=""
[ -n "$model" ] && l1+="${B}${C}◆ ${model}${R}"
[ -n "$effort" ] && l1+=" ${D}(${effort})${R}"
[ -n "$dir" ] && l1+="${SEP}${BL}${dir}${R}"

if [ -n "$cwd" ] && git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1; then
  br=$(git -C "$cwd" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null || git -C "$cwd" --no-optional-locks rev-parse --short HEAD 2>/dev/null)
  st=$(git -C "$cwd" --no-optional-locks status --porcelain=v1 -b 2>/dev/null)
  staged=$(grep -c '^[MADRC]' <<<"$st")
  modified=$(grep -c '^.[MD]' <<<"$st")
  untracked=$(grep -c '^??' <<<"$st")
  ahead=$(sed -n '1s/.*ahead \([0-9]*\).*/\1/p' <<<"$st")
  behind=$(sed -n '1s/.*behind \([0-9]*\).*/\1/p' <<<"$st")
  g=" ${M}${br}${R}"
  [ "$staged" -gt 0 ]    && g+=" ${G}+${staged}${R}"
  [ "$modified" -gt 0 ]  && g+=" ${Y}~${modified}${R}"
  [ "$untracked" -gt 0 ] && g+=" ${D}?${untracked}${R}"
  [ -n "$ahead" ]  && g+=" ${G}↑${ahead}${R}"
  [ -n "$behind" ] && g+=" ${RD}↓${behind}${R}"
  l1+="${SEP}${g# }"
fi

pr=$(j .pr.number); [ -n "$pr" ] && l1+="${SEP}${C}PR #${pr}${R}"
[ -n "$agent" ] && l1+="${SEP}${M}@${agent}${R}"
[ -n "$vim" ] && l1+="${SEP}${D}${vim}${R}"

# ---- line 2: context / limits / cost / time / lines / meta ----
l2=""
cp=$(j .context_window.used_percentage)
if [ -n "$cp" ]; then
  cp=${cp%.*}; cp=${cp:-0}
  cs=$(j .context_window.context_window_size)
  l2+="ctx $(pct_color "$cp")$(bar "$cp" 10) ${cp}%${R}"
  [ -n "$cs" ] && l2+=" ${D}/$(fmt_tok "$cs")${R}"
fi

for k in five_hour:5h seven_day:7d; do
  key=${k%%:*}; label=${k##*:}
  p=$(j ".rate_limits.${key}.used_percentage")
  if [ -n "$p" ]; then
    p=${p%.*}; p=${p:-0}
    [ -n "$l2" ] && l2+="$SEP"
    l2+="${label} $(pct_color "$p")${p}%${R}"
  fi
done

cost=$(j .cost.total_cost_usd)
[ -n "$cost" ] && { [ -n "$l2" ] && l2+="$SEP"; l2+="$(printf '$%.2f' "$cost")"; }

dur=$(j .cost.total_duration_ms)
[ -n "$dur" ] && { [ -n "$l2" ] && l2+="$SEP"; l2+="⏱ $(fmt_dur "${dur%.*}")"; }

add=$(j .cost.total_lines_added); del=$(j .cost.total_lines_removed)
if [ -n "$add$del" ]; then
  [ -n "$l2" ] && l2+="$SEP"
  l2+="${G}+${add:-0}${R} ${RD}-${del:-0}${R}"
fi

[ -n "$style" ] && [ "$style" != "default" ] && { [ -n "$l2" ] && l2+="$SEP"; l2+="${D}${style}${R}"; }
[ -n "$ver" ] && { [ -n "$l2" ] && l2+="$SEP"; l2+="${D}v${ver}${R}"; }

printf '%s' "$l1"
[ -n "$l2" ] && printf '\n%s' "$l2"
