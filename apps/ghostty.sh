templates="ghostty.conf"

config="${GHOSTTY_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/ghostty/config}"
# The ? makes it optional, so ghostty still starts before the first `narchy set`.
include="config-file = ?\"$(tilde "$(theme_file ghostty.conf)")\""

reload() { signal_reload ghostty; }

link() { prepend_line "$config" "$include"; }
unlink() { drop_line "$config" "$include"; }
