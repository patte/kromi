uses_background=1

link_path="$(theme_file background)"

detect() { command -v hyprpaper >/dev/null 2>&1; }

# IPC only. hyprpaper 0.8.4 does not read hyprpaper.conf at all — a deliberately
# invalid one raises no complaint and no wallpaper is set — so writing static
# directives there would leave dead lines in someone's config and nothing on
# screen. That is also why login needs `narchy background apply`.
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

link() {
  warn "hyprpaper needs no config; add to your hyprland config instead:"
  warn "    exec-once = hyprpaper"
  warn "    exec-once = narchy background apply"
}

unlink() { :; }
