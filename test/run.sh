#!/usr/bin/env bash
# Hermetic: everything runs against a throwaway XDG root.
set -euo pipefail

ROOT=$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)
NARCHY="$ROOT/bin/narchy"

SANDBOX=$(mktemp -d)
trap 'rm -rf "$SANDBOX"' EXIT

export XDG_CONFIG_HOME="$SANDBOX/config"
export XDG_STATE_HOME="$SANDBOX/state"
export HOME="$SANDBOX"
mkdir -p "$XDG_CONFIG_HOME" "$XDG_STATE_HOME"

pass=0
fail=0

ok() {
  printf '  ok   %s\n' "$1"
  pass=$((pass + 1))
}
no() {
  printf '  FAIL %s\n' "$1"
  fail=$((fail + 1))
}
check() { if [[ $1 == 0 ]]; then ok "$2"; else no "$2"; fi; }

# Rec. 601 luma, as narchy computes it, so the dim_text property can be
# checked without recomputing which colour it picked.
luma_of() {
  local h=${1#\#}
  printf '%d\n' $(((299 * 16#${h:0:2} + 587 * 16#${h:2:2} + 114 * 16#${h:4:2}) / 1000))
}
distance() {
  local a b
  a=$(luma_of "$1")
  b=$(luma_of "$2")
  if ((a > b)); then printf '%d\n' $((a - b)); else printf '%d\n' $((b - a)); fi
}
palette_value() { sed -n "s/^$2 = \"\(#[0-9a-fA-F]*\)\"/\1/p" "$1"; }

# Shipped themes and templates as they are, but app definitions with their
# reloads stripped: this suite must never signal the live session.
FIXTURE="$SANDBOX/fixture"
mkdir -p "$FIXTURE/apps"
ln -s "$ROOT/themes" "$FIXTURE/themes"
ln -s "$ROOT/templates" "$FIXTURE/templates"
for app in "$ROOT"/apps/*.sh; do
  name=$(basename "$app")
  if [[ $name == vscode.sh ]]; then
    # Its reload is the theme application itself, not a signal, and it writes
    # only inside the sandbox — so keep it, or there is nothing to test.
    cp "$app" "$FIXTURE/apps/$name"
  else
    {
      cat "$app"
      echo 'reload() { :; }'
    } >"$FIXTURE/apps/$name"
  fi
done
export NARCHY_PATH="$FIXTURE"

# A stand-in app that renders every template and touches nothing.
mkdir -p "$XDG_CONFIG_HOME/narchy/apps" "$XDG_CONFIG_HOME/narchy/templates"
cat >"$XDG_CONFIG_HOME/narchy/apps/dummy.sh" <<'EOF'
templates="palette.css waybar.css wofi.css mako.ini ghostty.conf btop.theme hyprland.lua hyprland.conf"
detect() { true; }
reload() { :; }
EOF

cat >"$XDG_CONFIG_HOME/narchy/apps/probe.sh" <<'EOF'
templates="probe.conf"
detect() { true; }
reload() { :; }
EOF

printf 'a={{ background_rgb }} b={{ background_strip }} mode={{ mode }} title={{ mode_title }} dim={{ dim_text }}\n' \
  >"$XDG_CONFIG_HOME/narchy/templates/probe.conf.tpl"

# Sorts last, so it catches a failed detection ending the whole run.
cat >"$XDG_CONFIG_HOME/narchy/apps/zz-absent.sh" <<'EOF'
templates="probe.conf"
detect() { false; }
reload() { :; }
EOF

# Setup is done. Assertions report their own failures from here, so a failing
# one must not take the whole run down with it.
set +e

echo "rendering"

# Every theme must render every template with nothing left unsubstituted, and
# a surface must never come out the same colour as the dim text on it — with
# color0 and color8 holding the same value in several palettes, using the
# slots for both made hover rows and breadcrumbs illegible.
unresolved=""
collided=""
faint=""
for theme_dir in "$ROOT"/themes/*/; do
  theme=$(basename "$theme_dir")
  NARCHY_APPS=dummy "$NARCHY" set "$theme" >/dev/null
  if grep -rq '{{' "$XDG_STATE_HOME/narchy/current/"; then
    unresolved="$unresolved $theme"
  fi
  gen="$XDG_STATE_HOME/narchy/current/vscode.json"
  surface=$(jq -r '."workbench.colorCustomizations"."list.hoverBackground"' "$gen")
  dim=$(jq -r '."workbench.colorCustomizations"."breadcrumb.foreground"' "$gen")
  if [[ $surface == "$dim" ]]; then
    collided="$collided vscode/$theme"
  fi

  nvim_theme="$XDG_STATE_HOME/narchy/current/neovim.lua"
  surface=$(sed -n 's/.*surface = "\(#[0-9a-fA-F]*\)".*/\1/p' "$nvim_theme")
  dim=$(sed -n 's/.*muted = "\(#[0-9a-fA-F]*\)".*/\1/p' "$nvim_theme")
  if [[ $surface == "$dim" ]]; then
    collided="$collided neovim/$theme"
  fi

  # dim_text has to clear the floor, or match the furthest candidate from the
  # background when the palette has nothing that does.
  bg=$(palette_value "$theme_dir/colors.toml" background)
  chosen=$(sed -n 's/.*dim=\(#[0-9a-fA-F]*\).*/\1/p' "$XDG_STATE_HOME/narchy/current/probe.conf")
  best=0
  for name in dark_foreground muted color8; do
    d=$(distance "$(palette_value "$theme_dir/colors.toml" "$name")" "$bg")
    ((d > best)) && best=$d
  done
  ((best > 80)) && best=80
  if (($(distance "$chosen" "$bg") < best)); then
    faint="$faint $theme"
  fi
done
[[ -z $unresolved ]]
check $? "all themes render with no unresolved tokens ($(ls "$ROOT/themes" | wc -l) themes)"

[[ -z $collided ]]
check $? "no theme paints dim text the colour of the surface under it"
[[ -z $collided ]] || printf '       collided:%s\n' "$collided"

[[ -z $faint ]]
check $? "dim text stands off the background as far as the palette allows"
[[ -z $faint ]] || printf '       too faint:%s\n' "$faint"

# The names past the 16 slots are not derivable, so a palette written by hand
# may well omit them. Every template still has to render.
mkdir -p "$XDG_CONFIG_HOME/narchy/themes/plain"
{
  printf '%s\n' 'accent = "#7aa2f7"' 'cursor = "#c0caf5"' 'foreground = "#a9b1d6"' \
    'background = "#1a1b26"' 'selection_foreground = "#c0caf5"' 'selection_background = "#7aa2f7"'
  for i in $(seq 0 15); do printf 'color%d = "#1a1b26"\n' "$i"; done
} >"$XDG_CONFIG_HOME/narchy/themes/plain/colors.toml"
NARCHY_APPS=dummy "$NARCHY" set plain >/dev/null
! grep -rq '{{' "$XDG_STATE_HOME/narchy/current/"
check $? "a palette naming only the 16 slots still renders everything"

NARCHY_APPS=dummy "$NARCHY" set tokyo-night >/dev/null
[[ $("$NARCHY" current) == tokyo-night ]]
check $? "current reports the theme just set"

grep -q '#1a1b26' "$XDG_STATE_HOME/narchy/current/waybar.css"
check $? "palette values reach the generated css"

# Detection runs over the real app definitions here, not the dummy.
"$NARCHY" set nord >/dev/null 2>&1
check $? "set succeeds when an app is undetected"

# Narrowing the app list must not delete files other configs still import;
# a missing @import target stops waybar starting at all.
NARCHY_APPS=probe "$NARCHY" set nord >/dev/null
[[ -f $XDG_STATE_HOME/narchy/current/palette.css && -f $XDG_STATE_HOME/narchy/current/waybar.css ]]
check $? "narrowing NARCHY_APPS still renders every app's files"

# The _rgb and _strip forms are the two derived substitutions templates rely on.
NARCHY_APPS=probe "$NARCHY" set tokyo-night >/dev/null
grep -q 'a=26,27,38 b=1a1b26 mode=dark title=Dark dim=#' "$XDG_STATE_HOME/narchy/current/probe.conf"
check $? "derived _rgb, _strip and mode substitutions"

NARCHY_APPS=probe "$NARCHY" set white >/dev/null
grep -q 'mode=light title=Light' "$XDG_STATE_HOME/narchy/current/probe.conf"
check $? "mode follows background luminance"

# A theme shipping its own file must win over the template.
mkdir -p "$XDG_CONFIG_HOME/narchy/themes/custom"
cp "$ROOT/themes/nord/colors.toml" "$XDG_CONFIG_HOME/narchy/themes/custom/"
echo "/* handwritten */" >"$XDG_CONFIG_HOME/narchy/themes/custom/waybar.css"
NARCHY_APPS=dummy "$NARCHY" set custom >/dev/null
grep -q 'handwritten' "$XDG_STATE_HOME/narchy/current/waybar.css"
check $? "theme-shipped file overrides the template"

# User themes dir is searched, so custom themes show up in the listing.
"$NARCHY" list >"$SANDBOX/list.txt"
grep -q 'Custom' "$SANDBOX/list.txt"
check $? "user themes appear in list"

grep -q '^\* Custom' "$SANDBOX/list.txt"
check $? "list marks the current theme"

echo "linking"

NARCHY_APPS=dummy "$NARCHY" set nord >/dev/null

# Seed configs the way a real system would have them.
mkdir -p "$XDG_CONFIG_HOME/hypr" "$XDG_CONFIG_HOME/waybar" "$XDG_CONFIG_HOME/Code/User"
echo "-- user config" >"$XDG_CONFIG_HOME/hypr/hyprland.lua"
echo "window#waybar { padding: 0; }" >"$XDG_CONFIG_HOME/waybar/style.css"
cat >"$XDG_CONFIG_HOME/Code/User/settings.json" <<'EOF'
{
  "editor.fontSize": 13,
  "workbench.colorTheme": "Monokai",
  "workbench.colorCustomizations": { "notebook.editorBackground": "#abcdef" }
}
EOF
cp -r "$XDG_CONFIG_HOME" "$SANDBOX/config.before"

apps="hyprland hyprpaper waybar wofi mako ghostty btop neovim vscode"
"$NARCHY" link $apps >/dev/null
"$NARCHY" link $apps >/dev/null

[[ $(grep -c 'narchy/current' "$XDG_CONFIG_HOME/hypr/hyprland.lua") == 1 ]]
check $? "link is idempotent (hyprland)"

[[ $(grep -c 'narchy/current' "$XDG_CONFIG_HOME/waybar/style.css") == 2 ]]
check $? "link adds palette and theme imports (waybar)"

# hyprpaper has no config of its own until narchy writes one, and sourcing a
# file that is not there is the one error it refuses to start on.
[[ $(grep -c '^source = .*narchy/current/hyprpaper.conf$' "$XDG_CONFIG_HOME/hypr/hyprpaper.conf") == 1 ]]
check $? "link sources narchy's file (hyprpaper)"

head -1 "$XDG_CONFIG_HOME/waybar/style.css" | grep -q 'palette.css'
check $? "palette import comes first, where css needs it"

tail -1 "$XDG_CONFIG_HOME/waybar/style.css" | grep -q 'waybar.css'
check $? "theme import comes last, so it overrides"

[[ -L $XDG_CONFIG_HOME/btop/themes/narchy.theme ]]
check $? "btop theme is symlinked into its themes dir"

settings="$XDG_CONFIG_HOME/Code/User/settings.json"

[[ $(jq -r '."editor.fontSize"' "$settings") == 13 ]]
check $? "vscode link leaves unrelated settings alone"

[[ $(jq -r '."workbench.colorCustomizations"."editor.background"' "$settings") == "#2e3440" ]]
check $? "vscode link writes the palette into colorCustomizations"

[[ $(jq -r '."workbench.colorCustomizations"."notebook.editorBackground"' "$settings") == "#abcdef" ]]
check $? "vscode link keeps colour keys the user already had"

# vscode is the one app written to on `set`, so it has to follow a switch.
NARCHY_APPS=vscode "$NARCHY" set tokyo-night >/dev/null
[[ $(jq -r '."workbench.colorCustomizations"."editor.background"' "$settings") == "#1a1b26" ]]
check $? "vscode follows a theme switch"

# A colour whose default is another colour resolves against the theme under
# the customisations rather than against ours, so the ones that follow the
# editor background have to be written out or they keep the base theme's — a
# black gutter down the side of a white editor.
missing=""
for key in editorGutter.background editorPane.background minimap.background \
  breadcrumb.background editorStickyScroll.background editorStickyScrollGutter.background \
  editorGroup.emptyBackground editorGroupHeader.noTabsBackground; do
  [[ $(jq -r --arg k "$key" '."workbench.colorCustomizations"[$k] // "unset"' "$settings") == "#1a1b26" ]] ||
    missing="$missing $key"
done
[[ -z $missing ]]
check $? "vscode names every surface that follows the editor background"
[[ -z $missing ]] || printf '       missing:%s\n' "$missing"

# Webviews take their light or dark from the theme's kind, not from any colour
# we name, so the base theme has to match the palette.
[[ $(jq -r '."workbench.colorTheme"' "$settings") == "Default Dark Modern" ]]
check $? "vscode gets a dark base theme for a dark palette"

NARCHY_APPS=vscode "$NARCHY" set catppuccin-latte >/dev/null
[[ $(jq -r '."workbench.colorTheme"' "$settings") == "Default Light Modern" ]]
check $? "vscode gets a light base theme for a light palette"

NARCHY_APPS=vscode "$NARCHY" set tokyo-night >/dev/null

echo "unlinking"

"$NARCHY" unlink $apps >/dev/null

! grep -rq 'narchy' "$XDG_CONFIG_HOME/hypr" "$XDG_CONFIG_HOME/waybar" 2>/dev/null
check $? "unlink leaves no residue"

diff -r "$SANDBOX/config.before/hypr" "$XDG_CONFIG_HOME/hypr" >/dev/null
check $? "unlink restores configs byte for byte"

[[ ! -e $XDG_CONFIG_HOME/mako/config ]]
check $? "unlink removes configs that held only our line"

diff <(jq -S . "$SANDBOX/config.before/Code/User/settings.json") <(jq -S . "$settings") >/dev/null
check $? "unlink hands vscode settings back exactly as they were"

# Nothing may be written to a config that was never linked.
"$NARCHY" set gruvbox >/dev/null
[[ $(jq -r '."workbench.colorCustomizations"."editor.background" // "none"' "$settings") == "none" ]]
check $? "set leaves vscode alone when it is not linked"

echo "interactive"

NARCHY_APPS=dummy "$NARCHY" set nord >/dev/null
NARCHY_APPS=dummy "$NARCHY" interactive 0 >"$SANDBOX/i.out" 2>/dev/null </dev/null

# Every theme narchy lists, which includes any the sandbox added.
"$NARCHY" list >"$SANDBOX/i-list.txt"
[[ $(grep -c '^\[' "$SANDBOX/i.out") == "$(wc -l <"$SANDBOX/i-list.txt")" ]]
check $? "interactive visits every theme"

# Running to the end must not strand you on whichever theme sorts last.
[[ $("$NARCHY" current) == nord ]]
check $? "interactive restores the theme it started from"

grep -q 'narchy set' "$SANDBOX/i.out"
check $? "interactive says how to apply one you liked"

! NARCHY_APPS=dummy "$NARCHY" interactive notanumber >/dev/null 2>&1 </dev/null
check $? "interactive rejects a non-numeric delay"

# Both short forms reach the same command.
NARCHY_APPS=dummy "$NARCHY" i 0 >"$SANDBOX/i-alias.out" 2>/dev/null </dev/null
NARCHY_APPS=dummy "$NARCHY" demo 0 >"$SANDBOX/demo-alias.out" 2>/dev/null </dev/null
diff -q "$SANDBOX/i-alias.out" "$SANDBOX/demo-alias.out" >/dev/null
check $? "i and demo are aliases for interactive"

# The keys only exist when there is a terminal to read them from, so these run
# narchy under a pty with the keystrokes queued ahead of it.
if command -v python3 >/dev/null 2>&1; then
  pty() {
    local keys=$1
    shift
    python3 -c '
import os, pty, select, sys, time

keys, cmd = sys.argv[1].encode().decode("unicode_escape").encode(), sys.argv[2:]
# pty.fork rather than a pipe pair: only a controlling terminal turns a typed
# ^C into a signal, and one of these tests is about Ctrl-C.
pid, master = pty.fork()
if pid == 0:
    os.execvp(cmd[0], cmd)

out = b""

def drain(seconds):
    global out
    end = time.time() + seconds
    while time.time() < end:
        if select.select([master], [], [], 0.1)[0]:
            try:
                chunk = os.read(master, 4096)
            except OSError:
                return False
            if not chunk:
                return False
            out += chunk
    return True

# Type only once there is output, so a signal cannot arrive before the trap,
# and one key at a time: sent together, a ^C is handled before the key ahead
# of it is ever read.
drain(1.0)
for key in keys:
    os.write(master, bytes([key]))
    drain(0.4)
while drain(0.5):
    if os.waitpid(pid, os.WNOHANG)[0]:
        break
sys.stdout.write(out.decode(errors="replace"))
sys.exit(0)
' "$keys" "$@"
  }

  NARCHY_APPS=dummy "$NARCHY" set nord >/dev/null
  NARCHY_APPS=dummy pty x "$NARCHY" i 5 >"$SANDBOX/i-auto.out" 2>&1 || true
  grep -q 'auto on, 5s' "$SANDBOX/i-auto.out"
  check $? "interactive with an interval starts rolling"

  NARCHY_APPS=dummy pty x "$NARCHY" i >"$SANDBOX/i-manual.out" 2>&1 || true
  ! grep -q 'auto on' "$SANDBOX/i-manual.out"
  check $? "interactive without one waits for a key"

  # It opens on the whole shelf: `narchy list`, star and all, before any key.
  # tr first: a terminal ends even a blank line with a carriage return.
  diff <(tr -d '\r' <"$SANDBOX/i-manual.out" | sed -n '1,/^$/p' | sed '/^$/d') \
    <(NARCHY_APPS=dummy "$NARCHY" list) >/dev/null
  check $? "interactive opens with the theme list, starred as list does"

  # The theme you arrived with is the first one printed, and named as such.
  [[ $(grep -m1 '^\[' "$SANDBOX/i-manual.out") == *"nord  (yours)"* ]]
  check $? "interactive marks the theme you started on"

  # tr, because a terminal ends its lines with a carriage return too.
  showing_of() { grep '^\[' "$1" | tail -1 | tr -d '\r' | awk '{print $2}'; }

  # r steps back to the theme you came with without ending the browse, so the
  # x that follows is what stops it — and stops it on yours.
  NARCHY_APPS=dummy pty 'nnrx' "$NARCHY" i >"$SANDBOX/i-restore.out" 2>&1 || true
  [[ $(showing_of "$SANDBOX/i-restore.out") == nord ]]
  check $? "r steps back to the theme you came with"

  grep -q '^kept nord' "$SANDBOX/i-restore.out"
  check $? "r keeps browsing, so x is still what ends it"

  [[ $(NARCHY_APPS=dummy "$NARCHY" current) == nord ]]
  check $? "r leaves the theme where it found it"

  # x stops on whatever is showing rather than on the one you came with.
  NARCHY_APPS=dummy pty 'nx' "$NARCHY" i >"$SANDBOX/i-keep.out" 2>&1 || true
  showing=$(showing_of "$SANDBOX/i-keep.out")
  grep -q "^kept $showing" "$SANDBOX/i-keep.out"
  check $? "x keeps the theme it was showing"

  [[ -n $showing && $showing != nord && $(NARCHY_APPS=dummy "$NARCHY" current) == "$showing" ]]
  check $? "x leaves the theme it stopped on"

  # Ctrl-C is x: the trap fires at once but does not make a blocked read
  # return, so a browse that waits on the keypress itself sits there ignoring
  # it.
  NARCHY_APPS=dummy "$NARCHY" set nord >/dev/null
  NARCHY_APPS=dummy pty 'n\x03' "$NARCHY" i >"$SANDBOX/i-int.out" 2>&1 || true
  grep -q '^kept ' "$SANDBOX/i-int.out"
  check $? "ctrl-c stops the browse"

  showing=$(showing_of "$SANDBOX/i-int.out")
  [[ -n $showing && $showing != nord && $(NARCHY_APPS=dummy "$NARCHY" current) == "$showing" ]]
  check $? "ctrl-c keeps the theme it was showing, not the one you came with"

  NARCHY_APPS=dummy "$NARCHY" set nord >/dev/null
else
  echo "  skip interactive key handling (no python3 for a pty)"
fi

echo "background selection"

BG="$XDG_CONFIG_HOME/narchy/backgrounds"
mkdir -p "$BG/nord"
echo x >"$BG/nord/1-first.jpg"
echo y >"$BG/nord/2-second.png"
echo z >"$BG/nord/3-third.jpg"

NARCHY_APPS=dummy "$NARCHY" set nord >/dev/null
[[ $("$NARCHY" background) == "$BG/nord/1-first.jpg" ]]
check $? "set points the background link at the first image"

HP="$XDG_STATE_HOME/narchy/current/hyprpaper.conf"

grep -qxF "    path = $XDG_STATE_HOME/narchy/current/background" "$HP"
check $? "the wallpaper config names the link, not the image behind it"

grep -qxF 'splash = false' "$HP"
check $? "hyprpaper's own splash is turned off"

[[ $(NARCHY_APPS=dummy "$NARCHY" background next) == "2-second.png" ]]
check $? "background next advances"

NARCHY_APPS=dummy "$NARCHY" background next >/dev/null
[[ $(NARCHY_APPS=dummy "$NARCHY" background next) == "1-first.jpg" ]]
check $? "background next wraps around"

# A theme nobody has pictures for must not break a switch.
NARCHY_APPS=dummy "$NARCHY" set gruvbox >/dev/null
check $? "set works for a theme with no backgrounds"

[[ ! -L $XDG_STATE_HOME/narchy/current/background ]]
check $? "no background link when there are no images"

# The sourced file has to exist even then: hyprpaper shrugs off a path it
# cannot resolve, but a source line with nothing behind it stops it starting.
[[ -f $HP ]]
check $? "the sourced file is written for a theme with no wallpaper"

echo "backgrounds"

# Point the fetcher at a local repo, so this stays offline.
SOURCE="$SANDBOX/source"
mkdir -p "$SOURCE/themes/nord/backgrounds" "$SOURCE/themes/gruvbox/backgrounds"
echo "upstream-a" >"$SOURCE/themes/nord/backgrounds/a.jpg"
echo "upstream-b" >"$SOURCE/themes/nord/backgrounds/b.jpg"
echo "upstream-c" >"$SOURCE/themes/gruvbox/backgrounds/c.jpg"
(
  cd "$SOURCE"
  git init -q .
  git config user.email t@t
  git config user.name t
  git config uploadpack.allowFilter true
  git add -A
  git commit -qm fixtures
  git tag v-test
) >/dev/null 2>&1

export NARCHY_BACKGROUNDS_REPO="$SOURCE"
export NARCHY_BACKGROUNDS_REF="v-test"
BACKGROUNDS="$ROOT/bin/narchy-backgrounds"
DEST="$XDG_CONFIG_HOME/narchy/backgrounds"

"$BACKGROUNDS" nord gruvbox >/dev/null 2>&1
[[ -f $DEST/nord/a.jpg && -f $DEST/nord/b.jpg && -f $DEST/gruvbox/c.jpg ]]
check $? "backgrounds are fetched into the user's backgrounds dir"

# The whole point: a picture you put there yourself must survive a re-run.
echo "mine" >"$DEST/nord/a.jpg"
echo "also-mine" >"$DEST/nord/keep.jpg"
"$BACKGROUNDS" nord >/dev/null 2>&1
[[ $(cat "$DEST/nord/a.jpg") == "mine" ]]
check $? "an existing file is never overwritten"

[[ -f $DEST/keep.jpg || -f $DEST/nord/keep.jpg ]]
check $? "a file with no upstream counterpart is left alone"

"$BACKGROUNDS" no-such-theme >/dev/null 2>&1
check $? "a theme with nothing upstream is not an error"

[[ ! -d $DEST/no-such-theme ]]
check $? "no empty directory is left for a theme with nothing upstream"

echo
printf '%s passed, %s failed\n' "$pass" "$fail"
[[ $fail == 0 ]]
