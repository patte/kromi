templates="palette.css wofi.css"

style="${XDG_CONFIG_HOME:-$HOME/.config}/wofi/style.css"
palette_import="@import \"$(theme_file palette.css)\";"
theme_import="@import \"$(theme_file wofi.css)\";"

# wofi starts fresh each invocation.
reload() { :; }

link() {
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
