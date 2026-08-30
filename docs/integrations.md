# App integrations

kromi treats generating a theme and connecting apps as separate operations:

- `kromi set` renders app files under `$XDG_STATE_HOME/kromi/current/`, or
  `~/.local/state/kromi/current/` when `XDG_STATE_HOME` is unset. It then
  reloads detected apps.
- `kromi link` makes the one-time config changes that tell apps to use those
  files. `kromi setup` asks before running it.
- `kromi unlink` removes those connections and restores settings that kromi
  backed up.

Running `set` never edits the config of an unlinked app. Once linked, VS Code,
VLC, and Firefox are narrow exceptions to the usual include-based model. Each
updates only the documented settings it needs because the app has no suitable
config include.

```sh
kromi link                          # every detected app
kromi link waybar mako ghostty      # only these
kromi unlink waybar mako ghostty
```

## Overview

| App | Generated output | Reload behavior | Special requirement |
|---|---|---|---|
| Hyprland | Lua or Hyprlang colors | `hyprctl reload` | existing Hyprland config |
| Hyprpaper | wallpaper config | Hyprpaper IPC | a wallpaper for the current theme |
| Waybar | palette and CSS overrides | reload signal | imports at the start and end of its stylesheet |
| Wofi | palette and CSS overrides | next launch | imports at the start and end of its stylesheet |
| Mako | INI options | `makoctl reload` | config include |
| Ghostty | terminal palette | reload signal | config include |
| btop | btop theme | reload signal | symlink inside btop's theme directory |
| Neovim | Lua colorscheme | reloads responsive instances | config include |
| VS Code | JSON color customizations | watches settings | `jq`; linked settings are merged in place |
| VLC | light/dark marker | next start | linked `qt-dark-palette` is changed in place |
| Firefox | chrome and content CSS | next start | linked profile files, or `kromi firefox-live` |

## Manual setup

The examples below use the default state directory. Replace `/home/<you>` with
your absolute home path where an app does not expand `~`.

| App | Config | Connection |
|---|---|---|
| Waybar | `~/.config/waybar/style.css` | import `/home/<you>/.local/state/kromi/current/palette.css` at the top and `waybar.css` at the bottom |
| Wofi | `~/.config/wofi/style.css` | import `/home/<you>/.local/state/kromi/current/palette.css` at the top and `wofi.css` at the bottom |
| Mako | `~/.config/mako/config` | `include=~/.local/state/kromi/current/mako.ini` |
| Ghostty | `~/.config/ghostty/config` | `config-file = ?"~/.local/state/kromi/current/ghostty.conf"` |
| Hyprland 0.5x (Lua) | `~/.config/hypr/hyprland.lua` | `pcall(dofile, (os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state")) .. "/kromi/current/hyprland.lua")` |
| Older Hyprland | `~/.config/hypr/hyprland.conf` | `source = ~/.local/state/kromi/current/hyprland.conf` |
| Hyprpaper | `~/.config/hypr/hyprpaper.conf` | `source = ~/.local/state/kromi/current/hyprpaper.conf` |
| btop | `~/.config/btop/btop.conf` | symlink `btop.theme` into `~/.config/btop/themes/kromi.theme`, then set `color_theme = "kromi"` |
| Neovim | `~/.config/nvim/init.lua` | `pcall(dofile, (os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state")) .. "/kromi/current/neovim.lua")` |
| Firefox | each profile's `chrome/` and `user.js` | see [Firefox](#firefox) |

Waybar and Wofi need absolute import paths because their GTK stylesheets do not
expand `~`. CSS uses the last matching rule, so the two imports have different
positions:

- The palette belongs at the top. Its `@define-color` declarations must exist
  before the rest of the stylesheet uses them.
- The app override belongs at the bottom, where it can override existing
  rules.

Other integrations are prepended, allowing settings below kromi's line to
remain in charge.

VS Code and VLC have no manual include to add; their limited in-place changes
are what opting in with `kromi link` enables.

## Hyprland

The generated file sets the border colors and `misc:background_color`. A theme
without a wallpaper therefore shows the palette's background instead of the
previous desktop color.

Hyprland only paints that color when its logo is disabled, so the generated
file also sets `misc:disable_hyprland_logo`. Anything below kromi's line in
your config still wins.

## Hyprpaper

The generated `hyprpaper.conf` points at
`~/.local/state/kromi/current/wallpaper`. kromi keeps that symlink aimed at the
selected image for the current theme.

Hyprpaper reads its config at startup. To show a wallpaper after login, have
Hyprland start the daemon:

```text
exec-once = hyprpaper
```

Use `hl.exec_cmd("hyprpaper")` instead when your Hyprland config is Lua. This
startup command remains yours to add: kromi only adds a `source` line to
`hyprpaper.conf`, while starting programs remains Hyprland's responsibility.

When the daemon is not running, `kromi setup` offers to start it for the
current session and prints the appropriate login reminder. While Hyprpaper is
running, theme switches and `kromi wallpaper next` reach it over IPC.
`kromi wallpaper apply` reapplies the current image, including with a manually
connected setup.

The file also sets `splash = false`, preventing Hyprpaper's own splash
overlay. Options below the `source` line in your config remain in charge.

Hyprpaper refuses to start when a sourced config file does not exist. To avoid
that error, `kromi link hyprpaper` renders a theme first when none is set. A
theme without pictures leaves the wallpaper symlink absent; Hyprpaper logs the
missing image and continues running.

## VS Code

VS Code cannot include another settings file. It also caches installed themes
by ID, so reselecting a generated extension can return the colors parsed on
its first load. `workbench.colorCustomizations` is the mechanism VS Code
applies immediately.

After `kromi link vscode`, every switch merges three keys into
`~/.config/Code/User/settings.json`:

- `workbench.colorCustomizations`
- `editor.tokenColorCustomizations`
- `workbench.colorTheme`

Everything else is left unchanged. Linking records the previous values;
`kromi unlink vscode` restores them.

The generated customization names every relevant surface. VS Code resolves
defaults such as the editor gutter against the underlying theme, not against
another customized color, so leaving them unnamed would allow parts of the
base theme to show through.

kromi also selects the stock Light Modern or Dark Modern theme to match the
palette. This gives webviews—such as Markdown previews, notebook output, and
extension panels—the correct light or dark mode, which color values alone
cannot communicate.

Until VS Code is linked, `kromi set` does not open `settings.json`. Linking and
applying this integration requires `jq`. An invalid settings file is left
untouched.

## VLC

VLC exposes no individual Qt interface colors. Its only relevant setting is
`qt-dark-palette`, so kromi can switch VLC between light and dark but cannot
apply the full palette.

VLC also has no config include. `kromi link vlc` records the existing line in
`~/.config/vlc/vlcrc`, and later switches rewrite that one key in place.
`kromi unlink vlc` restores the original line, including whether it was
commented out.

An open VLC does not reread `vlcrc`. The new value is saved immediately but
appears after VLC restarts; kromi warns when it detects a running instance.

## Firefox

Firefox cannot include a separate settings file, and a generated add-on theme
would need to be signed and installed. Instead, kromi generates three files:

- `firefox.css` for tabs, toolbars, menus, the address bar, and sidebars
- `firefox-content.css` for Firefox-owned pages such as new tab, settings,
  add-ons, and `about:config`
- `firefox.conf`, a light/dark mode marker used by the integration

The content stylesheet intentionally stops at Firefox-owned pages; it does not
repaint normal websites. For websites, kromi updates only Firefox's appearance
preference so they receive the matching `prefers-color-scheme` value.

Both stylesheets use `!important` because Firefox loads them as user styles.
That declaration gives them precedence over the browser's own chrome rules.

### Profile linking

`kromi link firefox` connects every profile listed in `profiles.ini`; kromi
cannot know which one a launcher will open. For each profile, it:

1. creates `chrome/kromi.css` and `chrome/kromi-content.css` symlinks to the
   generated stylesheets;
2. imports them at the top of `userChrome.css` and `userContent.css`;
3. enables legacy user stylesheets in `user.js`;
4. records and updates Firefox's website-appearance preference.

The imports point to relative symlinks inside the profile because Firefox's
sandboxed content process may not be able to read an absolute stylesheet
elsewhere. The imports must also appear before every CSS rule, or Firefox
discards them.

Profiles are searched under both `~/.config/mozilla/firefox` and
`~/.mozilla/firefox`. Set `KROMI_FIREFOX_HOME` to one or more space-separated
roots for alternatives such as LibreWolf or Flatpak Firefox:

```sh
KROMI_FIREFOX_HOME="$HOME/.librewolf" kromi link firefox
```

Firefox parses these stylesheets once per run. With profile linking, a theme
switch therefore appears after Firefox restarts.

`kromi unlink firefox` removes the imports and symlinks and restores the saved
website-appearance preference. Firefox copies `user.js` into `prefs.js` at
startup, so the last appearance value may remain until you change it in
Firefox's settings. If the live loader is installed, it also offers to remove
that (root is needed); decline to keep live switching.

### Live switching

`kromi firefox-live` is the optional way to recolor windows that are already
open. It is a larger step than profile linking. Firefox runs privileged
JavaScript only from its installation directory, so the loader must be placed
beside the program, usually as root. A Firefox update that replaces that
directory also removes the loader; reinstall it afterward.

```sh
kromi unlink firefox            # the two do not compose; see below
kromi firefox-live install
```

Restart Firefox once after installation. Future `kromi set` commands then
update open windows immediately, and kromi writes nothing into the profile in
this mode.

- `kromi firefox-live status` reports whether the loader is installed and
  current.
- `kromi firefox-live uninstall` removes it.
- `KROMI_FIREFOX_APP` specifies Firefox's installation directory when
  auto-detection does not find it.

A stylesheet imported through `userChrome.css` loads before one registered by
the live loader and takes precedence. A profile connection would therefore pin
the palette that Firefox started with. Both integrations guard against this:
the live installer warns about connected profiles, and `kromi link firefox`
refuses while the loader is installed.

This conflict affects only Firefox. A bare `kromi link` can still connect the
other detected apps while the live loader is installed.

The loader registers kromi's generated stylesheets through Firefox's internal
stylesheet service and updates the website-appearance preference. Each Firefox
process listens on a Unix socket below `$XDG_RUNTIME_DIR/kromi`. On every
switch, kromi connects to each socket. The connection is the complete
notification; no payload is sent or read.

Sending the notification requires `socat`, a netcat with `-U`, or `python3`.
Without one of them, the loader falls back to checking the generated file:
frequently for a short time after a switch, rarely otherwise, and not while
the machine is idle.

The chrome stylesheet is the change marker. After editing a different
generated Firefox file by hand, either run the following command or set the
theme again:

```sh
touch ~/.local/state/kromi/current/firefox.css
```

After uninstalling live switching, restart Firefox to clear the current
palette. You can then return to profile linking with `kromi link firefox`.

## Neovim

The generated colorscheme has no plugin or network dependency and works with
every kromi palette, including custom ones.

Each Neovim instance listens on its own socket from startup. On a theme switch,
kromi asks responsive instances that are still using the `kromi` colorscheme
to source the generated file again. It then fires `ColorScheme` so statuslines
and other integrations can update.

An `init.lua` that selects another colorscheme below kromi's line remains in
charge. kromi also does not hold up an instance that is busy at a prompt or in
an external command. That instance updates on the next switch or when the
generated file is sourced manually.
