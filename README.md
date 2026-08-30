# kromi

Beautiful and simple theming for Hyprland and your favorite apps.

The included themes and template-driven approach come from
[Omarchy](https://github.com/basecamp/omarchy), adapted here into a standalone
tool.

```sh
kromi set tokyo-night
```

kromi is Bash and sed. There is nothing to compile and no daemon. It does not
install software or assume a distribution. The only change it makes to an
app's config is one pointer line — added when you ask, listed in full under
[What link edits](#what-link-edits), and removed by `kromi unlink`.

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
`~/.local/bin`; run it again to update. If you would rather do them yourself:

```sh
git clone https://github.com/patte/kromi ~/.local/share/kromi
mkdir -p ~/.local/bin && ln -s ~/.local/share/kromi/bin/kromi ~/.local/bin/kromi
```

## Quick start

```sh
kromi setup
```

That lists the apps it found and asks whether to edit their configs (see
[What link edits](#what-link-edits)), asks about Firefox's live loader, offers
to fetch wallpapers if Hyprpaper is installed, applies Tokyo Night, and then
offers to browse the themes so you can pick one. Nothing changes on screen
until the questions are answered, and `kromi unlink` undoes the edits. From
then on, switching is one command:

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

## What link edits

`kromi link` — and `kromi setup`, after asking — is the only thing that
touches a file outside kromi's own directories. This is all of it:

| App | File | Change |
|---|---|---|
| Hyprland | `~/.config/hypr/hyprland.lua` (or `.conf`) | one `pcall(dofile, …)` / `source =` line prepended; refuses if the file does not exist |
| Hyprpaper | `~/.config/hypr/hyprpaper.conf` | one `source =` line prepended; the file is created if absent |
| Waybar | `~/.config/waybar/style.css` | seeded from `/etc/xdg/waybar/style.css` if absent; `@import palette.css` at the top, `@import waybar.css` at the bottom |
| Wofi | `~/.config/wofi/style.css` | the same two imports |
| Mako | `~/.config/mako/config` | one `include=` line prepended |
| Ghostty | `~/.config/ghostty/config` | one `config-file = ?…` line prepended |
| Neovim | `~/.config/nvim/init.lua` | one `pcall(dofile, …)` line prepended |
| btop | `~/.config/btop/themes/kromi.theme`, `btop.conf` | a symlink, and `color_theme = "kromi"` |
| VS Code | `~/.config/Code/User/settings.json` | three keys merged in place: `workbench.colorCustomizations`, `editor.tokenColorCustomizations`, `workbench.colorTheme`; the old values are backed up |
| VLC | `~/.config/vlc/vlcrc` | the one `qt-dark-palette=` line rewritten in place; the old line is backed up |
| Firefox | each profile's `chrome/userChrome.css`, `chrome/userContent.css`, `user.js` | two `@import` lines, two symlinks into `chrome/`, two `user_pref` lines |

Lines are prepended so anything you write below them wins; the CSS imports
are the exception, where last wins. Linking twice adds nothing. `kromi unlink`
removes exactly these lines and keys, restores the VS Code, VLC and Firefox
values it backed up, and deletes a file that held nothing but kromi's line.

After linking, only VS Code, VLC and Firefox's `user.js` are written to again
on a switch, because they have no include mechanism. The rest re-read kromi's
rendered files.

The one thing outside your home directory is optional and separate:
`kromi firefox-live install` puts a loader beside Firefox's program files so a
switch recolours open windows, and needs root. Setup asks; it never does it
unasked. See [App integrations](docs/integrations.md#live-switching).

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
