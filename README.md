# kromi

Beautiful and simple theming for Hyprland and your favorite apps.

The included themes and template-driven approach are derived from
[Omarchy](https://github.com/basecamp/omarchy), adapted here into a standalone
tool.

```sh
kromi set tokyo-night
```

https://github.com/user-attachments/assets/ed646693-63d0-411f-a5fc-e57ae086aa4b

kromi is Bash and sed. There is nothing to compile, no daemon, and no assumed
distribution. It does not install your apps or take over their configs:

- Theme switches write generated files inside kromi's own state directory.
- Connecting an app is a one-time config change that you approve — usually an
  include, import, or pointer to kromi's generated files.
- `kromi unlink` removes that connection and restores any settings kromi replaced.

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/patte/kromi/main/install.sh | bash
```

The piped installer clones kromi into `~/.local/share/kromi` and links the
command into `~/.local/bin`. Run it again to update.

To install manually run this:

```sh
git clone https://github.com/patte/kromi ~/.local/share/kromi
mkdir -p ~/.local/bin && ln -s ~/.local/share/kromi/bin/kromi ~/.local/bin/kromi
```

## Uninstall

```sh
kromi uninstall
```

Uninstall lists everything it will remove and asks for confirmation. It:

- unlinks every connected app;
- removes Firefox live switching if it is installed;
- deletes kromi's generated state and installed command;
- deletes the clone made by the installer, but leaves a checkout linked from
  elsewhere with `./install.sh` in place;
- keeps your themes, templates, and wallpapers under `~/.config/kromi` by
  default.

Pass `-y` to skip the confirmation. Without it, kromi separately offers to
delete your files under `~/.config/kromi`.

## Quick start

```sh
kromi setup
```

Setup walks you through the first run. It:

1. finds supported apps and asks before connecting their configs;
2. offers Firefox live switching when Firefox is installed;
3. offers to download wallpapers when a wallpaper app is available;
4. applies Tokyo Night on a fresh install, then offers to browse other themes.

The questions come before anything changes on screen.
Every config change is listed and reversible with `kromi unlink`; see
[Config changes and undoing them](#config-changes-and-undoing-them).

After setup, switch themes directly or browse them interactively:

```sh
kromi interactive        # browse themes: n/p step, a auto, r restore, x/q keep
kromi set nord           # set nord theme
```

If you manage your own dotfiles, skip `setup` and add the connections from
[Manual setup](docs/integrations.md#manual-setup) yourself.

## Everyday use

```sh
kromi interactive        # browse themes: n/p step, a auto, r restore, x/q keep

kromi set <theme>        # apply a theme
kromi list               # list themes and mark the current one
kromi current            # print the current theme

kromi wallpaper next     # use the current theme's next wallpaper
kromi wallpaper fetch    # download wallpaper sets (needs git)

kromi apps               # show detected apps and whether they are connected
kromi link [app...]      # connect detected or named apps
kromi unlink [app...]    # remove those connections
kromi uninstall          # unlink everything and remove kromi
```

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
other apps. kromi updates only the settings it needs; see
[App integrations](docs/integrations.md) for the exact behavior and trade-offs.

## Wallpapers

kromi ships without wallpapers: a palette is a list of numbers, while a
wallpaper is somebody's picture. Put your own images under
`~/.config/kromi/wallpapers/<theme>/`, or fetch the sets Omarchy uses (setup offers this):

```sh
kromi wallpaper fetch [theme...]
```

Existing files are never overwritten. A theme without pictures still applies;
Hyprland paints the bare desktop in the palette's background instead.

Fetched images are for your own use. The collection mixes freely licensed
photography with artwork that is not. Point `KROMI_WALLPAPERS_REPO` and
`KROMI_WALLPAPERS_REF` at another repository laid out as
`themes/<name>/backgrounds/` to fetch from somewhere else.

## Config changes and undoing them

kromi deliberately separates applying a theme from connecting app configs:

- `kromi set` renders files under `~/.local/state/kromi/current/` and reloads
  detected apps.
- `kromi link` makes the one-time config changes that tell apps to use those
  generated files. `kromi setup` asks before running it.
- `kromi unlink` removes kromi's lines and restores the settings it backed up.

This separation keeps ordinary theme switching safe for people who manage
their own dotfiles. Most integrations add an include or import. VS Code, VLC,
and Firefox are exceptions because they do not provide a suitable
config include.

### Exact changes

This is everything `kromi link` can change outside kromi's own directories:

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

Most connections are prepended so settings below them remain in charge. CSS
imports are the exception because the last matching rule wins. Linking twice
adds nothing.

After linking, only VS Code, VLC, and Firefox's `user.js` are written again
during a switch. They have no include mechanism; the other apps simply read
kromi's rendered files.

`kromi unlink` removes exactly the lines and keys above, restores the VS Code,
VLC, and Firefox values it backed up, and deletes a file if it held nothing but
kromi's connection.

### Firefox live switching

The optional Firefox live loader is the only feature that writes outside your
home directory. `kromi firefox-live install` puts a loader beside Firefox's
program files so open windows can follow a theme switch. It usually needs root,
and a Firefox update may remove it.

Setup offers this option when Firefox is detected; it never installs it without
asking. See [Firefox live switching](docs/integrations.md#live-switching) for
details.

## Customize and extend

User files under `~/.config/kromi/` shadow shipped files of the same name, so
customizations do not require changing the checkout.

- [App integrations](docs/integrations.md) — manual setup, app-specific
  behavior, and Firefox live switching.
- [Extending kromi](docs/extending.md) — add a theme, customize a template, or
  write a new app definition.

## Development

From a checkout, run the installer directly:

```sh
./install.sh
```

This links the current working tree as-is, including uncommitted changes.

### Tests

```sh
./test/run.sh
```

The suite uses a throwaway XDG root and does not signal your running desktop.

## Credit

The palettes and template-and-sed approach come from
[Omarchy](https://github.com/basecamp/omarchy), MIT licensed. See
[NOTICE](NOTICE) for details.
