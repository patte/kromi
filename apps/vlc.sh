templates="vlc.conf"

vlcrc="${XDG_CONFIG_HOME:-$HOME/.config}/vlc/vlcrc"
backup="$NARCHY_STATE/vlc-dark-palette-backup"

detect() { command -v vlc >/dev/null 2>&1; }

# VLC gets a side of light and dark, not a palette. `qt-dark-palette` swaps
# Qt's own palette wholesale and is the only thing the Qt interface offers —
# there is no colour in it to set, so mode is all narchy has to say.
#
# There is no include either, and no reload: the interface reads vlcrc when it
# starts and never looks again, so a switch lands in the file at once and shows
# up the next time VLC opens. The write is not at risk from a VLC already
# running — quitting one leaves vlcrc byte for byte as it was — but the player
# in front of you keeps the palette it started with, which is what the warning
# is for. Saving preferences from VLC's own dialog is the thing that rewrites
# the file, and it writes narchy's key along with everything else.
#
# set_kv is no good here: vlcrc is `key=value` with no spaces, and the key
# ships commented out, which is how VLC spells a default. Rewriting that line
# in place keeps it in the [qt] section where it belongs — appending would put
# it under whichever module happened to come last.
value_for_mode() {
  local generated mode
  generated=$(theme_file vlc.conf)
  [[ -f $generated ]] || return 1
  mode=$(sed -n 's/^mode=//p' "$generated")
  [[ $mode == dark ]] && printf '1\n' || printf '0\n'
}

write_key() {
  local value=$1
  mkdir -p "$(dirname "$vlcrc")"
  if [[ -f $vlcrc ]] && grep -qE '^#?qt-dark-palette=' "$vlcrc"; then
    sed -i -E "s|^#?qt-dark-palette=.*|qt-dark-palette=$value|" "$vlcrc"
  elif [[ -f $vlcrc ]] && grep -qE '^\[qt\]' "$vlcrc"; then
    # `a` rather than a substitution: the section header carries a trailing
    # comment, and replacing the match would strand it on our line.
    sed -i "/^\[qt\]/a qt-dark-palette=$value" "$vlcrc"
  else
    printf '[qt]\nqt-dark-palette=%s\n' "$value" >>"$vlcrc"
  fi
}

apply() {
  local value
  value=$(value_for_mode) || return 0
  write_key "$value"
  if pgrep -x vlc >/dev/null 2>&1; then
    warn "vlc is open; it reads vlcrc only at startup, so restart it to see this"
  fi
}

reload() {
  [[ -f $backup ]] || return 0
  apply
}

# The backup is both the record and the mark that vlc has been linked. Empty
# means the key was not there to begin with, which unlink puts back by removing
# ours rather than writing a value nobody chose.
link() {
  if [[ ! -f $backup ]]; then
    mkdir -p "$(dirname "$backup")"
    if [[ -f $vlcrc ]]; then
      grep -E '^#?qt-dark-palette=' "$vlcrc" >"$backup" || : >"$backup"
    else
      : >"$backup"
    fi
  fi
  apply
}

unlink() {
  [[ -f $backup ]] || return 0
  if [[ -f $vlcrc ]]; then
    if [[ -s $backup ]]; then
      local original
      original=$(head -1 "$backup")
      sed -i -E "s|^#?qt-dark-palette=.*|$original|" "$vlcrc"
    else
      sed -i -E '/^#?qt-dark-palette=/d' "$vlcrc"
    fi
  fi
  rm -f "$backup"
}
