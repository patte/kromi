# kromi

Beautiful and simple theming for Hyprland and your favorite apps.

The included themes and template-driven approach come from
[Omarchy](https://github.com/basecamp/omarchy), adapted here into a standalone
tool.

```sh
kromi set tokyo-night
```

kromi is Bash and sed. There is nothing to compile and no daemon. It does not
install software or assume a distribution, and it leaves app configs alone
unless you ask it to connect them.

https://github.com/user-attachments/assets/ed646693-63d0-411f-a5fc-e57ae086aa4b

## Supported apps

| App | What kromi styles | When a switch appears |
|---|---|---|
| Hyprland | borders and the bare desktop | immediately |
| Hyprpaper | wallpaper | immediately |
| Waybar | bar | immediately |
| Wofi | launcher | next launch |
| Mako | notifications | immediately |
| Ghostty | terminal | immediately |
| btop | terminal UI | immediately |
| Neovim | editor | immediately while using kromi |
| VS Code | editor and workbench | immediately |
| VLC | light or dark Qt palette | after restart |
| Firefox | browser chrome and internal pages | after restart, or immediately with `kromi firefox-live` |

VS Code, VLC, and Firefox cannot consume a generated config as directly as the
other apps. kromi handles them without taking over the rest of their settings;
see [App integrations](docs/integrations.md) for the exact trade-offs.

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/patte/kromi/main/install.sh | bash
```

That clones kromi into `~/.local/share/kromi` and links `kromi` into
`~/.local/bin`; run it again to update. It is only ever these two lines, if
you would rather do them yourself:

```sh
git clone https://github.com/patte/kromi ~/.local/share/kromi
mkdir -p ~/.local/bin && ln -s ~/.local/share/kromi/bin/kromi ~/.local/bin/kromi
```

## Quick start

```sh
kromi setup
```

That sets Tokyo Night, lists the apps it found, asks whether to connect their
configs, and — if Hyprpaper is installed — offers to fetch wallpapers. Every
question defaults to the safe answer, and `kromi unlink` undoes the
connections. From then on, switching is one command:

```sh
kromi set nord
kromi interactive      # or browse: n/p step, a auto, r restore, x keep
```

If you would rather wire your configs yourself, skip `setup` and add the lines
from [App integrations](docs/integrations.md#manual-setup) instead.

## Usage

```sh
kromi set <theme>        # render and apply a theme
kromi list               # list themes and mark the current one
kromi current            # print the current theme
kromi interactive        # browse themes and keep the one you stop on

kromi apps               # list integrations: * detected, and linked or not
kromi link [app...]      # connect detected or named apps
kromi unlink [app...]    # remove those connections

kromi wallpaper next     # cycle through the current theme's wallpapers
kromi wallpaper fetch    # download wallpaper sets (needs git)
```

## Wallpapers

kromi ships none: a palette is a list of numbers, a wallpaper is somebody's
picture. Put your own under `~/.config/kromi/wallpapers/<theme>/`, or fetch
the sets Omarchy uses with `kromi wallpaper fetch [theme...]`. Existing files
are never overwritten. A theme without pictures still applies; Hyprland paints
the bare desktop in the palette's background instead.

Fetched images are for your own use — the collection mixes freely licensed
photography with artwork that is not. Point `KROMI_WALLPAPERS_REPO` and
`KROMI_WALLPAPERS_REF` at another repository laid out as
`themes/<name>/backgrounds/` to fetch from somewhere else.

## How it works

`kromi set` renders one file per app under `~/.local/state/kromi/current/`,
swaps the complete theme into place, and reloads detected apps. It does not
edit their configs.

`kromi link` makes the small, app-specific config change that points an app at
those generated files. This separation keeps theme switching safe for people
who manage dotfiles themselves. VS Code, VLC, and Firefox are the documented
exceptions because those apps do not provide ordinary config includes.

## Customize and extend

- [App integrations](docs/integrations.md) — manual setup, app-specific
  behaviour, and live Firefox switching.
- [Extending kromi](docs/extending.md) — add a theme, customize a template,
  or write a new app definition.

User files under `~/.config/kromi/` shadow shipped files of the same name, so
customizations do not require changing the checkout.

## Tests

```sh
./test/run.sh
```

The suite uses a throwaway XDG root and does not signal your running desktop.

## Credit

The palettes and template-and-sed approach come from
[Omarchy](https://github.com/basecamp/omarchy),
MIT licensed. kromi extracts that idea into a standalone tool: no distribution,
no opinions about which bar or launcher you run, and app configs left alone
unless you ask. See [NOTICE](NOTICE).
