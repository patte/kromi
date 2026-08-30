#!/usr/bin/env bash
# Hermetic: everything runs against a throwaway XDG root.
set -euo pipefail

ROOT=$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)
KROMI="$ROOT/bin/kromi"

SANDBOX=$(mktemp -d)
trap 'rm -rf "$SANDBOX"' EXIT

export XDG_CONFIG_HOME="$SANDBOX/config"
export XDG_STATE_HOME="$SANDBOX/state"
export HOME="$SANDBOX"
# Sockets live here: the live session's are in the real one, and a suite that
# could reach them could reload the editor someone is working in.
export XDG_RUNTIME_DIR="$SANDBOX/run"
mkdir -p "$XDG_CONFIG_HOME" "$XDG_STATE_HOME" "$XDG_RUNTIME_DIR"

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

# Rec. 601 luma, as kromi computes it, so the dim_text property can be
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
# Any spacing around the =: lumon aligns its values in columns.
palette_value() { sed -n "s/^$2 *= *\"\(#[0-9a-fA-F]*\)\"/\1/p" "$1"; }

# Shipped themes and templates as they are, but app definitions with their
# reloads stripped: this suite must never signal the live session.
FIXTURE="$SANDBOX/fixture"
mkdir -p "$FIXTURE/apps"
ln -s "$ROOT/themes" "$FIXTURE/themes"
ln -s "$ROOT/templates" "$FIXTURE/templates"
for app in "$ROOT"/apps/*.sh; do
  name=$(basename "$app")
  if [[ $name == vscode.sh || $name == vlc.sh || $name == firefox.sh ]]; then
    # Their reload is the theme application itself, not a signal, and it writes
    # only inside the sandbox — so keep it, or there is nothing to test.
    cp "$app" "$FIXTURE/apps/$name"
  else
    {
      cat "$app"
      echo 'reload() { :; }'
      # Nor start a daemon: setup offers to, and the offer is what is tested.
      echo 'running() { [[ -f $XDG_STATE_HOME/running-$APP ]]; }'
      echo 'start() { touch "$XDG_STATE_HOME/started-$APP"; }'
    } >"$FIXTURE/apps/$name"
  fi
done
export KROMI_PATH="$FIXTURE"

# A stand-in app that renders every template and touches nothing.
mkdir -p "$XDG_CONFIG_HOME/kromi/apps" "$XDG_CONFIG_HOME/kromi/templates"
cat >"$XDG_CONFIG_HOME/kromi/apps/dummy.sh" <<'EOF'
templates="palette.css waybar.css wofi.css mako.ini ghostty.conf btop.theme hyprland.lua hyprland.conf"
detect() { true; }
reload() { :; }
EOF

cat >"$XDG_CONFIG_HOME/kromi/apps/probe.sh" <<'EOF'
templates="probe.conf"
detect() { true; }
reload() { :; }
EOF

printf 'a={{ background_rgb }} b={{ background_strip }} mode={{ mode }} title={{ mode_title }} dim={{ dim_text }}\n' \
  >"$XDG_CONFIG_HOME/kromi/templates/probe.conf.tpl"

# Sorts last, so it catches a failed detection ending the whole run.
cat >"$XDG_CONFIG_HOME/kromi/apps/zz-absent.sh" <<'EOF'
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
  KROMI_APPS=dummy "$KROMI" set "$theme" >/dev/null
  if grep -rq '{{' "$XDG_STATE_HOME/kromi/current/"; then
    unresolved="$unresolved $theme"
  fi
  gen="$XDG_STATE_HOME/kromi/current/vscode.json"
  surface=$(jq -r '."workbench.colorCustomizations"."list.hoverBackground"' "$gen")
  dim=$(jq -r '."workbench.colorCustomizations"."breadcrumb.foreground"' "$gen")
  if [[ $surface == "$dim" ]]; then
    collided="$collided vscode/$theme"
  fi

  nvim_theme="$XDG_STATE_HOME/kromi/current/neovim.lua"
  surface=$(sed -n 's/.*surface = "\(#[0-9a-fA-F]*\)".*/\1/p' "$nvim_theme")
  dim=$(sed -n 's/.*muted = "\(#[0-9a-fA-F]*\)".*/\1/p' "$nvim_theme")
  if [[ $surface == "$dim" ]]; then
    collided="$collided neovim/$theme"
  fi

  # dim_text has to clear the floor, or match the furthest candidate from the
  # background when the palette has nothing that does.
  bg=$(palette_value "$theme_dir/colors.toml" background)
  chosen=$(sed -n 's/.*dim=\(#[0-9a-fA-F]*\).*/\1/p' "$XDG_STATE_HOME/kromi/current/probe.conf")
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
mkdir -p "$XDG_CONFIG_HOME/kromi/themes/plain"
{
  printf '%s\n' 'accent = "#7aa2f7"' 'cursor = "#c0caf5"' 'foreground = "#a9b1d6"' \
    'background = "#1a1b26"' 'selection_foreground = "#c0caf5"' 'selection_background = "#7aa2f7"'
  for i in $(seq 0 15); do printf 'color%d = "#1a1b26"\n' "$i"; done
} >"$XDG_CONFIG_HOME/kromi/themes/plain/colors.toml"
KROMI_APPS=dummy "$KROMI" set plain >/dev/null
! grep -rq '{{' "$XDG_STATE_HOME/kromi/current/"
check $? "a palette naming only the 16 slots still renders everything"

KROMI_APPS=dummy "$KROMI" set tokyo-night >/dev/null
[[ $("$KROMI" current) == tokyo-night ]]
check $? "current reports the theme just set"

grep -q '#1a1b26' "$XDG_STATE_HOME/kromi/current/waybar.css"
check $? "palette values reach the generated css"

# A theme with no wallpaper still has to look like the theme: the bare desktop
# takes the palette's background, in both spellings of the config.
grep -q 'background_color = "#1a1b26"' "$XDG_STATE_HOME/kromi/current/hyprland.lua" &&
  grep -q 'background_color = rgb(1a1b26)' "$XDG_STATE_HOME/kromi/current/hyprland.conf"
check $? "hyprland paints the bare desktop in the palette's background"

# Detection runs over the real app definitions here, not the dummy.
"$KROMI" set nord >/dev/null 2>&1
check $? "set succeeds when an app is undetected"

# Narrowing the app list must not delete files other configs still import;
# a missing @import target stops waybar starting at all.
KROMI_APPS=probe "$KROMI" set nord >/dev/null
[[ -f $XDG_STATE_HOME/kromi/current/palette.css && -f $XDG_STATE_HOME/kromi/current/waybar.css ]]
check $? "narrowing KROMI_APPS still renders every app's files"

# The _rgb and _strip forms are the two derived substitutions templates rely on.
KROMI_APPS=probe "$KROMI" set tokyo-night >/dev/null
grep -q 'a=26,27,38 b=1a1b26 mode=dark title=Dark dim=#' "$XDG_STATE_HOME/kromi/current/probe.conf"
check $? "derived _rgb, _strip and mode substitutions"

KROMI_APPS=probe "$KROMI" set white >/dev/null
grep -q 'mode=light title=Light' "$XDG_STATE_HOME/kromi/current/probe.conf"
check $? "mode follows background luminance"

# A theme shipping its own file must win over the template.
mkdir -p "$XDG_CONFIG_HOME/kromi/themes/custom"
cp "$ROOT/themes/nord/colors.toml" "$XDG_CONFIG_HOME/kromi/themes/custom/"
echo "/* handwritten */" >"$XDG_CONFIG_HOME/kromi/themes/custom/waybar.css"
KROMI_APPS=dummy "$KROMI" set custom >/dev/null
grep -q 'handwritten' "$XDG_STATE_HOME/kromi/current/waybar.css"
check $? "theme-shipped file overrides the template"

# User themes dir is searched, so custom themes show up in the listing.
"$KROMI" list >"$SANDBOX/list.txt"
grep -q 'Custom' "$SANDBOX/list.txt"
check $? "user themes appear in list"

grep -q '^\* Custom' "$SANDBOX/list.txt"
check $? "list marks the current theme"

echo "linking"

KROMI_APPS=dummy "$KROMI" set nord >/dev/null

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
# vlcrc as VLC writes one: sectioned, and the key present but commented out,
# which is how it spells a default.
mkdir -p "$XDG_CONFIG_HOME/vlc"
cat >"$XDG_CONFIG_HOME/vlc/vlcrc" <<'EOF'
[core]
#volume=256

[qt] # Qt interface
# Enable Dark Mode (boolean)
#qt-dark-palette=0

# Show advanced preferences over simple ones (boolean)
#qt-advanced-pref=0
EOF
# Firefox as it looks once it has been run: profiles.ini, one profile, and a
# userChrome.css of the user's own for the import to be prepended to. Once in
# each root, since Firefox has moved to the XDG directories and still reads the
# old location — a machine may well have both.
profile="$XDG_CONFIG_HOME/mozilla/firefox/8h2k1p9x.default-release"
legacy_profile="$HOME/.mozilla/firefox/3d0m4q7v.default"
for p in "$profile" "$legacy_profile"; do
  mkdir -p "$p/chrome"
  cat >"$(dirname "$p")/profiles.ini" <<EOF
[Profile0]
Name=default-release
IsRelative=1
Path=$(basename "$p")
Default=1

[Install9E7C1A2B3D4F5061]
Default=$(basename "$p")
Locked=1
EOF
  echo '#TabsToolbar { visibility: collapse; }' >"$p/chrome/userChrome.css"
  echo 'user_pref("browser.startup.homepage", "about:blank");' >"$p/user.js"
done

cp -r "$XDG_CONFIG_HOME" "$SANDBOX/config.before"
cp -r "$HOME/.mozilla" "$SANDBOX/mozilla.before"

apps="hyprland hyprpaper waybar wofi mako ghostty btop neovim vscode vlc firefox"
"$KROMI" link $apps >/dev/null
"$KROMI" link $apps >/dev/null

[[ $(grep -c 'kromi/current' "$XDG_CONFIG_HOME/hypr/hyprland.lua") == 1 ]]
check $? "link is idempotent (hyprland)"

# apps reports what link did, app by app, read back from the configs.
KROMI_APPS="$apps" "$KROMI" apps >"$SANDBOX/apps.txt"
unlinked=""
for app in $apps; do
  grep -qE "^\* $app +linked$" "$SANDBOX/apps.txt" || unlinked="$unlinked $app"
done
[[ -z $unlinked ]]
check $? "apps marks every linked app as linked"
[[ -z $unlinked ]] || printf '       not marked:%s\n' "$unlinked"

# And what a hand takes out, it no longer claims.
sed -i '/kromi\/current/d' "$XDG_CONFIG_HOME/mako/config"
KROMI_APPS="$apps" "$KROMI" apps | grep -qE '^\* mako +linked$'
[[ $? != 0 ]]
check $? "apps sees an include line that was removed by hand"
"$KROMI" link mako >/dev/null

[[ $(grep -c 'kromi/current' "$XDG_CONFIG_HOME/waybar/style.css") == 2 ]]
check $? "link adds palette and theme imports (waybar)"

# hyprpaper has no config of its own until kromi writes one, and sourcing a
# file that is not there is the one error it refuses to start on.
[[ $(grep -c '^source = .*kromi/current/hyprpaper.conf$' "$XDG_CONFIG_HOME/hypr/hyprpaper.conf") == 1 ]]
check $? "link sources kromi's file (hyprpaper)"

head -1 "$XDG_CONFIG_HOME/waybar/style.css" | grep -q 'palette.css'
check $? "palette import comes first, where css needs it"

tail -1 "$XDG_CONFIG_HOME/waybar/style.css" | grep -q 'waybar.css'
check $? "theme import comes last, so it overrides"

[[ -L $XDG_CONFIG_HOME/btop/themes/kromi.theme ]]
check $? "btop theme is symlinked into its themes dir"

settings="$XDG_CONFIG_HOME/Code/User/settings.json"

[[ $(jq -r '."editor.fontSize"' "$settings") == 13 ]]
check $? "vscode link leaves unrelated settings alone"

[[ $(jq -r '."workbench.colorCustomizations"."editor.background"' "$settings") == "#2e3440" ]]
check $? "vscode link writes the palette into colorCustomizations"

[[ $(jq -r '."workbench.colorCustomizations"."notebook.editorBackground"' "$settings") == "#abcdef" ]]
check $? "vscode link keeps colour keys the user already had"

# A settings.json that will not parse is left alone — and a link that wrote
# nothing must not be reported as one that did.
mkdir -p "$SANDBOX/broken/Code/User"
printf '{ "editor.fontSize": 13, \n' >"$SANDBOX/broken/Code/User/settings.json"
XDG_CONFIG_HOME="$SANDBOX/broken" XDG_STATE_HOME="$SANDBOX/broken-state" "$KROMI" link vscode >"$SANDBOX/broken.out" 2>&1
grep -q 'link failed' "$SANDBOX/broken.out" &&
  ! XDG_CONFIG_HOME="$SANDBOX/broken" XDG_STATE_HOME="$SANDBOX/broken-state" KROMI_APPS=vscode "$KROMI" apps | grep -q linked
check $? "a vscode link that could not write is not reported as linked"

# vscode is the one app written to on `set`, so it has to follow a switch.
KROMI_APPS=vscode "$KROMI" set tokyo-night >/dev/null
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

KROMI_APPS=vscode "$KROMI" set catppuccin-latte >/dev/null
[[ $(jq -r '."workbench.colorTheme"' "$settings") == "Default Light Modern" ]]
check $? "vscode gets a light base theme for a light palette"

KROMI_APPS=vscode "$KROMI" set tokyo-night >/dev/null

vlcrc="$XDG_CONFIG_HOME/vlc/vlcrc"
section_of() { awk '/^\[/ { s = $1 } /^qt-dark-palette=/ { print s; exit }' "$1"; }

grep -qx 'qt-dark-palette=1' "$vlcrc"
check $? "vlc turns dark mode on for a dark palette"

[[ $(section_of "$vlcrc") == "[qt]" ]]
check $? "the key is rewritten where it stood, under [qt]"

[[ $(grep -c 'qt-dark-palette' "$vlcrc") == 1 ]]
check $? "the commented default is replaced, not doubled"

KROMI_APPS=vlc "$KROMI" set catppuccin-latte >/dev/null
grep -qx 'qt-dark-palette=0' "$vlcrc"
check $? "vlc turns it off again for a light palette"

KROMI_APPS=vlc "$KROMI" set tokyo-night >/dev/null

user_chrome="$profile/chrome/userChrome.css"

[[ $(grep -c '@import url("kromi.css");' "$user_chrome") == 1 ]]
check $? "link is idempotent (firefox)"

head -1 "$user_chrome" | grep -qx '@import url("kromi.css");'
check $? "the import goes above the rules already in userChrome.css"

grep -qx '@import url("kromi-content.css");' "$profile/chrome/userContent.css"
check $? "link imports the about: sheet as well (firefox)"

grep -qx '@import url("kromi.css");' "$legacy_profile/chrome/userChrome.css"
check $? "link reaches profiles in the old root as well as the XDG one"

# The sheets are reached through the profile rather than named where they lie:
# the process that loads userContent.css may not read outside the profile.
[[ $(readlink "$profile/chrome/kromi.css") == "$XDG_STATE_HOME/kromi/current/firefox.css" ]] &&
  [[ $(readlink "$profile/chrome/kromi-content.css") == "$XDG_STATE_HOME/kromi/current/firefox-content.css" ]]
check $? "both sheets are symlinked into the profile's chrome dir"

grep -qx 'user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);' "$profile/user.js"
check $? "link turns on the pref that makes firefox read them"

grep -qx 'user_pref("layout.css.prefers-color-scheme.content-override", 0);' "$profile/user.js"
check $? "firefox hands websites a dark palette's dark"

KROMI_APPS=firefox "$KROMI" set catppuccin-latte >/dev/null 2>&1
grep -qx 'user_pref("layout.css.prefers-color-scheme.content-override", 1);' "$profile/user.js"
check $? "firefox follows a switch to a light palette"

[[ $(grep -c 'prefers-color-scheme.content-override' "$profile/user.js") == 1 ]]
check $? "the pref is rewritten where it stands, not stacked"

grep -q 'browser.startup.homepage' "$profile/user.js"
check $? "firefox link leaves prefs of your own alone"

KROMI_APPS=firefox "$KROMI" set tokyo-night >/dev/null 2>&1

echo "unlinking"

"$KROMI" unlink $apps >/dev/null

! grep -rq 'kromi' "$XDG_CONFIG_HOME/hypr" "$XDG_CONFIG_HOME/waybar" 2>/dev/null
check $? "unlink leaves no residue"

! KROMI_APPS="$apps" "$KROMI" apps | grep -q 'linked'
check $? "apps marks nothing as linked after unlink"

diff -r "$SANDBOX/config.before/hypr" "$XDG_CONFIG_HOME/hypr" >/dev/null
check $? "unlink restores configs byte for byte"

[[ ! -e $XDG_CONFIG_HOME/mako/config ]]
check $? "unlink removes configs that held only our line"

diff <(jq -S . "$SANDBOX/config.before/Code/User/settings.json") <(jq -S . "$settings") >/dev/null
check $? "unlink hands vscode settings back exactly as they were"

diff "$SANDBOX/config.before/vlc/vlcrc" "$vlcrc" >/dev/null
check $? "unlink puts vlcrc back, comment and default and all"

diff -r "$SANDBOX/mozilla.before" "$HOME/.mozilla" >/dev/null &&
  diff -r "$SANDBOX/config.before/mozilla" "$XDG_CONFIG_HOME/mozilla" >/dev/null
check $? "unlink puts the firefox profiles back byte for byte"

# Nothing may be written to a config that was never linked.
"$KROMI" set gruvbox >/dev/null
[[ $(jq -r '."workbench.colorCustomizations"."editor.background" // "none"' "$settings") == "none" ]]
check $? "set leaves vscode alone when it is not linked"

! grep -q 'prefers-color-scheme.content-override' "$profile/user.js"
check $? "set leaves firefox alone when it is not linked"

echo "firefox live loader"

# A stand-in for a firefox install: the loader goes beside the program, and
# what matters is that it lands, names itself, and comes back out.
FFAPP="$SANDBOX/ffapp"
mkdir -p "$FFAPP/defaults/pref"
printf '#!/bin/sh\n' >"$FFAPP/firefox"
chmod +x "$FFAPP/firefox"

KROMI_PATH=$ROOT KROMI_FIREFOX_APP=$FFAPP "$KROMI" firefox-live install >/dev/null
[[ -f $FFAPP/kromi-live.cfg && -f $FFAPP/defaults/pref/kromi-autoconfig.js ]]
check $? "the live loader installs beside the program"

grep -q '"general.config.filename", "kromi-live.cfg"' "$FFAPP/defaults/pref/kromi-autoconfig.js"
check $? "the bootstrap names the loader"

KROMI_PATH=$ROOT KROMI_FIREFOX_APP=$FFAPP "$KROMI" firefox-live status >"$SANDBOX/st.txt" 2>&1
grep -q '^loader    installed$' "$SANDBOX/st.txt"
check $? "status reports it in place"
grep -q '^loader    installed$' "$SANDBOX/st.txt" || sed 's/^/       /' "$SANDBOX/st.txt"

# There is one general.config.filename, and it may be somebody else's.
printf 'pref("general.config.filename", "theirs.cfg");\n' >"$FFAPP/defaults/pref/theirs.js"
! KROMI_PATH=$ROOT KROMI_FIREFOX_APP=$FFAPP "$KROMI" firefox-live install >/dev/null 2>&1
check $? "install refuses to take over another autoconfig"
rm -f "$FFAPP/defaults/pref/theirs.js"

KROMI_PATH=$ROOT KROMI_FIREFOX_APP=$FFAPP "$KROMI" firefox-live uninstall >/dev/null
[[ ! -e $FFAPP/kromi-live.cfg && ! -e $FFAPP/defaults/pref/kromi-autoconfig.js ]]
check $? "uninstall takes both files out again"

# The knock, against a socket that answers and one that does not. python3 is
# only standing in for a listening Firefox here.
if command -v python3 >/dev/null 2>&1; then
  mkdir -p "$XDG_RUNTIME_DIR/kromi"
  python3 -c '
import os, socket, sys
path = sys.argv[1]
s = socket.socket(socket.AF_UNIX)
s.bind(path)
s.listen(4)
conn, _ = s.accept()
conn.close()
open(sys.argv[2], "w").write("knocked")
' "$XDG_RUNTIME_DIR/kromi/firefox-1.sock" "$SANDBOX/knocked" &
  listener=$!
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    [[ -S $XDG_RUNTIME_DIR/kromi/firefox-1.sock ]] && break
    python3 -c 'import time; time.sleep(0.2)'
  done

  KROMI_PATH=$ROOT "$KROMI" firefox-live poke >/dev/null
  wait $listener 2>/dev/null
  [[ -f $SANDBOX/knocked ]]
  check $? "poke reaches a listening firefox"

  # Nothing is behind it now, and a socket nobody answers is one kromi would
  # knock on for the rest of the session.
  KROMI_PATH=$ROOT "$KROMI" firefox-live poke >/dev/null || true
  [[ ! -e $XDG_RUNTIME_DIR/kromi/firefox-1.sock ]]
  check $? "a socket with nobody behind it is cleared away"
fi

echo "neovim live reload"

# The one section that runs an app definition's real reload, because the
# reload is the whole of what is being tested. Safe to: the instances are
# started here, and the sockets it can reach are the sandbox's own.
if command -v nvim >/dev/null 2>&1; then
  themed_init="$SANDBOX/nvim-themed.lua"
  own_init="$SANDBOX/nvim-own.lua"
  printf 'pcall(dofile, "%s/kromi/current/neovim.lua")\n' "$XDG_STATE_HOME" >"$themed_init"
  # An init.lua is free to take a colorscheme of its own below kromi's line.
  # Spelled out rather than named, so the test does not turn on which schemes
  # a given nvim build ships.
  {
    cat "$themed_init"
    printf 'vim.g.colors_name = "sandbox"\n'
    printf 'vim.api.nvim_set_hl(0, "Normal", { bg = "#123456" })\n'
  } >"$own_init"

  live() { KROMI_APPS=neovim KROMI_PATH="$ROOT" "$KROMI" set "$1" >/dev/null; }

  # Started on one palette, so switching to another is what has to show up.
  live nord

  nvim --headless -u "$themed_init" >/dev/null 2>&1 &
  themed=$!
  # A config under NVIM_APPNAME names its socket for the app rather than for
  # nvim, and is reached by the same walk over running instances.
  NVIM_APPNAME=kromitest nvim --headless -u "$themed_init" >/dev/null 2>&1 &
  named=$!
  nvim --headless -u "$own_init" >/dev/null 2>&1 &
  own=$!

  socket_of() {
    local sock
    for sock in "$XDG_RUNTIME_DIR"/*."$1".[0-9]*; do
      [[ -S $sock ]] && {
        printf '%s\n' "$sock"
        return 0
      }
    done
    return 1
  }

  started=0
  for _ in $(seq 40); do
    if socket_of "$themed" >/dev/null && socket_of "$named" >/dev/null &&
      socket_of "$own" >/dev/null; then
      started=1
      break
    fi
    sleep 0.25
  done

  # What the instance is painting Normal with, which is the palette it is on.
  normal_bg() {
    local sock
    sock=$(socket_of "$1") || return 1
    timeout 5 nvim --server "$sock" --remote-expr \
      'luaeval("string.format(\"#%06x\", vim.api.nvim_get_hl(0, {name=\"Normal\"}).bg or 0)")'
  }

  if ((started)); then
    before=$(normal_bg "$themed")
    live gruvbox
    gruvbox_bg=$(palette_value "$ROOT/themes/gruvbox/colors.toml" background)

    [[ $before != "$gruvbox_bg" && $(normal_bg "$themed") == "$gruvbox_bg" ]]
    check $? "a running instance takes the new palette"

    [[ $(normal_bg "$named") == "$gruvbox_bg" ]]
    check $? "an instance under NVIM_APPNAME is reached too"

    [[ $(normal_bg "$own") == "#123456" ]]
    check $? "an instance with a colorscheme of its own is left on it"
  else
    echo "  skip neovim live reload (no instance came up)"
  fi

  kill "$themed" "$named" "$own" 2>/dev/null
  wait "$themed" "$named" "$own" 2>/dev/null
else
  echo "  skip neovim live reload (no nvim)"
fi

echo "interactive"

KROMI_APPS=dummy "$KROMI" set nord >/dev/null
KROMI_APPS=dummy "$KROMI" interactive 0 >"$SANDBOX/i.out" 2>/dev/null </dev/null

# Every theme kromi lists, which includes any the sandbox added.
"$KROMI" list >"$SANDBOX/i-list.txt"
[[ $(grep -c '^\[' "$SANDBOX/i.out") == "$(wc -l <"$SANDBOX/i-list.txt")" ]]
check $? "interactive visits every theme"

# Running to the end must not strand you on whichever theme sorts last.
[[ $("$KROMI" current) == nord ]]
check $? "interactive restores the theme it started from"

grep -q 'kromi set' "$SANDBOX/i.out"
check $? "interactive says how to apply one you liked"

! KROMI_APPS=dummy "$KROMI" interactive notanumber >/dev/null 2>&1 </dev/null
check $? "interactive rejects a non-numeric delay"

# Both short forms reach the same command.
KROMI_APPS=dummy "$KROMI" i 0 >"$SANDBOX/i-alias.out" 2>/dev/null </dev/null
KROMI_APPS=dummy "$KROMI" demo 0 >"$SANDBOX/demo-alias.out" 2>/dev/null </dev/null
diff -q "$SANDBOX/i-alias.out" "$SANDBOX/demo-alias.out" >/dev/null
check $? "i and demo are aliases for interactive"

# The keys only exist when there is a terminal to read them from, so these run
# kromi under a pty with the keystrokes queued ahead of it.
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

  KROMI_APPS=dummy "$KROMI" set nord >/dev/null
  KROMI_APPS=dummy pty x "$KROMI" i 5 >"$SANDBOX/i-auto.out" 2>&1 || true
  grep -q 'auto on, 5s' "$SANDBOX/i-auto.out"
  check $? "interactive with an interval starts rolling"

  KROMI_APPS=dummy pty x "$KROMI" i >"$SANDBOX/i-manual.out" 2>&1 || true
  ! grep -q 'auto on' "$SANDBOX/i-manual.out"
  check $? "interactive without one waits for a key"

  # It opens on the whole shelf: `kromi list`, star and all, before any key.
  # tr first: a terminal ends even a blank line with a carriage return.
  diff <(tr -d '\r' <"$SANDBOX/i-manual.out" | sed -n '1,/^$/p' | sed '/^$/d') \
    <(KROMI_APPS=dummy "$KROMI" list) >/dev/null
  check $? "interactive opens with the theme list, starred as list does"

  # The theme you arrived with is the first one printed, and named as such.
  [[ $(grep -m1 '^\[' "$SANDBOX/i-manual.out") == *"nord  (yours)"* ]]
  check $? "interactive marks the theme you started on"

  # tr, because a terminal ends its lines with a carriage return too.
  showing_of() { grep '^\[' "$1" | tail -1 | tr -d '\r' | awk '{print $2}'; }

  # r steps back to the theme you came with without ending the browse, so the
  # x that follows is what stops it — and stops it on yours.
  KROMI_APPS=dummy pty 'nnrx' "$KROMI" i >"$SANDBOX/i-restore.out" 2>&1 || true
  [[ $(showing_of "$SANDBOX/i-restore.out") == nord ]]
  check $? "r steps back to the theme you came with"

  grep -q '^kept nord' "$SANDBOX/i-restore.out"
  check $? "r keeps browsing, so x is still what ends it"

  [[ $(KROMI_APPS=dummy "$KROMI" current) == nord ]]
  check $? "r leaves the theme where it found it"

  # x stops on whatever is showing rather than on the one you came with.
  KROMI_APPS=dummy pty 'nx' "$KROMI" i >"$SANDBOX/i-keep.out" 2>&1 || true
  showing=$(showing_of "$SANDBOX/i-keep.out")
  grep -q "^kept $showing" "$SANDBOX/i-keep.out"
  check $? "x keeps the theme it was showing"

  [[ -n $showing && $showing != nord && $(KROMI_APPS=dummy "$KROMI" current) == "$showing" ]]
  check $? "x leaves the theme it stopped on"

  # Ctrl-C is x: the trap fires at once but does not make a blocked read
  # return, so a browse that waits on the keypress itself sits there ignoring
  # it.
  KROMI_APPS=dummy "$KROMI" set nord >/dev/null
  KROMI_APPS=dummy pty 'n\x03' "$KROMI" i >"$SANDBOX/i-int.out" 2>&1 || true
  grep -q '^kept ' "$SANDBOX/i-int.out"
  check $? "ctrl-c stops the browse"

  showing=$(showing_of "$SANDBOX/i-int.out")
  [[ -n $showing && $showing != nord && $(KROMI_APPS=dummy "$KROMI" current) == "$showing" ]]
  check $? "ctrl-c keeps the theme it was showing, not the one you came with"

  KROMI_APPS=dummy "$KROMI" set nord >/dev/null
else
  echo "  skip interactive key handling (no python3 for a pty)"
fi

echo "wallpaper selection"

BG="$XDG_CONFIG_HOME/kromi/wallpapers"
mkdir -p "$BG/nord"
echo x >"$BG/nord/1-first.jpg"
echo y >"$BG/nord/2-second.png"
echo z >"$BG/nord/3-third.jpg"

KROMI_APPS=dummy "$KROMI" set nord >/dev/null
[[ $("$KROMI" wallpaper) == "$BG/nord/1-first.jpg" ]]
check $? "set points the wallpaper link at the first image"

HP="$XDG_STATE_HOME/kromi/current/hyprpaper.conf"

grep -qxF "    path = $XDG_STATE_HOME/kromi/current/wallpaper" "$HP"
check $? "the wallpaper config names the link, not the image behind it"

grep -qxF 'splash = false' "$HP"
check $? "hyprpaper's own splash is turned off"

[[ $(KROMI_APPS=dummy "$KROMI" wallpaper next) == "2-second.png" ]]
check $? "wallpaper next advances"

KROMI_APPS=dummy "$KROMI" wallpaper next >/dev/null
[[ $(KROMI_APPS=dummy "$KROMI" wallpaper next) == "1-first.jpg" ]]
check $? "wallpaper next wraps around"

# What next stopped on is where the theme comes back to, and where set lands
# when the theme is applied again — not the first in the list.
KROMI_APPS=dummy "$KROMI" wallpaper next >/dev/null
KROMI_APPS=dummy "$KROMI" set gruvbox >/dev/null
KROMI_APPS=dummy "$KROMI" set nord >/dev/null
[[ $("$KROMI" wallpaper) == "$BG/nord/2-second.png" ]]
check $? "a theme remembers the wallpaper it was left on"

# A choice whose picture has gone falls back to the first, quietly.
rm "$BG/nord/2-second.png"
KROMI_APPS=dummy "$KROMI" set nord >/dev/null
[[ $("$KROMI" wallpaper) == "$BG/nord/1-first.jpg" ]]
check $? "a remembered wallpaper that is gone falls back to the first"
echo y >"$BG/nord/2-second.png"

# backgrounds/ is Omarchy's name for the directory, so a theme brought over
# from there finds its pictures without being renamed.
mkdir -p "$XDG_CONFIG_HOME/kromi/backgrounds/kanagawa"
echo k >"$XDG_CONFIG_HOME/kromi/backgrounds/kanagawa/omarchy.jpg"
KROMI_APPS=dummy "$KROMI" set kanagawa >/dev/null
[[ $("$KROMI" wallpaper) == "$XDG_CONFIG_HOME/kromi/backgrounds/kanagawa/omarchy.jpg" ]]
check $? "a backgrounds/ directory is read, as Omarchy names it"

# A theme nobody has pictures for must not break a switch.
KROMI_APPS=dummy "$KROMI" set gruvbox >/dev/null
check $? "set works for a theme with no wallpapers"

[[ ! -L $XDG_STATE_HOME/kromi/current/wallpaper ]]
check $? "no wallpaper link when there are no images"

# The sourced file has to exist even then: hyprpaper shrugs off a path it
# cannot resolve, but a source line with nothing behind it stops it starting.
[[ -f $HP ]]
check $? "the sourced file is written for a theme with no wallpaper"

echo "setup"

# Piped in, setup takes its defaults: link yes, fetch no. hyprpaper is not
# among the apps here, so the wallpaper step has to say why it did nothing.
KROMI_APPS="hyprland waybar" "$KROMI" setup nord >"$SANDBOX/setup.out" 2>&1 </dev/null
check $? "setup runs through without a terminal"

grep -q 'kromi/current' "$XDG_CONFIG_HOME/hypr/hyprland.lua" &&
  grep -q 'kromi/current' "$XDG_CONFIG_HOME/waybar/style.css"
check $? "setup links the detected apps by default"

grep -qx 'Wallpaper skipped: hyprpaper is not installed' "$SANDBOX/setup.out"
check $? "setup says so when nothing is there to show a wallpaper"

! grep -q 'edited in place' "$SANDBOX/setup.out"
check $? "setup does not mention in-place edits when no such app is detected"

KROMI_APPS="hyprland vscode vlc" "$KROMI" setup nord >"$SANDBOX/setup-inplace.out" 2>&1 </dev/null
grep -q 'vscode, vlc: a few settings edited in place' "$SANDBOX/setup-inplace.out"
check $? "setup says which apps get settings edited in place"
KROMI_APPS="hyprland vscode vlc" "$KROMI" unlink >/dev/null
KROMI_APPS="hyprland waybar" "$KROMI" unlink >/dev/null

# With hyprpaper there and pictures for the theme, it reports the one chosen.
KROMI_APPS=hyprpaper "$KROMI" setup nord >"$SANDBOX/setup.out" 2>&1 </dev/null
grep -q "^Wallpaper: $BG/nord/" "$SANDBOX/setup.out"
check $? "setup names the wallpaper when the theme has one"

# A wallpaper with no daemon up is a wallpaper nobody sees: setup offers to
# start it, and starts it by default, and says how to keep it started.
grep -q '^hyprpaper is not running' "$SANDBOX/setup.out" && [[ -f $XDG_STATE_HOME/started-hyprpaper ]]
check $? "setup starts the wallpaper daemon when it is not running"

# The fixture's start leaves running false, which is a start that did not
# take — and setup has to say that rather than claim a wallpaper is up.
grep -q '^hyprpaper did not start' "$SANDBOX/setup.out"
check $? "setup notices when the daemon does not come up"

grep -q 'exec-once = hyprpaper.*docs/integrations.md#hyprpaper' "$SANDBOX/setup.out"
check $? "setup says how to start the daemon at login, and where to read more"

# A start that takes is reported as one.
echo 'start() { touch "$XDG_STATE_HOME/running-$APP"; }' >>"$FIXTURE/apps/hyprpaper.sh"
KROMI_APPS=hyprpaper "$KROMI" setup nord >"$SANDBOX/setup-started.out" 2>&1 </dev/null
grep -q '^started hyprpaper$' "$SANDBOX/setup-started.out"
check $? "setup reports a daemon it started"
rm -f "$XDG_STATE_HOME/running-hyprpaper"

touch "$XDG_STATE_HOME/running-hyprpaper"
KROMI_APPS=hyprpaper "$KROMI" setup nord >"$SANDBOX/setup-running.out" 2>&1 </dev/null
! grep -q 'not running' "$SANDBOX/setup-running.out"
check $? "setup leaves a running daemon alone"
rm -f "$XDG_STATE_HOME/running-hyprpaper" "$XDG_STATE_HOME/started-hyprpaper"

# And with none, it offers to fetch, and does not without a yes.
KROMI_APPS=hyprpaper "$KROMI" setup gruvbox >"$SANDBOX/setup.out" 2>&1 </dev/null
grep -q '^No wallpaper for gruvbox' "$SANDBOX/setup.out" && grep -q 'kromi wallpaper fetch' "$SANDBOX/setup.out"
check $? "setup points at the fetch when a theme has no wallpaper"

[[ ! -d $BG/gruvbox ]]
check $? "setup does not fetch unless told to"

grep -q '^source = .*kromi/current/hyprpaper.conf$' "$XDG_CONFIG_HOME/hypr/hyprpaper.conf"
check $? "setup links hyprpaper even before there is a wallpaper"
KROMI_APPS=hyprpaper "$KROMI" unlink >/dev/null

# The closing lines say what is linked now, read back from the configs — so
# an app whose link failed is named, not buried under 'Done'.
KROMI_APPS="hyprland ghostty" "$KROMI" setup gruvbox >"$SANDBOX/setup-sum.out" 2>&1 </dev/null
grep -q '^Linked: hyprland ghostty$' "$SANDBOX/setup-sum.out" && ! grep -q '^Not linked' "$SANDBOX/setup-sum.out"
check $? "setup ends by listing what is linked"
KROMI_APPS="hyprland ghostty" "$KROMI" unlink >/dev/null

mv "$XDG_CONFIG_HOME/hypr/hyprland.lua" "$XDG_CONFIG_HOME/hypr/hyprland.lua.away"
KROMI_APPS="hyprland ghostty" "$KROMI" setup gruvbox >"$SANDBOX/setup-fail.out" 2>&1 </dev/null
grep -q '^Not linked: hyprland$' "$SANDBOX/setup-fail.out" && grep -q '^Linked: ghostty$' "$SANDBOX/setup-fail.out"
check $? "setup names an app whose link failed"
mv "$XDG_CONFIG_HOME/hypr/hyprland.lua.away" "$XDG_CONFIG_HOME/hypr/hyprland.lua"
KROMI_APPS="hyprland ghostty" "$KROMI" unlink >/dev/null

# Without a theme named, setup keeps the one already set.
[[ $("$KROMI" current) == gruvbox ]]
check $? "setup leaves the theme where it was when none is named"

# link used to refuse until set had run; a fresh install now starts on the
# default rather than being sent away to run another command first.
XDG_STATE_HOME="$SANDBOX/state-fresh" KROMI_APPS=probe "$KROMI" link >/dev/null 2>&1
[[ $(XDG_STATE_HOME="$SANDBOX/state-fresh" "$KROMI" current) == tokyo-night ]]
check $? "link on a fresh install renders the default theme first"

if command -v python3 >/dev/null 2>&1; then
  # A no at the prompt has to be a no: nothing linked, and told so.
  KROMI_APPS=hyprland pty 'n\n' "$KROMI" setup nord >"$SANDBOX/setup-no.out" 2>&1 || true
  ! grep -q 'kromi/current' "$XDG_CONFIG_HOME/hypr/hyprland.lua" && grep -q 'Not linked' "$SANDBOX/setup-no.out"
  check $? "setup at a terminal takes no for an answer"

  KROMI_APPS=hyprland pty '\n' "$KROMI" setup nord >"$SANDBOX/setup-yes.out" 2>&1 || true
  grep -q 'kromi/current' "$XDG_CONFIG_HOME/hypr/hyprland.lua"
  check $? "an empty answer takes the default, which links"
  KROMI_APPS=hyprland "$KROMI" unlink >/dev/null
fi

echo "wallpaper fetch"

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

export KROMI_WALLPAPERS_REPO="$SOURCE"
export KROMI_WALLPAPERS_REF="v-test"
fetch() { KROMI_PATH=$ROOT "$KROMI" wallpaper fetch "$@"; }
DEST="$XDG_CONFIG_HOME/kromi/wallpapers"

# gruvbox is the theme on screen and has had no picture until now.
KROMI_APPS=dummy "$KROMI" set gruvbox >/dev/null
fetch nord gruvbox >"$SANDBOX/fetch.out" 2>&1
[[ -f $DEST/nord/a.jpg && -f $DEST/nord/b.jpg && -f $DEST/gruvbox/c.jpg ]]
check $? "wallpapers are fetched into the user's wallpapers dir"

[[ $("$KROMI" wallpaper) == "$DEST/gruvbox/c.jpg" ]] && grep -q '^selected c.jpg for gruvbox$' "$SANDBOX/fetch.out"
check $? "a fetch for the theme on screen selects its wallpaper at once"

# Setup's fetch, accepted, is for the one theme it is configuring — not the
# collection. A terminal is needed to say yes: the link question takes its
# default, the fetch question gets a y, and the daemon question its default.
if command -v python3 >/dev/null 2>&1; then
  rm -rf "$DEST"
  KROMI_APPS=hyprpaper KROMI_PATH=$ROOT pty '\ny\n\n' "$KROMI" setup nord >"$SANDBOX/setup-fetch.out" 2>&1 || true
  [[ -f $DEST/nord/a.jpg && ! -e $DEST/gruvbox ]]
  check $? "setup fetches wallpapers for its theme only"

  grep -q "^Wallpaper: $DEST/nord/a.jpg" "$SANDBOX/setup-fetch.out"
  check $? "setup shows the wallpaper it fetched"
  KROMI_APPS=hyprpaper "$KROMI" unlink >/dev/null
fi

KROMI_PATH=$ROOT "$KROMI" wallpaper list >"$SANDBOX/wl.txt" 2>&1
grep -q '^nord *2$' "$SANDBOX/wl.txt" && grep -q '^gruvbox *1$' "$SANDBOX/wl.txt"
check $? "wallpaper list counts what is upstream"

# The whole point: a picture you put there yourself must survive a re-run.
echo "mine" >"$DEST/nord/a.jpg"
echo "also-mine" >"$DEST/nord/keep.jpg"
fetch nord >/dev/null 2>&1
[[ $(cat "$DEST/nord/a.jpg") == "mine" ]]
check $? "an existing file is never overwritten"

[[ -f $DEST/keep.jpg || -f $DEST/nord/keep.jpg ]]
check $? "a file with no upstream counterpart is left alone"

fetch no-such-theme >/dev/null 2>&1
check $? "a theme with nothing upstream is not an error"

[[ ! -d $DEST/no-such-theme ]]
check $? "no empty directory is left for a theme with nothing upstream"

echo "install"

# Against the checkout itself as the remote, so this stays offline. HOME is
# the sandbox already, which is where the defaults land.
INSTALL_HOME="$SANDBOX/install-home"
mkdir -p "$INSTALL_HOME"
if ! git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "  skip install (checkout is not a git repository)"
else
  HOME=$INSTALL_HOME KROMI_REPO=$ROOT PATH="$INSTALL_HOME/.local/bin:$PATH" \
    bash "$ROOT/install.sh" >"$SANDBOX/install.out" 2>&1
  check $? "install.sh runs through"

  [[ $(readlink "$INSTALL_HOME/.local/bin/kromi") == "$INSTALL_HOME/.local/share/kromi/bin/kromi" ]]
  check $? "install.sh clones and links kromi into ~/.local/bin"

  grep -q '^next: kromi setup$' "$SANDBOX/install.out" && ! grep -q 'not on your PATH' "$SANDBOX/install.out"
  check $? "install.sh points at setup rather than running it"

  HOME=$INSTALL_HOME KROMI_REPO=$ROOT PATH="/usr/bin:/bin" \
    bash "$ROOT/install.sh" >"$SANDBOX/install2.out" 2>&1
  grep -q '^updated ' "$SANDBOX/install2.out" && grep -q 'not on your PATH' "$SANDBOX/install2.out" && grep -q "^next: $INSTALL_HOME/.local/bin/kromi setup$" "$SANDBOX/install2.out"
  check $? "a second run updates in place and notices a PATH without ~/.local/bin"

  # A kromi of somebody else's on PATH is not ours to replace.
  OTHER_HOME="$SANDBOX/install-other"
  mkdir -p "$OTHER_HOME/.local/bin"
  printf '#!/bin/sh\necho theirs\n' >"$OTHER_HOME/.local/bin/kromi"
  chmod +x "$OTHER_HOME/.local/bin/kromi"
  ! HOME=$OTHER_HOME KROMI_REPO=$ROOT bash "$ROOT/install.sh" >/dev/null 2>&1 &&
    [[ ! -L $OTHER_HOME/.local/bin/kromi && $("$OTHER_HOME/.local/bin/kromi") == theirs ]]
  check $? "install.sh refuses to replace a kromi that is not a link into its checkout"

  # Nor is a directory with a .git in it a checkout of kromi.
  NOT_KROMI="$SANDBOX/not-kromi"
  mkdir -p "$NOT_KROMI"
  git -C "$NOT_KROMI" init -q
  ! HOME=$OTHER_HOME KROMI_DIR=$NOT_KROMI bash "$ROOT/install.sh" >"$SANDBOX/install3.out" 2>&1 &&
    grep -q 'not a kromi checkout' "$SANDBOX/install3.out"
  check $? "install.sh refuses a directory that is not kromi"

  # The linked copy has to be a working kromi, not just a file.
  [[ $(HOME=$INSTALL_HOME XDG_CONFIG_HOME=$INSTALL_HOME/.config XDG_STATE_HOME=$INSTALL_HOME/.local/state \
    KROMI_PATH= KROMI_APPS=probe "$INSTALL_HOME/.local/bin/kromi" set nord 2>/dev/null) == "kromi: Nord" ]]
  check $? "the installed kromi runs from its own checkout"
fi

echo
printf '%s passed, %s failed\n' "$pass" "$fail"
[[ $fail == 0 ]]
