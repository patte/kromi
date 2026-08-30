templates="hyprpaper.conf"
uses_wallpaper=1

config="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hyprpaper.conf"
include="source = $(tilde "$(theme_file hyprpaper.conf)")"

link_path="$(theme_file wallpaper)"

detect() { command -v hyprpaper >/dev/null 2>&1; }

# For setup, which offers to start it: a linked hyprpaper that is not running
# shows nothing, and a wallpaper that never appears looks like a bug.
running() { pgrep -x hyprpaper >/dev/null 2>&1; }
start() { setsid hyprpaper >/dev/null 2>&1 & }
autostart_hint='exec-once = hyprpaper in hyprland.conf, or hl.exec_cmd("hyprpaper") in hyprland.lua'

# Config for a cold start, IPC for a warm one: hyprpaper reads its config once,
# at startup, so a daemon already running has to be told. That split is why a
# login needs nothing of kromi's — hyprpaper puts the wallpaper back itself.
#
# hyprpaper caches by path and the symlink's path never changes, so unload
# first or it keeps showing the image that link used to point at. The resolved
# path is handed over for the same reason.
reload() {
  local image
  pgrep -x hyprpaper >/dev/null 2>&1 || return 0
  image=$(readlink -f "$link_path" 2>/dev/null) || return 0
  [[ -f $image ]] || return 0

  hyprctl hyprpaper unload all >/dev/null 2>&1 || true
  hyprctl hyprpaper preload "$image" >/dev/null 2>&1 || true
  hyprctl hyprpaper wallpaper ",$image" >/dev/null 2>&1 || true
}

# Sourcing a file that is not there is the one config error hyprpaper refuses
# to start on — a missing image it merely complains about. So check rather than
# hand someone a daemon that will not come up.
link() {
  local sourced
  sourced=$(theme_file hyprpaper.conf)
  [[ -f $sourced ]] || {
    warn "no $sourced to source; run 'kromi set <theme>' first"
    return 1
  }
  prepend_line "$config" "$include"
}

unlink() { drop_line "$config" "$include"; }
