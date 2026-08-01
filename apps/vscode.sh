templates="vscode.json"

settings="${XDG_CONFIG_HOME:-$HOME/.config}/Code/User/settings.json"
backup="$NARCHY_STATE/vscode-settings-backup.json"

detect() { command -v code >/dev/null 2>&1; }

# VS Code has no way to include another settings file, and it caches themes by
# id — reselecting one serves the cached colours rather than rereading the
# file, so shipping a generated theme extension leaves the editor a palette
# behind. colorCustomizations is the one mechanism it applies immediately.
#
# That makes this the only app narchy writes a config for on `set`. It happens
# solely once vscode has been linked, which is what the backup marks.
apply() {
  local generated
  generated=$(theme_file vscode.json)
  [[ -f $generated ]] || return 0
  command -v jq >/dev/null 2>&1 || return 1

  [[ -e $settings ]] || {
    mkdir -p "$(dirname "$settings")"
    printf '{}\n' >"$settings"
  }

  # Merge our colours over any already there, and leave the rest of the file
  # alone. tokenColorCustomizations is replaced outright, which is what the
  # backup is for.
  if ! jq --slurpfile new "$generated" '
        ."workbench.colorCustomizations" =
          ((."workbench.colorCustomizations" // {}) + $new[0]["workbench.colorCustomizations"])
        | ."editor.tokenColorCustomizations" = $new[0]["editor.tokenColorCustomizations"]
      ' "$settings" >"$settings.narchy-tmp" 2>/dev/null; then
    rm -f "$settings.narchy-tmp"
    warn "cannot parse $settings; leaving it alone"
    return 1
  fi
  mv "$settings.narchy-tmp" "$settings"
}

reload() {
  [[ -f $backup ]] || return 0
  apply
}

link() {
  # Remember what was there, so unlink can hand it back rather than guess.
  if [[ ! -f $backup ]]; then
    mkdir -p "$(dirname "$backup")"
    if [[ -f $settings ]] && command -v jq >/dev/null 2>&1; then
      jq '{"workbench.colorCustomizations": ."workbench.colorCustomizations",
           "editor.tokenColorCustomizations": ."editor.tokenColorCustomizations"}' \
        "$settings" >"$backup" 2>/dev/null || printf '{}\n' >"$backup"
    else
      printf '{}\n' >"$backup"
    fi
  fi
  apply
}

unlink() {
  [[ -f $settings ]] || return 0
  command -v jq >/dev/null 2>&1 || return 0

  if [[ -f $backup ]]; then
    jq --slurpfile old "$backup" '
      . as $s
      | reduce ("workbench.colorCustomizations", "editor.tokenColorCustomizations") as $k
          ($s; if ($old[0][$k] == null) then del(.[$k]) else .[$k] = $old[0][$k] end)
    ' "$settings" >"$settings.narchy-tmp" 2>/dev/null &&
      mv "$settings.narchy-tmp" "$settings" || rm -f "$settings.narchy-tmp"
    rm -f "$backup"
  fi
}
