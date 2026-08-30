templates="mako.ini"

config="${XDG_CONFIG_HOME:-$HOME/.config}/mako/config"
# mako wants an absolute path or one starting with ~/.
include="include=$(tilde "$(theme_file mako.ini)")"

reload() { makoctl reload 2>/dev/null || true; }

# Prepended: in mako the last matching option wins, so anything below stays in charge.
link() { prepend_line "$config" "$include"; }
