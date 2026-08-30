templates="firefox.css firefox-content.css firefox.conf"

# Where the profiles live. Firefox has moved to the XDG directories and still
# reads the old location, so take whichever is there rather than pick — both,
# if a machine has both. KROMI_FIREFOX_HOME overrides with a root of your own,
# or several: librewolf keeps its profiles in ~/.librewolf, a flatpak Firefox
# in ~/.var/app/org.mozilla.firefox/.mozilla/firefox.
firefox_homes() {
  if [[ -n ${KROMI_FIREFOX_HOME:-} ]]; then
    printf '%s\n' ${KROMI_FIREFOX_HOME}
    return 0
  fi
  local dir
  for dir in "${XDG_CONFIG_HOME:-$HOME/.config}/mozilla/firefox" "$HOME/.mozilla/firefox"; do
    [[ -f $dir/profiles.ini ]] && printf '%s\n' "$dir"
  done
  return 0
}

# One file per linked profile, holding the pref line as kromi found it. Both
# the record unlink restores from and the mark that says this profile has been
# linked, which is what keeps `set` off an unlinked one.
marks="$KROMI_STATE/firefox"

# A symlink in the profile's own chrome directory, imported by a relative URL,
# rather than an @import naming kromi's file where it lies. userContent.css
# is applied to content documents, which are loaded by a sandboxed process
# that may not read outside the profile: an absolute file:// import there is
# fetched by nobody and fails silently — the chrome sheet, loaded by the
# parent process, would have been happy with one. Same shape for both, so
# there is one thing to know rather than two.
chrome_link="kromi.css"
content_link="kromi-content.css"
chrome_import="@import url(\"$chrome_link\");"
content_import="@import url(\"$content_link\");"

# Without this Firefox does not read userChrome.css or userContent.css at all.
stylesheets_pref='user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);'

# What websites are told to render as. The colours above cannot say it: a page
# picks its own light or dark from prefers-color-scheme, which follows the
# browser theme, and kromi installs no theme for it to follow. 0 is dark, 1
# light — Settings writes the same pref from its Website appearance radio.
scheme_key="layout.css.prefers-color-scheme.content-override"

detect() { command -v firefox >/dev/null 2>&1; }

# Every profile profiles.ini names, absolute. Install sections carry Default=
# rather than Path=, so this picks up profiles and nothing else. All of them:
# which one a launcher opens is not ours to guess, and a palette that misses
# the profile you actually use is worse than one written twice.
profiles() {
  local home path
  while read -r home; do
    [[ -f $home/profiles.ini ]] || continue
    while IFS= read -r path; do
      [[ -n $path ]] || continue
      if [[ $path == /* ]]; then
        printf '%s\n' "$path"
      else
        printf '%s/%s\n' "$home" "$path"
      fi
    done < <(tr -d '\r' <"$home/profiles.ini" | sed -n 's/^[[:space:]]*Path=//p')
  done < <(firefox_homes)
}

# user.js is a list of user_pref() calls read at startup, the last one for a
# key winning. Ours is rewritten in place when it is already there, so a
# switch replaces the value rather than stacking another line on it.
set_pref() {
  local file=$1 key=$2 value=$3 line
  line="user_pref(\"$key\", $value);"
  mkdir -p "$(dirname "$file")"
  [[ -e $file ]] || : >"$file"
  if grep -q "^user_pref(\"$key\"," "$file"; then
    sed -i -E "s|^user_pref\(\"$key\",.*|$line|" "$file"
  else
    # Prepended, so anything written below it still wins.
    prepend_line "$file" "$line"
  fi
}

value_for_mode() {
  local generated mode
  generated=$(theme_file firefox.conf)
  [[ -f $generated ]] || return 1
  mode=$(sed -n 's/^mode=//p' "$generated")
  [[ $mode == dark ]] && printf '0\n' || printf '1\n'
}

apply() {
  local told=${1:-0} value profile linked=0
  value=$(value_for_mode) || return 0

  while read -r profile; do
    [[ -f $marks/$(basename "$profile") ]] || continue
    set_pref "$profile/user.js" "$scheme_key" "$value"
    linked=1
  done < <(profiles)

  # Not when the live loader answered: it has already been told, and telling
  # someone to restart a browser that just changed colour is nonsense.
  if ((linked && !told)) && pgrep -x firefox >/dev/null 2>&1; then
    warn "firefox is open; it reads its stylesheets and prefs at startup, so restart it to see this"
  fi
  return 0
}

# Knock, if the live loader is listening. It is opt-in and installed by hand,
# so the usual case is that there is no socket directory to look in and this
# costs a test on a path.
knock() {
  [[ -d ${XDG_RUNTIME_DIR:-/tmp}/kromi ]] || return 1
  "$KROMI_BIN" firefox-live poke >/dev/null 2>&1
}

# There is no reload of Firefox's own, and no new window to fall back on
# either: the stylesheets are parsed once per run and cached for every window
# after, so a switch shows up when Firefox next starts. Unless the live loader
# is in, which is what the knock is for. The rest is the write of the one thing
# `set` has to keep up to date, and only for a profile already linked.
reload() {
  local told=0
  knock && told=1
  apply "$told"
}

# The live loader is the other way to do all this, and the two do not compose:
# a sheet imported by userChrome.css is loaded before one registered later and
# wins, so a linked profile pins the palette Firefox opened with and the loader
# looks broken. `kromi firefox-live install` says as much from its side when it
# installs over a linked profile. This is the half that matters to a bare
# `kromi link`, which would otherwise shadow a working loader without a word —
# and it asks that command rather than going looking, so there is one idea of
# where Firefox is installed instead of two.
live_installed() { "$KROMI_BIN" firefox-live installed 2>/dev/null; }

link() {
  local profile name found=0

  if live_installed; then
    warn "the firefox-live loader is installed; linking would shadow it"
    warn "leave firefox to the loader, or 'kromi firefox-live uninstall' first"
    return 1
  fi

  while read -r profile; do
    [[ -d $profile ]] || continue
    found=1
    name=$(basename "$profile")

    # Remember the pref as it stood, so unlink hands it back rather than
    # guessing. Empty means it was not set, which unlink spells by removing.
    if [[ ! -f $marks/$name ]]; then
      mkdir -p "$marks"
      if [[ -f $profile/user.js ]]; then
        grep "^user_pref(\"$scheme_key\"," "$profile/user.js" >"$marks/$name" || : >"$marks/$name"
      else
        : >"$marks/$name"
      fi
    fi

    mkdir -p "$profile/chrome"
    ln -snf "$(theme_file firefox.css)" "$profile/chrome/$chrome_link"
    ln -snf "$(theme_file firefox-content.css)" "$profile/chrome/$content_link"

    # @import has to come before any rule, so these are prepended whether or
    # not the file already has some — appending would see them dropped.
    prepend_line "$profile/chrome/userChrome.css" "$chrome_import"
    prepend_line "$profile/chrome/userContent.css" "$content_import"
    prepend_line "$profile/user.js" "$stylesheets_pref"
  done < <(profiles)

  ((found)) || {
    warn "no firefox profiles found; start firefox once, then link it"
    return 1
  }
  apply
}

unlink() {
  local profile name
  while read -r profile; do
    name=$(basename "$profile")
    [[ -f $marks/$name ]] || continue

    drop_line "$profile/chrome/userChrome.css" "$chrome_import"
    drop_line "$profile/chrome/userContent.css" "$content_import"
    drop_line "$profile/user.js" "$stylesheets_pref"
    rm -f "$profile/chrome/$chrome_link" "$profile/chrome/$content_link"

    if [[ -f $profile/user.js ]]; then
      if [[ -s $marks/$name ]]; then
        sed -i -E "s|^user_pref\(\"$scheme_key\",.*|$(head -1 "$marks/$name")|" "$profile/user.js"
      else
        sed -i -E "/^user_pref\(\"$scheme_key\",/d" "$profile/user.js"
      fi
      [[ -s $profile/user.js ]] || rm -f "$profile/user.js"
    fi

    rmdir "$profile/chrome" 2>/dev/null || true
    rm -f "$marks/$name"
  done < <(profiles)
  rmdir "$marks" 2>/dev/null || true
}
