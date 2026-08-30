templates="palette.css waybar.css"

style="${XDG_CONFIG_HOME:-$HOME/.config}/waybar/style.css"
palette_import="@import \"$(theme_file palette.css)\";"
theme_import="@import \"$(theme_file waybar.css)\";"

reload() { signal_reload waybar; }

link() {
  # Without a seed, creating style.css would drop waybar's own layout rules.
  seed_file "$style" /etc/xdg/waybar/style.css
  prepend_line "$style" "$palette_import"
  append_line "$style" "$theme_import"
}

unlink() {
  linked || return 2
  drop_line "$style" "$palette_import"
  drop_line "$style" "$theme_import"
}

linked() {
  [[ -f $style ]] && grep -qxF "$palette_import" "$style" && grep -qxF "$theme_import" "$style"
}
