hypr_dir="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"

# 0.5x reads hyprland.lua and only falls back to hyprland.conf when there is none.
if [[ -f $hypr_dir/hyprland.conf && ! -f $hypr_dir/hyprland.lua ]]; then
  templates="hyprland.conf"
  config="$hypr_dir/hyprland.conf"
  include="source = $(tilde "$(theme_file hyprland.conf)")"
else
  templates="hyprland.lua"
  config="$hypr_dir/hyprland.lua"
  # dofile re-runs on every reload, unlike require, which caches. pcall keeps a
  # missing file from taking the whole config down.
  include='pcall(dofile, (os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state")) .. "/narchy/current/hyprland.lua")'
fi

reload() { hyprctl reload >/dev/null 2>&1 || true; }

link() {
  [[ -f $config ]] || die_hint
  prepend_line "$config" "$include"
}

unlink() { drop_line "$config" "$include"; }

die_hint() {
  printf 'narchy: no %s to link into\n' "$config" >&2
  return 1
}
