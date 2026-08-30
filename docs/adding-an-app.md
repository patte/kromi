# Adding an app

An app integration is a shell file in `apps/`. Put personal integrations under
`~/.config/kromi/apps/`; user files shadow shipped definitions with the same
name.

A minimal definition declares the templates it needs, where the app config
lives, and how to reload and connect it:

```sh
templates="foo.conf"

config="${XDG_CONFIG_HOME:-$HOME/.config}/foo/config"
include="include $(tilde "$(theme_file foo.conf)")"

detect() { command -v foo >/dev/null; }   # the default if omitted
reload() { pkill -HUP -x foo || true; }

link()   { prepend_line "$config" "$include"; }
unlink() { drop_line "$config" "$include"; }
```

Its template belongs at `templates/foo.conf.tpl`, or at
`~/.config/kromi/templates/foo.conf.tpl` for a personal integration. See
[Themes and templates](themes.md#customize-templates) for available
substitutions.

## Available helpers

App definitions can use:

| Helper | Purpose |
|---|---|
| `theme_file <name>` | absolute path to a generated file in the current theme |
| `tilde <path>` | replace the home-directory prefix with `~` |
| `seed_file <destination> <source>` | create a missing config from a default file, or empty |
| `prepend_line <file> <line>` | add an idempotent line at the beginning |
| `append_line <file> <line>` | add an idempotent line at the end |
| `drop_line <file> <line>` | remove an exact line and clean up an empty file |
| `set_kv <file> <key> <value>` | replace or append a `key = value` setting |
| `set_json <file> <key> <value>` | set one JSON key with `jq` |
| `drop_json <file> <key>` | remove one JSON key with `jq` |
| `signal_reload <process> [signal]` | signal a process and restart it if the reload kills it |

Set `uses_background=1` when the integration consumes the current wallpaper;
this makes `kromi background apply` and `next` call its `reload` function.

Detection controls which installed apps are linked and reloaded automatically.
It does not control rendering: kromi renders output for every known app so a
config never points at a missing file merely because detection failed during a
switch.

Users can override detection completely in `~/.config/kromi/config`:

```sh
KROMI_APPS="waybar mako foo"
```

## Test the integration

Run the complete suite with:

```sh
./test/run.sh
```

Tests use a temporary XDG environment and avoid signaling the running desktop.
The Neovim reload tests start their own headless instances on sockets inside
that environment.
