# Extending kromi

Everything kromi ships—themes, templates, and app definitions—can be
overridden by a matching item under `~/.config/kromi/`. You can therefore
customize or extend kromi without changing its checkout.

## Add a theme

A theme is a directory containing `colors.toml`. Put custom themes in
`~/.config/kromi/themes/<name>/`. A user theme with the same name as a shipped
theme takes precedence.

### Required colors

A palette requires 22 values: six named roles and the 16 terminal colors.

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

### Optional roles

Shipped themes also define surface and text roles that the 16 terminal colors
cannot always express well:

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

Every role in this second block is optional. Missing roles fall back to the
nearest palette color—for example, `muted` falls back to `color8`, while
`lighter_background` falls back to `color0`. A theme containing only the 22
required values still renders every template.

Explicit roles are useful when a fallback would give one color conflicting
jobs. A terminal color might otherwise act as both a surface and dim text,
making one of those uses difficult to read.

The names `red`, `green`, `yellow`, `blue`, `magenta`, and `cyan`, together
with their `bright_` variants, are aliases for `color1` through `color14`.
The numbered values remain authoritative.

### Wallpapers

A theme may ship a `wallpapers/` directory (or `backgrounds/`, as Omarchy's
themes do). Images under `~/.config/kromi/wallpapers/<name>/` take precedence
over images shipped with the theme.

### Override a generated file

A theme can provide a complete generated app file instead of using its
template. For example, place `waybar.css` beside `colors.toml` to use that file
verbatim for the theme.

## Customize templates

Templates are plain text files containing `{{ key }}` substitutions. Shipped
templates live under `templates/`. Override one by placing a file with the
same name under `~/.config/kromi/templates/`.

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

`dim_text` is selected independently for each palette. kromi considers
`dark_foreground`, `muted`, and `color8`, choosing the dimmest candidate that
still stands apart from the background. If none meets the contrast threshold,
it chooses the candidate that differs most from the background.

Use `dim_text` for comments, line numbers, and placeholders. Use `muted` for
borders and separators.

## Add an app

An app integration is a shell file in `apps/`. Put personal integrations in
`~/.config/kromi/apps/`. A user definition with the same name as a shipped one
takes precedence.

### Minimal definition

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

The template belongs at `templates/foo.conf.tpl`, or at
`~/.config/kromi/templates/foo.conf.tpl` for a personal integration. It can use
the substitutions described under [Customize templates](#customize-templates).

### Link status

`kromi apps` calls `linked` to report whether each app is connected. The
default implementation checks whether `$include` appears as a line in
`$config`, which is correct for the minimal definition above.

An integration that uses another connection mechanism—such as a symlink, a
backup file, or several imports—must define its own `linked` function.

Set `in_place=1` when `link` edits settings instead of adding an include. This
allows `kromi setup` to disclose the direct edit before asking for permission.

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

The functions `detect`, `reload`, `link`, `unlink`, and `linked` all have
defaults and can be overridden by an app definition.

### Wallpaper integrations

Set `uses_wallpaper=1` when the integration shows the current wallpaper; this
makes `kromi wallpaper apply` and `kromi wallpaper next` call its `reload`
function. It also tells `kromi setup` whether offering wallpapers is useful.

### Detection and rendering

Detection controls which installed apps are linked and reloaded automatically.
It does not control rendering. kromi renders output for every known app so a
config never points at a missing file merely because detection failed during
a switch.

Override detection completely in `~/.config/kromi/config` when needed:

```sh
KROMI_APPS="waybar mako foo"
```

### Test an integration

```sh
./test/run.sh
```

The test suite uses a temporary XDG environment and does not signal your
running desktop. Neovim reload tests start separate headless instances on
sockets inside that environment.
