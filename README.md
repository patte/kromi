# narchy

Apply one colour palette across a desktop's apps — bar, launcher, notifications,
terminal, compositor — with a single command.

```sh
narchy set tokyo-night
```

The engine is bash and sed. There is nothing to compile and no daemon. It does
not install software, manage your configs, or care which distribution you run:
it recolours whatever it finds.

## Install

```sh
git clone https://github.com/patte/narchy ~/.local/share/narchy
ln -s ~/.local/share/narchy/bin/narchy ~/.local/bin/narchy
```

## Use

```
narchy set <theme>      render the palette and reload running apps
narchy list             list themes, marking the current one
narchy current          print the current theme
narchy apps             list app definitions, marking detected ones
narchy link [app...]    point app configs at narchy's output (opt-in)
narchy unlink [app...]  undo link
```

## Two layers, on purpose

`narchy set` **only ever writes inside `~/.local/state/narchy/current/`.** It
renders one file per app from the palette and reloads whatever is running. It
never edits a config of yours.

For those generated files to matter, each app's own config has to point at them.
That is one line per app, and it is a separate command — `narchy link` — because
plenty of people keep their dotfiles under version control or configuration
management and want to write that line themselves.

So: run `narchy link` once and forget about it, or skip it forever and add the
lines below to your own configs. Both are first-class.

## Wiring it by hand

Paths assume the default `XDG_STATE_HOME`. `narchy link` writes exactly these.

| App | Config | Line |
|---|---|---|
| waybar | `~/.config/waybar/style.css` | `@import "~/.local/state/narchy/current/palette.css";` at the **top**, `@import "~/.local/state/narchy/current/waybar.css";` at the **bottom** |
| wofi | `~/.config/wofi/style.css` | same two, same order |
| mako | `~/.config/mako/config` | `include=~/.local/state/narchy/current/mako.ini` |
| ghostty | `~/.config/ghostty/config` | `config-file = ?"~/.local/state/narchy/current/ghostty.conf"` |
| hyprland | `~/.config/hypr/hyprland.lua` | `pcall(dofile, (os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state")) .. "/narchy/current/hyprland.lua")` |
| btop | `~/.config/btop/btop.conf` | symlink `~/.local/state/narchy/current/btop.theme` into `~/.config/btop/themes/`, then set `color_theme` to its name |

GTK stylesheets need absolute paths — `~` is not expanded there, so use the full
path in the waybar and wofi imports.

Two things about order. CSS is last-wins, so the palette import goes at the top
where `@define-color` names must be declared before use, and the overrides go at
the bottom where they can beat the stylesheet already in place. Everything else
is prepended, so anything you write below it stays in charge.

Pre-0.5x Hyprland uses `hyprland.conf` and `source =` instead; narchy detects
which one you have and renders to match.

## Themes

A theme is a directory holding a `colors.toml`:

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

Drop your own in `~/.config/narchy/themes/<name>/`. That directory shadows the
shipped one, so a theme of the same name replaces it.

A theme may also ship a finished file instead of letting a template generate it
— put `waybar.css` in the theme directory and it is used verbatim.

## Templates

Templates live in `templates/` and are plain text with `{{ key }}` holes. Every
palette key is available in three forms:

| Form | Example output |
|---|---|
| `{{ background }}` | `#1a1b26` |
| `{{ background_strip }}` | `1a1b26` |
| `{{ background_rgb }}` | `26,27,38` |

Override any of them from `~/.config/narchy/templates/`.

## Adding an app

An app is one file in `apps/`, or in `~/.config/narchy/apps/` for your own. It
declares which templates it wants and how to reload itself:

```sh
templates="foo.conf"

config="${XDG_CONFIG_HOME:-$HOME/.config}/foo/config"
include="include $(tilde "$(theme_file foo.conf)")"

detect() { command -v foo >/dev/null; }   # the default, if you omit it
reload() { pkill -HUP -x foo || true; }

link()   { prepend_line "$config" "$include"; }
unlink() { drop_line "$config" "$include"; }
```

`theme_file`, `tilde`, `prepend_line`, `append_line`, `drop_line`, `seed_file`
and `set_kv` are available to app files. Apps whose `detect` fails are skipped,
so an app file costs nothing on a machine that lacks the program.

Set `NARCHY_APPS="waybar mako"` in `~/.config/narchy/config` to override
detection entirely.

## Supported out of the box

hyprland, waybar, wofi, mako, ghostty, btop.

## Tests

```sh
./test/run.sh
```

Runs against a throwaway XDG root and never signals a running session.

## Credit

The palettes and the template-and-sed approach come from
[Omarchy](https://github.com/basecamp/omarchy) by David Heinemeier Hansson, MIT
licensed. narchy extracts that idea into a standalone tool: no distribution, no
opinions about which bar or launcher you run, and app configs left alone unless
you ask. See NOTICE.
