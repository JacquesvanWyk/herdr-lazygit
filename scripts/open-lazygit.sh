#!/usr/bin/env bash
# Toggle lazygit in a split pane: OPEN if absent in the focused tab,
# FOCUS (zoom on/off) if present but unfocused, CLOSE if it is the focused pane.
# Mirrors herdr-file-viewer's launch_decision, reimplemented in jq.
set -uo pipefail

herdr_bin="${HERDR_BIN_PATH:-herdr}"

open_pane() {
  exec "$herdr_bin" plugin pane open \
    --plugin herdr-lazygit --entrypoint lazygit \
    --placement split --direction right --focus
}

command -v jq >/dev/null 2>&1 || open_pane
panes="$("$herdr_bin" pane list 2>/dev/null)" || open_pane
[ -n "$panes" ] || open_pane

# Decide OPEN / "FOCUS <id>" / "CLOSE <id>". Only a lazygit pane in the focused
# pane's tab counts; ids must be flag-safe (never start with "-") before they
# reach an argv.
decision="$(printf '%s' "$panes" | jq -r '
  def safe: type == "string" and length > 0 and (test("^[A-Za-z0-9_:.][A-Za-z0-9_:.-]*$"));
  (.result.panes // []) as $panes
  | ($panes | map(select(.focused == true)) | first) as $focused
  | if $focused == null then "OPEN"
    else
      ($panes | map(select(.label == "lazygit" and .tab_id == $focused.tab_id)) | first) as $lg
      | if $lg == null or (($lg.pane_id // "") | safe | not) then "OPEN"
        elif $lg.pane_id == $focused.pane_id then "CLOSE \($lg.pane_id)"
        else "FOCUS \($lg.pane_id)"
        end
    end' 2>/dev/null)" || decision="OPEN"

case "$decision" in
  "FOCUS "*)
    pid="${decision#FOCUS }"
    "$herdr_bin" pane zoom "$pid" --on >/dev/null 2>&1 || true
    exec "$herdr_bin" pane zoom "$pid" --off
    ;;
  "CLOSE "*)
    pid="${decision#CLOSE }"
    exec "$herdr_bin" pane close "$pid"
    ;;
  *)
    open_pane
    ;;
esac
