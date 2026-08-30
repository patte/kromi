templates="vscode.json"

settings="${XDG_CONFIG_HOME:-$HOME/.config}/Code/User/settings.json"
backup="$KROMI_STATE/vscode-settings-backup.json"

detect() { command -v code >/dev/null 2>&1; }

# VS Code has no way to include another settings file, and it caches themes by
# id — reselecting one serves the cached colours rather than rereading the
# file, so shipping a generated theme extension leaves the editor a palette
# behind. colorCustomizations is the one mechanism it applies immediately.
#
# That makes this the only app kromi writes a config for on `set`. It happens
# solely once vscode has been linked, which is what the backup marks.
#
# The cost of customisations is that they layer over whatever colour theme is
# active, and only the keys named get replaced. Worse, a key whose default is
# defined as another colour — editorGutter.background is editor.background,
# breadcrumb.background likewise — resolves against the theme underneath, not
# against our value for the colour it points at. Left unnamed they keep the
# base theme's, which is why the template writes them out even though they
# only repeat {{ background }}: without them a light palette leaves a black
# gutter down the side of a white editor.
#
# So the template names every surface it can, and colorTheme is set to the
# stock Light or Dark Modern to match the palette's mode. That is the one
# thing colours cannot do for themselves: webviews — markdown preview,
# notebook output, extension panels — style themselves from the theme's kind
# rather than from any colour we name, and would stay dark under a light
# palette. It is also the only setting here that was likely deliberate, so
# link backs it up and unlink puts it back.
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
  # alone. tokenColorCustomizations and colorTheme are replaced outright,
  # which is what the backup is for.
  if ! jq --slurpfile new "$generated" '
        ."workbench.colorCustomizations" =
          ((."workbench.colorCustomizations" // {}) + $new[0]["workbench.colorCustomizations"])
        | ."editor.tokenColorCustomizations" = $new[0]["editor.tokenColorCustomizations"]
        | if $new[0]["workbench.colorTheme"] then
            ."workbench.colorTheme" = $new[0]["workbench.colorTheme"]
          else . end
      ' "$settings" >"$settings.kromi-tmp" 2>/dev/null; then
    rm -f "$settings.kromi-tmp"
    warn "cannot parse $settings; leaving it alone"
    return 1
  fi
  mv "$settings.kromi-tmp" "$settings"
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
           "editor.tokenColorCustomizations": ."editor.tokenColorCustomizations",
           "workbench.colorTheme": ."workbench.colorTheme"}' \
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
      | reduce ("workbench.colorCustomizations", "editor.tokenColorCustomizations",
                "workbench.colorTheme") as $k
          ($s; if ($old[0][$k] == null) then del(.[$k]) else .[$k] = $old[0][$k] end)
    ' "$settings" >"$settings.kromi-tmp" 2>/dev/null &&
      mv "$settings.kromi-tmp" "$settings" || rm -f "$settings.kromi-tmp"
    rm -f "$backup"
  fi
}
