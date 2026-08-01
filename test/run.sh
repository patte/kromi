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

printf 'a={{ background_rgb }} b={{ background_strip }} mode={{ mode }} title={{ mode_title }}\n' \
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
done
[[ -z $unresolved ]]
check $? "all themes render with no unresolved tokens ($(ls "$ROOT/themes" | wc -l) themes)"

[[ -z $collided ]]
check $? "no theme paints dim text the colour of the surface under it"
[[ -z $collided ]] || printf '       collided:%s\n' "$collided"

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
grep -qx 'a=26,27,38 b=1a1b26 mode=dark title=Dark' "$XDG_STATE_HOME/narchy/current/probe.conf"
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

apps="hyprland waybar wofi mako ghostty btop neovim vscode"
"$NARCHY" link $apps >/dev/null
"$NARCHY" link $apps >/dev/null

[[ $(grep -c 'narchy/current' "$XDG_CONFIG_HOME/hypr/hyprland.lua") == 1 ]]
check $? "link is idempotent (hyprland)"

[[ $(grep -c 'narchy/current' "$XDG_CONFIG_HOME/waybar/style.css") == 2 ]]
check $? "link adds palette and theme imports (waybar)"

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

echo "demo"

NARCHY_APPS=dummy "$NARCHY" set nord >/dev/null
NARCHY_APPS=dummy "$NARCHY" demo 0 >"$SANDBOX/demo.out" 2>/dev/null </dev/null

# Every theme narchy lists, which includes any the sandbox added.
"$NARCHY" list >"$SANDBOX/demo-list.txt"
[[ $(grep -c '^\[' "$SANDBOX/demo.out") == "$(wc -l <"$SANDBOX/demo-list.txt")" ]]
check $? "demo visits every theme"

# Running to the end must not strand you on whichever theme sorts last.
[[ $("$NARCHY" current) == nord ]]
check $? "demo restores the theme it started from"

grep -q 'narchy set' "$SANDBOX/demo.out"
check $? "demo says how to apply one you liked"

! NARCHY_APPS=dummy "$NARCHY" demo notanumber >/dev/null 2>&1 </dev/null
check $? "demo rejects a non-numeric delay"

# The keys only exist when there is a terminal to read them from, so these run
# narchy under a pty with the keystrokes queued ahead of it.
if command -v python3 >/dev/null 2>&1; then
  pty() {
    local keys=$1
    shift
    python3 -c '
import os, pty, subprocess, sys

keys, cmd = sys.argv[1].encode(), sys.argv[2:]
master, slave = pty.openpty()
child = subprocess.Popen(cmd, stdin=slave, stdout=slave, stderr=slave)
os.close(slave)
os.write(master, keys)

out = b""
while True:
    try:
        chunk = os.read(master, 4096)
    except OSError:
        break
    if not chunk:
        break
    out += chunk
sys.stdout.write(out.decode(errors="replace"))
sys.exit(child.wait())
' "$keys" "$@"
  }

  NARCHY_APPS=dummy "$NARCHY" set nord >/dev/null
  NARCHY_APPS=dummy pty x "$NARCHY" demo 5 >"$SANDBOX/demo-auto.out" 2>&1 || true
  grep -q 'auto on, 5s' "$SANDBOX/demo-auto.out"
  check $? "demo with an interval starts rolling"

  NARCHY_APPS=dummy pty x "$NARCHY" demo >"$SANDBOX/demo-manual.out" 2>&1 || true
  ! grep -q 'auto on' "$SANDBOX/demo-manual.out"
  check $? "demo without one waits for a key"

  # The theme you arrived with is the first one printed, and named as such.
  [[ $(grep -m1 '^\[' "$SANDBOX/demo-manual.out") == *"nord  (yours)"* ]]
  check $? "demo marks the theme you started on"

  # Whichever way it started, x is what puts your own theme back.
  [[ $("$NARCHY" current) == nord ]]
  check $? "demo restores on x"
else
  echo "  skip demo key handling (no python3 for a pty)"
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
