# Extending kromi

Everything kromi ships — themes, templates, app definitions — can be shadowed
by a file of the same name under `~/.config/kromi/`, so nothing here requires
changing the checkout.

## Add a theme

A theme is a directory containing `colors.toml`. Put custom themes under
`~/.config/kromi/themes/<name>/`; a user theme with the same name as a shipped
one replaces it.

The required palette contains 22 values:

```toml
accent = "#7aa2f7"
cursor = "#c0caf5"
foreground = "#a9b1d6"
background = "#1a1b26"
selection_foreground = "#c0caf5"
selection_background = "#7aa2f7"

color0 = "#32344a"
# ... through color15
```

Shipped themes also define some surfaces and text roles that the 16 terminal
slots cannot always express well:

```toml
selection = "#292e42"
muted = "#414868"
lighter_background = "#24283b"
dark_background = "#13141c"
darker_background = "#0e0e14"
light_foreground = "#b4bee6"
dark_foreground = "#565f89"
bright_foreground = "#c0caf5"
orange = "#eb927b"
brown = "#75493d"
```

Every additional value is optional and falls back to its nearest palette slot,
such as `muted` to `color8` and `lighter_background` to `color0`. A theme with
only the required values still renders every template. Explicit roles avoid
poor fallbacks in palettes where, for example, a terminal slot is both a
surface and the proposed dim-text color.

The names `red`, `green`, `yellow`, `blue`, `magenta`, `cyan` and their
`bright_` variants are aliases for `color1` through `color14`. The numbered
slots remain authoritative.

A theme may ship a `wallpapers/` directory (or `backgrounds/`, as Omarchy's
themes do); pictures under `~/.config/kromi/wallpapers/<name>/` come first.

### Override a generated file

A theme can ship a completed app file instead of using its template. For
example, placing `waybar.css` beside `colors.toml` uses that file verbatim for
the theme.

## Customize templates

Templates are plain text files with `{{ key }}` substitutions. Project
templates live under `templates/`; override one by placing a file of the same
name under `~/.config/kromi/templates/`.

Every palette value is available in three forms:

| Form | Example output |
|---|---|
| `{{ background }}` | `#1a1b26` |
| `{{ background_strip }}` | `1a1b26` |
| `{{ background_rgb }}` | `26,27,38` |

kromi also derives:

| Key | Value |
|---|---|
| `{{ mode }}` | `light` or `dark`, based on background brightness |
| `{{ mode_title }}` | the capitalized mode |
| `{{ dim_text }}` | a legible, recessed text color for the palette |
| `{{ wallpaper }}` | the absolute path of the current wallpaper link |

`dim_text` is selected independently for each palette. kromi chooses the
dimmest of `dark_foreground`, `muted`, and `color8` that still stands apart
from the background, or the most distinct candidate if none clears its
threshold. Use it for comments, line numbers, and placeholders. Use `muted`
for borders and separators.

## Add an app

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
`~/.config/kromi/templates/foo.conf.tpl` for a personal integration.

### Available helpers

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

Set `uses_wallpaper=1` when the integration shows the current wallpaper; this
makes `kromi wallpaper apply` and `next` call its `reload` function, and lets
`kromi setup` know whether a wallpaper is worth offering.

Detection controls which installed apps are linked and reloaded automatically.
It does not control rendering: kromi renders output for every known app so a
config never points at a missing file merely because detection failed during a
switch.

Users can override detection completely in `~/.config/kromi/config`:

```sh
KROMI_APPS="waybar mako foo"
```

### Test the integration

```sh
./test/run.sh
```

Tests use a temporary XDG environment and avoid signaling the running desktop.
The Neovim reload tests start their own headless instances on sockets inside
that environment.
