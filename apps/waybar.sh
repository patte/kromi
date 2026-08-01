templates="palette.css waybar.css"

style="${XDG_CONFIG_HOME:-$HOME/.config}/waybar/style.css"
palette_import="@import \"$(theme_file palette.css)\";"
theme_import="@import \"$(theme_file waybar.css)\";"

reload() { pkill -SIGUSR2 -x waybar 2>/dev/null || true; }

link() {
  # Without a seed, creating style.css would drop waybar's own layout rules.
  seed_file "$style" /etc/xdg/waybar/style.css
  prepend_line "$style" "$palette_import"
  append_line "$style" "$theme_import"
}

unlink() {
  drop_line "$style" "$palette_import"
  drop_line "$style" "$theme_import"
}
