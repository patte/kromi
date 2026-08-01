templates="neovim.lua"

config="${XDG_CONFIG_HOME:-$HOME/.config}/nvim/init.lua"
include='pcall(dofile, (os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state")) .. "/narchy/current/neovim.lua")'

detect() { command -v nvim >/dev/null 2>&1; }

# Running instances keep the old colours; there is no reload channel that does
# not need a server address we have not got. New ones start themed.
reload() { :; }

# Prepended, so a colorscheme set further down init.lua still wins.
link() { prepend_line "$config" "$include"; }
unlink() { drop_line "$config" "$include"; }
