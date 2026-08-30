# Themes and templates

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

## Override a generated file

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
| `{{ background_image }}` | the absolute path of the current wallpaper link |

`dim_text` is selected independently for each palette. kromi chooses the
dimmest of `dark_foreground`, `muted`, and `color8` that still stands apart
from the background, or the most distinct candidate if none clears its
threshold. Use it for comments, line numbers, and placeholders. Use `muted`
for borders and separators.
