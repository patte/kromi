templates="neovim.lua"

config="${XDG_CONFIG_HOME:-$HOME/.config}/nvim/init.lua"
include='pcall(dofile, (os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state")) .. "/narchy/current/neovim.lua")'

detect() { command -v nvim >/dev/null 2>&1; }

# There is a server address after all: nvim listens on one from the moment it
# starts, with no --listen and no plugin, and tells you where by naming the
# socket after the process — <appname>.<pid>.<n> in $XDG_RUNTIME_DIR. So the
# running instances are the running nvims, found the same way waybar's are,
# and reloading them is telling each one to read the file again.
#
# Walking the pids rather than globbing nvim.* covers a config running under
# NVIM_APPNAME, whose socket is named for the app and not for nvim, and skips
# the sockets an instance that crashed left behind.
#
# --remote-expr and not --remote-send, whose keys arrive as typed: someone in
# insert mode would have the reload typed into their buffer.
#
# `and` rather than an `if`, because luaeval takes an expression. Only the
# instances still wearing narchy's colours are touched — an init.lua that
# picks a colorscheme below our line has already overridden us there, and a
# theme switch is no reason to take that window off it.
#
# timeout, because a busy instance — at a hit-enter prompt, waiting on a :!
# command — answers whenever it next reaches its loop, and `set` must not wait
# that long. That one keeps its colours until the next switch or a :source.
reload() {
  local file run pid sock
  file=$(theme_file neovim.lua)
  [[ -f $file ]] || return 0

  # Without XDG_RUNTIME_DIR nvim picks a temporary directory of its own, and
  # a guess at which one is worth less than leaving the instance alone.
  run=${XDG_RUNTIME_DIR:-}
  [[ -d $run ]] || return 0

  while read -r pid; do
    for sock in "$run"/*."$pid".[0-9]*; do
      [[ -S $sock ]] || continue
      timeout 2 nvim --server "$sock" --remote-expr \
        "luaeval('vim.g.colors_name == \"narchy\" and pcall(dofile, _A)', '$file')" \
        >/dev/null 2>&1 || true
    done
  done < <(pgrep -x nvim 2>/dev/null)
}

# Prepended, so a colorscheme set further down init.lua still wins.
link() { prepend_line "$config" "$include"; }
unlink() { drop_line "$config" "$include"; }
