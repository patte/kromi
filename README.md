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
| Hyprland | compositor colours | immediately |
| Hyprpaper | wallpaper | immediately |
| Waybar | bar | immediately |
| Wofi | launcher | next launch |
| Mako | notifications | immediately |
| Ghostty | terminal | immediately |
| btop | terminal UI | immediately |
| Neovim | editor | immediately while using kromi |
| VS Code | editor and workbench | immediately |
| VLC | light or dark Qt palette | after restart |
| Firefox | browser chrome and internal pages | after restart, or immediately with the optional live helper |

VS Code, VLC, and Firefox cannot consume a generated config as directly as the
other apps. kromi handles them without taking over the rest of their settings;
see [App integrations](docs/integrations.md) for the exact trade-offs.

## Install

```sh
git clone https://github.com/patte/kromi ~/.local/share/kromi
ln -s ~/.local/share/kromi/bin/kromi ~/.local/bin/kromi
```

Optional helpers:

```sh
ln -s ~/.local/share/kromi/bin/kromi-backgrounds ~/.local/bin/kromi-backgrounds
ln -s ~/.local/share/kromi/bin/kromi-firefox-live ~/.local/bin/kromi-firefox-live
```

They do nothing unless you run them. The first fetches wallpapers; the second
enables live Firefox updates and requires a system-level installation step.

## Quick start

Choose an initial theme, inspect the detected apps, then connect their configs
to kromi's generated files:

```sh
kromi set tokyo-night
kromi apps
kromi link
```

`link` is a one-time, opt-in setup. After that, switching is just:

```sh
kromi set nord
```

To connect only particular apps, name them:

```sh
kromi link waybar mako ghostty
```

Use `kromi unlink [app...]` to undo the corresponding changes. If you manage
your configs yourself, skip `link` and use the lines in
[App integrations](docs/integrations.md#manual-setup).

## Usage

### Switch themes

The easiest way to choose a theme is to browse them interactively:

```sh
kromi interactive      # browse manually
```

| Key | Action |
|---|---|
| `n` / `p` | Show the next or previous theme |
| `a` | Toggle automatic browsing |
| `1`–`9` | Set the automatic interval in seconds |
| `r` | Return to the starting theme and keep browsing |
| `x` / Ctrl-C | Keep the current theme and exit |


Alternatively you can use specific commands:

```sh
kromi set <theme>      # render and apply a theme
kromi list             # list themes and mark the current one
kromi current          # print the current theme
```

### Manage app connections

```sh
kromi apps             # list integrations and mark detected apps
kromi link [app...]    # connect detected or named apps
kromi unlink [app...]  # remove those connections
```

### Wallpapers

```sh
kromi-backgrounds        # download wallpapers for every known theme
kromi background next    # cycle through the current theme's wallpapers
```

This fetches wallpaper sets for every known theme from
[Omarchy](https://github.com/basecamp/omarchy) v3.8.4. Once Hyprpaper is linked,
the usual `kromi set <theme>` switches its wallpaper along with the rest of the
theme.

Many themes have several wallpapers. The downloader never overwrites existing
files. See [Wallpapers](docs/wallpapers.md) for selective downloads, available
sets, licensing, custom images, and Hyprpaper setup.

## How it works

`kromi set` renders one file per app under
`~/.local/state/kromi/current/`, swaps the complete theme into place, and
reloads detected apps. It does not edit their configs.

`kromi link` makes the small, app-specific config change that points an app at
those generated files. This separation keeps theme switching safe for people
who manage dotfiles themselves. VS Code, VLC, and Firefox are the documented
exceptions because those apps do not provide ordinary config includes.

## Customize and extend

- [Themes and templates](docs/themes.md) — add a theme, override a rendered
  file, or customize a template.
- [Wallpapers](docs/wallpapers.md) — provide your own images or fetch a set.
- [App integrations](docs/integrations.md) — manual setup and app-specific
  behavior.
- [Live Firefox switching](docs/firefox-live.md) — recolour an open Firefox.
- [Adding an app](docs/adding-an-app.md) — write a new app definition.

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
