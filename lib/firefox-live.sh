# kromi firefox-live — make a running Firefox follow `kromi set`.
#
# Sourced by `kromi` for this one subcommand, and kept out of `kromi link` on
# purpose. Everything link does happens inside your home directory and undoes
# itself. This does not: Firefox only runs privileged JavaScript from its own
# install directory, so the loader goes in beside the program, as root, and a
# package update that replaces that directory takes it away again.
#
# What it buys is the one thing linking cannot do. Firefox parses
# userChrome.css once per run and caches it for every window after, so a linked
# profile shows a switch at its next start. The loader watches kromi's output
# and registers it into the windows already open, which makes a switch land
# while you are looking at it.

SOURCE="$KROMI_PATH/apps/firefox-live.cfg"
CFG="kromi-live.cfg"
BOOTSTRAP="defaults/pref/kromi-autoconfig.js"

# Where a listening Firefox puts its socket, one per process.
KNOCKS="${XDG_RUNTIME_DIR:-/tmp}/kromi"

say() { printf '%s\n' "$*"; }

usage() {
  cat <<'USAGE'
kromi firefox-live [install|uninstall|status]

  install     put the loader in Firefox's install directory (needs root)
  uninstall   take it back out
  status      say whether it is there, whether it is current, who is listening
  installed   say nothing, and exit 0 if the loader is in — what
              `kromi link firefox` asks before it refuses to shadow one
  poke        tell every listening firefox to look now — kromi does this
              itself on every `set`, so it is here to be run by hand

Then restart Firefox once. After that every `kromi set` recolours the windows
already open, without a restart and without kromi writing to your profile.

Firefox is told rather than left to watch: it listens on a unix socket under
$XDG_RUNTIME_DIR/kromi, and kromi opens a connection to it. That needs socat,
a netcat with -U, or python3. Without one of those the loader falls back to
looking at the file, which works just as well and costs a wakeup a second.

`kromi link firefox` is the other way to do this: no root, nothing outside
your home, and a switch shows up the next time Firefox starts. Use one or the
other — a sheet imported by userChrome.css is loaded first and wins, which
pins the palette Firefox opened with. Run `kromi unlink firefox` before this.

  KROMI_FIREFOX_APP   Firefox's install directory, if it is somewhere unusual
USAGE
}

# Where the program itself lives, which is not where `firefox` on your PATH
# is: distributions ship a wrapper script there.
app_dir() {
  local dir
  for dir in ${KROMI_FIREFOX_APP:-} /usr/lib64/firefox /usr/lib/firefox \
    /usr/lib64/firefox-esr /usr/lib/firefox-esr /opt/firefox /usr/local/lib/firefox; do
    [[ -x $dir/firefox ]] && {
      printf '%s\n' "$dir"
      return 0
    }
  done
  return 1
}

# Root only where root is needed: a Firefox unpacked into a directory of your
# own is writable already, and asking for a password to write there is theatre.
as_root() {
  local dir=$1
  shift
  if [[ $EUID -eq 0 || -w $dir ]]; then
    "$@"
  else
    command -v sudo >/dev/null 2>&1 || die "need root to write in $dir, and no sudo"
    sudo "$@"
  fi
}

# Somebody else's AutoConfig — an enterprise policy, a userChrome.js loader —
# uses the same one pref, and there is only one of it. Say so rather than take
# it over.
conflicting_bootstrap() {
  local dir=$1 file
  while read -r file; do
    [[ -n $file ]] || continue
    [[ $file == "$dir/$BOOTSTRAP" ]] && continue
    printf '%s\n' "$file"
    return 0
  done < <(grep -rl 'general\.config\.filename' "$dir/defaults/pref" 2>/dev/null)
  return 1
}

# Only to warn with: the profile roots kromi itself looks in.
linked_profiles() {
  local -a roots
  if [[ -n ${KROMI_FIREFOX_HOME:-} ]]; then
    roots=(${KROMI_FIREFOX_HOME})
  else
    roots=("${XDG_CONFIG_HOME:-$HOME/.config}/mozilla/firefox" "$HOME/.mozilla/firefox")
  fi
  local root
  for root in "${roots[@]}"; do
    [[ -d $root ]] || continue
    grep -l '@import url("kromi\.css");' "$root"/*/chrome/userChrome.css 2>/dev/null || true
  done
}

# Opening the connection is the whole message, so anything that can open a
# unix socket will do. socat first because it behaves the same everywhere;
# nc's -U is spelled differently by each of the netcats; python3 is the one
# most likely to be there when neither is.
knock() {
  local sock=$1
  if command -v socat >/dev/null 2>&1; then
    socat -u /dev/null "UNIX-CONNECT:$sock" 2>/dev/null
  elif command -v nc >/dev/null 2>&1 && nc -h 2>&1 | grep -q -- '-U'; then
    nc -U -w 1 "$sock" </dev/null >/dev/null 2>&1
  elif command -v python3 >/dev/null 2>&1; then
    python3 -c 'import socket, sys
s = socket.socket(socket.AF_UNIX)
s.connect(sys.argv[1])
s.close()' "$sock" 2>/dev/null
  else
    return 2
  fi
}

listeners() {
  local sock
  for sock in "$KNOCKS"/firefox-*.sock; do
    [[ -S $sock ]] && printf '%s\n' "$sock"
  done
  return 0
}

# Whether the loader is in, quietly, for `kromi link firefox` to ask before it
# shadows one. State on disk rather than anything kromi remembers: a Firefox
# update replaces the install directory and takes the loader with it, so a mark
# kept elsewhere would go on claiming it was there.
#
# Out of date still counts as installed. An older loader is one that has to be
# reinstalled, not one a linked profile may quietly override.
installed() {
  local dir
  dir=$(app_dir) || return 1
  [[ -f $dir/$CFG && -f $dir/$BOOTSTRAP ]]
}

can_knock() {
  command -v socat >/dev/null 2>&1 && return 0
  command -v nc >/dev/null 2>&1 && nc -h 2>&1 | grep -q -- '-U' && return 0
  command -v python3 >/dev/null 2>&1
}

# Called by the app definition on every `kromi set`, so it says nothing and
# costs nothing when there is nobody to tell.
cmd_poke() {
  local sock reached=0 rc
  while read -r sock; do
    [[ -n $sock ]] || continue
    knock "$sock" && {
      reached=$((reached + 1))
      continue
    }
    rc=$?
    ((rc == 2)) && die "nothing here can open a unix socket — install socat"
    # Nobody behind it: a firefox that went away without tidying up.
    rm -f "$sock"
  done < <(listeners)
  ((reached > 0))
}

cmd_status() {
  local dir
  dir=$(app_dir) || die "no firefox install found; set KROMI_FIREFOX_APP"
  say "firefox   $dir"

  if installed; then
    if cmp -s "$SOURCE" "$dir/$CFG"; then
      say "loader    installed"
    else
      say "loader    installed, and out of date — run install again"
    fi
  else
    say "loader    not installed"
  fi

  local count
  count=$(listeners | grep -c . || true)
  if ((count > 0)); then
    say "listening $count firefox process(es), in $KNOCKS"
  else
    say "listening nothing — start firefox, or it is watching the file instead"
  fi
  can_knock || say "knocking  no socat, nc -U or python3 — nothing can tell it"

  local linked
  linked=$(linked_profiles)
  [[ -n $linked ]] && say "linked    $(printf '%s\n' "$linked" | wc -l) profile(s) still import kromi.css — see below"
  return 0
}

cmd_install() {
  local dir conflict
  dir=$(app_dir) || die "no firefox install found; set KROMI_FIREFOX_APP"
  [[ -f $SOURCE ]] || die "missing $SOURCE"

  if conflict=$(conflicting_bootstrap "$dir"); then
    die "$conflict already sets general.config.filename; remove it first, or merge by hand"
  fi

  as_root "$dir" install -m 0644 "$SOURCE" "$dir/$CFG"
  as_root "$dir" install -d -m 0755 "$dir/defaults/pref"
  # Written rather than shipped: it is three lines, and they name the file above.
  as_root "$dir" tee "$dir/$BOOTSTRAP" >/dev/null <<EOF
// Installed by kromi firefox-live. Points Firefox at $CFG beside the program.
pref("general.config.filename", "$CFG");
pref("general.config.obscure_value", 0);
pref("general.config.sandbox_enabled", false);
EOF

  say "installed in $dir"

  local linked
  linked=$(linked_profiles)
  if [[ -n $linked ]]; then
    say ""
    say "run 'kromi unlink firefox' first: a sheet imported by userChrome.css is"
    say "loaded before this one and wins, which pins the palette Firefox started"
    say "with. These profiles still import it:"
    printf '  %s\n' $linked
  fi

  can_knock || {
    say ""
    say "no socat, nc -U or python3 here, so nothing can knock: the loader will"
    say "fall back to looking at the file a couple of times a second instead."
  }

  say ""
  say "restart firefox once. after that, every 'kromi set' lands in the windows"
  say "already open. a firefox update replaces $dir, so run this again after one."
}

cmd_uninstall() {
  local dir
  dir=$(app_dir) || die "no firefox install found; set KROMI_FIREFOX_APP"
  if [[ ! -e $dir/$CFG && ! -e $dir/$BOOTSTRAP ]]; then
    say "nothing installed in $dir"
    return 0
  fi
  as_root "$dir" rm -f "$dir/$CFG" "$dir/$BOOTSTRAP"
  say "removed from $dir"
  say "the palette stays until firefox restarts, and the sheets are still rendered"
  say "— 'kromi link firefox' is the way to keep them without this."
}

firefox_live_main() {
  case ${1:-status} in
    install) cmd_install ;;
    uninstall | remove) cmd_uninstall ;;
    poke) cmd_poke ;;
    status) cmd_status ;;
    installed) installed ;;
    help | -h | --help) usage ;;
    *) die "unknown command: ${1} (try 'kromi firefox-live help')" ;;
  esac
}
