templates="btop.theme"

config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/btop"

reload() { signal_reload btop; }

# btop only loads themes from its own themes dir, so this one links a file
# rather than adding an import.
link() {
  mkdir -p "$config_dir/themes"
  ln -snf "$(theme_file btop.theme)" "$config_dir/themes/kromi.theme"
  set_kv "$config_dir/btop.conf" color_theme '"kromi"'
}

unlink() {
  rm -f "$config_dir/themes/kromi.theme"
  set_kv "$config_dir/btop.conf" color_theme '"Default"'
}

linked() {
  [[ -L $config_dir/themes/kromi.theme ]] &&
    grep -qE '^color_theme *= *"kromi"' "$config_dir/btop.conf" 2>/dev/null
}
