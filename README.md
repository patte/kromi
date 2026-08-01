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
ln -s ~/.local/share/narchy/bin/narchy-backgrounds ~/.local/bin/narchy-backgrounds
```

The second one is optional and does nothing unless you run it — see Wallpapers.

## Use

```
narchy set <theme>      render the palette and reload running apps
narchy list             list themes, marking the current one
narchy demo [seconds]   browse themes: n/p step, a auto, o keep, x restore
                        with seconds, starts rolling at that interval
narchy current          print the current theme
narchy background next  cycle to this theme's next wallpaper
narchy background apply reapply the current one (for autostart)
narchy apps             list app definitions, marking detected ones
narchy link [app...]    point app configs at narchy's output (opt-in)
narchy unlink [app...]  undo link
```

## Picking one

```sh
narchy demo        # step by hand, a key at a time
narchy demo 8      # roll on its own, 8 seconds a theme
```

Applies a theme, prints its name, and waits for a key:

```
n next   p prev   a auto   1-9 secs   o keep   x restore

[13/19] osaka-jade  (yours)
[14/19] retro-82
```

| Key | |
|---|---|
| `n` / `p` | step forwards or backwards, wrapping around |
| `a` | toggle rolling on by itself |
| `1`–`9` | seconds between steps in auto |
| `o` | stop here and keep this theme |
| `x` | stop and put back the one you started with |

It begins on your current theme — marked `(yours)`, since that is where `x`
comes back to — so `p` reaches the one before it. Naming an interval starts it
rolling at that interval; with no interval it steps by hand until you press
`a`, then every 3 seconds. Ctrl-C behaves like `o`: quitting abruptly should
not undo a theme you stopped on to look at. The names stay in your scrollback
either way, so one you liked and missed is a `narchy set <name>` away.

With no terminal to read keys from — piped, or from a script — it just rolls
through unattended and restores what you had at the end.

## Two layers, on purpose

`narchy set` **only ever writes inside `~/.local/state/narchy/current/`.** It
renders one file per app from the palette and reloads whatever is running. It
never edits a config of yours.

VS Code is the single exception, and only once you have linked it — see below.

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
| neovim | `~/.config/nvim/init.lua` | `pcall(dofile, (os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state")) .. "/narchy/current/neovim.lua")` |
| vscode | `~/.config/Code/User/settings.json` | no line — see below |

GTK stylesheets need absolute paths — `~` is not expanded there, so use the full
path in the waybar and wofi imports.

Two things about order. CSS is last-wins, so the palette import goes at the top
where `@define-color` names must be declared before use, and the overrides go at
the bottom where they can beat the stylesheet already in place. Everything else
is prepended, so anything you write below it stays in charge.

Pre-0.5x Hyprland uses `hyprland.conf` and `source =` instead; narchy detects
which one you have and renders to match.

### Why VS Code is different

VS Code cannot include another settings file, and it caches themes by id —
reselecting one hands back the colours it parsed the first time rather than
rereading the file. A generated theme extension therefore leaves the editor a
palette behind until you reload the window. `workbench.colorCustomizations` is
the one thing it applies immediately.

So narchy merges three keys — `workbench.colorCustomizations`,
`editor.tokenColorCustomizations` and `workbench.colorTheme` — into your
`settings.json`, and does it again on every switch. Everything else in the file
is left alone. `narchy link vscode` saves whatever those three keys held first,
and `narchy unlink vscode` puts them back.

Customisations replace only the keys they name, and a key VS Code defines in
terms of another one — `editorGutter.background` is `editor.background`,
`breadcrumb.background` likewise — takes its value from the theme underneath
rather than from ours. So the template names every surface it can, which is why
one colour key you set yourself may be overwritten while linked, and why
`colorTheme` is set to stock Light or Dark Modern to match the palette. That
last one is the only thing colours cannot do for themselves: webviews —
markdown preview, notebook output, extension panels — take their light or dark
from the theme's kind, not from any colour, and would stay dark under a light
palette.

This only ever happens after linking. Until then `narchy set` does not open
your `settings.json` at all.

### neovim

The generated colorscheme is derived from the palette, so it needs no plugin
manager, no network and no colorscheme plugin — it works in a bare nvim and
covers any palette, including your own. Running instances keep their colours;
new ones start themed.

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

Those 22 are all a theme needs. The shipped ones also carry a handful of names
the 16 slots cannot express — a surface a shade off the background, dim text
that is not the same colour as that surface, a selection tint:

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

Every one of them is optional and falls back to its nearest slot — `muted` to
`color8`, `lighter_background` to `color0` — so a palette that names only the
22 renders every template. Naming them is how a theme stops the fallbacks
guessing: in several palettes `color0` and `color8` hold the same value, which
puts dim text on a surface of exactly its own colour.

The hue names — `red`, `green`, `yellow`, `blue`, `magenta`, `cyan` and their
`bright_` forms — are always aliases for `color1`–`color14`, so templates can
read as what they mean. Only the slots are authoritative.

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

## Wallpapers

narchy ships none. They are not the project's to hand out: a palette is a list
of hex codes, but a wallpaper is someone's photograph or artwork, and an
upstream set that mixes freely licensed photography with film stills and
paintings cannot be relicensed by whoever collected it.

`narchy-backgrounds` fetches them instead, so the files come from their source
rather than from here:

```sh
narchy-backgrounds --list          # what is available, and how many
narchy-backgrounds                 # every theme narchy knows about
narchy-backgrounds nord kanagawa   # just these
```

They land in `~/.config/narchy/backgrounds/<theme>/`. **Nothing already there
is ever overwritten**, so pictures you put there yourself survive a re-run —
only names that do not exist yet are added.

Defaults to Omarchy v3.8.4. Point it elsewhere with `NARCHY_BACKGROUNDS_REPO`
and `NARCHY_BACKGROUNDS_REF`; any repository laid out as
`themes/<name>/backgrounds/` will do, including one of your own.

Downloading art does not license it. Fetching means narchy is not the one
distributing these files, but they still belong to the people who made them,
and a few in the upstream set are plainly not free to redistribute. Use your
judgement, particularly if you are putting the result somewhere public.

### Setting them

`narchy set` points `~/.local/state/narchy/current/background` at the first
image for that theme, and `narchy background next` cycles through the rest.
Which daemon puts it on screen is an app definition like any other; hyprpaper
ships, and a theme may carry its own `backgrounds/` directory instead of
relying on yours.

hyprpaper needs no linking — it is driven over IPC, because hyprpaper 0.8.4
does not read `hyprpaper.conf` at all (a deliberately invalid one raises no
complaint and no wallpaper appears). That also means it starts blank, so
autostart both:

```
exec-once = hyprpaper
exec-once = narchy background apply
```

A theme with no images just gets no wallpaper; nothing fails.

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

hyprland, hyprpaper, waybar, wofi, mako, ghostty, btop, neovim, vscode.

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
