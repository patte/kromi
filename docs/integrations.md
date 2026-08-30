# App integrations

kromi has two deliberately separate operations:

- `kromi set` renders app files under
  `${XDG_STATE_HOME:-~/.local/state}/kromi/current/` and reloads detected apps.
- `kromi link` makes the one-time config changes that tell apps to use those
  files. `kromi setup` asks before running it.

Running `set` never edits an unlinked app config. Once explicitly linked, VS
Code, VLC, and Firefox are narrow exceptions to the usual include-based model:
each updates only the documented settings it needs because the app provides no
suitable config include.

```sh
kromi link                          # every detected app
kromi link waybar mako ghostty      # only these
kromi unlink waybar mako ghostty
```

## Overview

| App | Generated output | Reload behavior | Special requirement |
|---|---|---|---|
| Hyprland | Lua or Hyprlang colours | `hyprctl reload` | existing Hyprland config |
| Hyprpaper | wallpaper config | Hyprpaper IPC | a wallpaper for the current theme |
| Waybar | palette and CSS overrides | reload signal | imports at the start and end of its stylesheet |
| Wofi | palette and CSS overrides | next launch | imports at the start and end of its stylesheet |
| Mako | INI options | `makoctl reload` | config include |
| Ghostty | terminal palette | reload signal | config include |
| btop | btop theme | reload signal | symlink inside btop's theme directory |
| Neovim | Lua colorscheme | reloads responsive instances | config include |
| VS Code | JSON colour customizations | watches settings | `jq`; linked settings are merged in place |
| VLC | light/dark marker | next start | linked `qt-dark-palette` is changed in place |
| Firefox | chrome and content CSS | next start | linked profile files, or `kromi firefox-live` |

## Manual setup

The examples below assume the default state directory. Replace `/home/<you>`
with your absolute home path where an app does not expand `~`.

| App | Config | Connection |
|---|---|---|
| Waybar | `~/.config/waybar/style.css` | import `/home/<you>/.local/state/kromi/current/palette.css` at the top and `waybar.css` at the bottom |
| Wofi | `~/.config/wofi/style.css` | import `/home/<you>/.local/state/kromi/current/palette.css` at the top and `wofi.css` at the bottom |
| Mako | `~/.config/mako/config` | `include=~/.local/state/kromi/current/mako.ini` |
| Ghostty | `~/.config/ghostty/config` | `config-file = ?"~/.local/state/kromi/current/ghostty.conf"` |
| Hyprland 0.5x | `~/.config/hypr/hyprland.lua` | `pcall(dofile, (os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state")) .. "/kromi/current/hyprland.lua")` |
| Older Hyprland | `~/.config/hypr/hyprland.conf` | `source = ~/.local/state/kromi/current/hyprland.conf` |
| Hyprpaper | `~/.config/hypr/hyprpaper.conf` | `source = ~/.local/state/kromi/current/hyprpaper.conf` |
| btop | `~/.config/btop/btop.conf` | symlink `btop.theme` into `~/.config/btop/themes/kromi.theme`, then set `color_theme = "kromi"` |
| Neovim | `~/.config/nvim/init.lua` | `pcall(dofile, (os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state")) .. "/kromi/current/neovim.lua")` |
| Firefox | each profile's `chrome/` and `user.js` | see [Firefox](#firefox) |

Waybar and Wofi need absolute import paths because their GTK stylesheets do not
expand `~`. CSS is last-wins: the palette import belongs at the top, where its
`@define-color` declarations exist before use, and the app override belongs at
the bottom, where it can override the existing stylesheet. Other integrations
are prepended, allowing settings below kromi's line to remain in charge.

VS Code and VLC have no manual include to add; their limited in-place changes
are what opting in with `kromi link` enables.

## Hyprland

The generated file sets the border colours and `misc:background_color`, so a
theme with no wallpaper shows the palette's background rather than whatever
was there before. Hyprland only paints that colour with its logo disabled, so
the file sets `misc:disable_hyprland_logo` too. Anything below kromi's line in
your own config wins.

## Hyprpaper

Hyprpaper reads its config at startup, so the generated `hyprpaper.conf`
points at `~/.local/state/kromi/current/wallpaper`, a link kromi keeps aimed
at the current picture; a login needs nothing of kromi's beyond Hyprland
starting the daemon:

```text
exec-once = hyprpaper
```

or `hl.exec_cmd("hyprpaper")` in a Lua config. That line is yours to add:
kromi's link is one `source` line in `hyprpaper.conf`, and starting programs
is Hyprland's job, not a theme's. `kromi setup` offers to start the daemon
for the current session when it is not running, and prints this reminder.
While Hyprpaper is running, switches and `kromi wallpaper next` reach it over
IPC.
`kromi wallpaper apply` reapplies the current image to a running daemon,
including in a manually wired setup.

The file also sets `splash = false`, preventing Hyprpaper's own splash
overlay. Options below the `source` line in your config remain in charge.

Sourcing a file that does not exist is the one config error Hyprpaper refuses
to start on, so `kromi link hyprpaper` renders a theme first when none is set.
A theme with no pictures leaves the link absent; Hyprpaper logs that and
carries on.

## VS Code

VS Code cannot include another settings file, and it caches installed themes
by ID. Reselecting a generated extension can therefore return the colors it
parsed on its first load. `workbench.colorCustomizations` is the mechanism it
applies immediately.

After `kromi link vscode`, every switch merges three keys into
`~/.config/Code/User/settings.json`:

- `workbench.colorCustomizations`
- `editor.tokenColorCustomizations`
- `workbench.colorTheme`

Everything else is left alone. Linking records the previous values and
`kromi unlink vscode` restores them.

The generated customization names all relevant surfaces because VS Code
resolves defaults such as the editor gutter against the underlying theme, not
against another custom color. kromi also selects stock Light or Dark Modern to
match the palette. This gives webviews such as Markdown previews, notebook
output, and extension panels the correct light/dark mode, which color values
alone cannot communicate.

Until VS Code is linked, `kromi set` does not open `settings.json`. Linking and
applying this integration requires `jq`; an invalid settings file is left
untouched.

## VLC

VLC exposes no individual Qt interface colors. It has only
`qt-dark-palette`, so kromi can switch it between light and dark rather than
apply the full palette.

VLC also has no config include. `kromi link vlc` records the existing line in
`~/.config/vlc/vlcrc`, and later switches rewrite that one key in place.
`kromi unlink vlc` restores the original line, including whether it was
commented out.

An open VLC does not reread `vlcrc`. The new value is saved immediately but
appears after VLC restarts; kromi warns when it detects a running instance.

## Firefox

Firefox cannot include a separate settings file, and a generated add-on theme
would need to be signed and installed. kromi instead generates:

- `firefox.css` for tabs, toolbars, menus, the address bar, and sidebars
- `firefox-content.css` for Firefox-owned pages such as new tab, settings,
  add-ons, and `about:config`
- `firefox.conf`, a light/dark mode marker used by the integration

The content stylesheet intentionally stops at Firefox-owned pages. It does not
repaint normal websites. kromi only updates Firefox's website-appearance
preference so sites receive the matching `prefers-color-scheme` value.

Both stylesheets use `!important` because Firefox loads them as user styles.
A user `!important` declaration is what gives them precedence over the
browser's own chrome rules.

### Profile linking

`kromi link firefox` connects every profile listed in `profiles.ini`, because
kromi cannot know which profile a launcher will open. For each profile it:

1. creates `chrome/kromi.css` and `chrome/kromi-content.css` symlinks to the
   generated stylesheets;
2. imports them at the top of `userChrome.css` and `userContent.css`;
3. enables legacy user stylesheets in `user.js`;
4. records and updates Firefox's website-appearance preference.

The imports are relative symlinks inside the profile because Firefox's
sandboxed content process may not read an absolute stylesheet elsewhere. They
must appear before every CSS rule or Firefox discards them.

Profiles are searched under both `~/.config/mozilla/firefox` and
`~/.mozilla/firefox`. Set `KROMI_FIREFOX_HOME` to one or more space-separated
roots for alternatives such as LibreWolf or Flatpak Firefox:

```sh
KROMI_FIREFOX_HOME="$HOME/.librewolf" kromi link firefox
```

Firefox parses these stylesheets once per run, so ordinary profile linking
requires a browser restart after a switch. `kromi unlink firefox` removes the
imports and symlinks and restores the saved website-appearance preference.
Because Firefox copies `user.js` into `prefs.js` at startup, the last appearance
value may remain until it is changed in Firefox settings.

### Live switching

`kromi firefox-live` is the optional way to recolour windows that are already
open. It is a larger step than linking: Firefox runs privileged JavaScript
only from its installation directory, so a loader goes in beside the program,
usually as root, and a Firefox update that replaces that directory removes it
again — run the install again afterwards.

```sh
kromi unlink firefox            # the two do not compose; see below
kromi firefox-live install
```

Then restart Firefox once. Future `kromi set` commands update open windows
immediately, and kromi writes nothing into the profile in this mode.
`kromi firefox-live status` says whether the loader is in and current;
`kromi firefox-live uninstall` takes it out. `KROMI_FIREFOX_APP` names
Firefox's installation directory when it is somewhere unusual.

A stylesheet imported through `userChrome.css` loads before one registered by
the loader and wins over it, so a linked profile would pin the palette Firefox
started with. Both sides guard this: the installer warns about linked profiles,
and `kromi link firefox` refuses while the loader is installed.

The loader watches kromi's generated Firefox files and registers their
stylesheets through Firefox's internal stylesheet service. Each Firefox
process listens on a Unix socket below `$XDG_RUNTIME_DIR/kromi`; on every
switch kromi connects to each, and the connection itself is the whole
notification. That needs `socat`, a netcat with `-U`, or `python3`. Without
one of those the loader falls back to checking the file: often for a short
while after a switch, rarely otherwise, and not at all while the machine is
idle. The chrome stylesheet is the change marker, so after editing another
generated file by hand, `touch ~/.local/state/kromi/current/firefox.css` or
set the theme again.

## Neovim

The generated colorscheme has no plugin or network dependency and works with
every kromi palette, including custom ones.

Neovim instances listen on their own sockets from startup. On a theme switch,
kromi asks responsive instances that are still using the `kromi` colorscheme
to source the generated file again and fires `ColorScheme` for statuslines and
other integrations.

An `init.lua` that selects another colorscheme below kromi's line remains in
charge. An instance busy at a prompt or external command is not held up; it
updates on the next switch or when the generated file is sourced manually.
