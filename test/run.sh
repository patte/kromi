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

printf 'a={{ background_rgb }} b={{ background_strip }} mode={{ mode }}\n' \
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

# Every theme must render every template with nothing left unsubstituted.
unresolved=""
for theme_dir in "$ROOT"/themes/*/; do
  theme=$(basename "$theme_dir")
  NARCHY_APPS=dummy "$NARCHY" set "$theme" >/dev/null
  if grep -rq '{{' "$XDG_STATE_HOME/narchy/current/"; then
    unresolved="$unresolved $theme"
  fi
done
[[ -z $unresolved ]]
check $? "all themes render with no unresolved tokens ($(ls "$ROOT/themes" | wc -l) themes)"

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
grep -qx 'a=26,27,38 b=1a1b26 mode=dark' "$XDG_STATE_HOME/narchy/current/probe.conf"
check $? "derived _rgb, _strip and mode substitutions"

NARCHY_APPS=probe "$NARCHY" set white >/dev/null
grep -q 'mode=light' "$XDG_STATE_HOME/narchy/current/probe.conf"
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
  "workbench.colorCustomizations": { "titleBar.border": "#abcdef" }
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

[[ $(jq -r '."workbench.colorCustomizations"."titleBar.border"' "$settings") == "#abcdef" ]]
check $? "vscode link keeps colour keys the user already had"

# vscode is the one app written to on `set`, so it has to follow a switch.
NARCHY_APPS=vscode "$NARCHY" set tokyo-night >/dev/null
[[ $(jq -r '."workbench.colorCustomizations"."editor.background"' "$settings") == "#1a1b26" ]]
check $? "vscode follows a theme switch"

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
