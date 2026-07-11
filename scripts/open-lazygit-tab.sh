#!/usr/bin/env bash
# Toggle lazygit in its own tab: CLOSE when it is the focused pane, FOCUS when
# in the focused tab, SWITCHTAB when in another tab of the same workspace,
# otherwise OPEN a new tab. Mirrors herdr-file-viewer's launch_decision_tab.
set -uo pipefail

herdr_bin="${HERDR_BIN_PATH:-herdr}"

open_tab() {
  exec "$herdr_bin" plugin pane open \
    --plugin herdr-lazygit --entrypoint lazygit \
    --placement tab --focus
}

command -v jq >/dev/null 2>&1 || open_tab
panes="$("$herdr_bin" pane list 2>/dev/null)" || open_tab
[ -n "$panes" ] || open_tab

# Workspace is the prefix of the id we act on (tab_id "w1:t2" -> "w1"); a
# lazygit pane in another workspace is ignored rather than yanking the user
# there. Ids must be flag-safe before they reach an argv.
decision="$(printf '%s' "$panes" | jq -r '
  def safe: type == "string" and length > 0 and (test("^[A-Za-z0-9_:.][A-Za-z0-9_:.-]*$"));
  def ws: (.tab_id // .pane_id // "") | split(":") | if length > 1 and .[0] != "" then .[0] else null end;
  (.result.panes // []) as $panes
  | ($panes | map(select(.focused == true)) | first) as $focused
  | if $focused == null then "OPEN"
    else
      ($panes | map(select(.label == "lazygit"))) as $lgs
      | ($lgs | map(select(.tab_id == $focused.tab_id)) | first) as $here
      | if $here != null then
          if (($here.pane_id // "") | safe | not) then "OPEN"
          elif $here.pane_id == $focused.pane_id then "CLOSE \($here.pane_id)"
          else "FOCUS \($here.pane_id)"
          end
        else
          ($focused | ws) as $fws
          | ($lgs | map(select($fws != null and (. | ws) == $fws)) | first) as $elsewhere
          | if $elsewhere != null and (($elsewhere.tab_id // "") | safe) then "SWITCHTAB \($elsewhere.tab_id)"
            else "OPEN"
            end
        end
    end' 2>/dev/null)" || decision="OPEN"

case "$decision" in
  "SWITCHTAB "*)
    tid="${decision#SWITCHTAB }"
    "$herdr_bin" tab focus "$tid" && exit 0
    open_tab
    ;;
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
    open_tab
    ;;
esac
