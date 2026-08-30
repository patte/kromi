# Wallpapers

kromi ships no wallpapers. A palette is a reusable list of color values, but a
wallpaper is somebody's photograph or artwork and may not be freely
redistributable.

You can place your own files under:

```text
~/.config/kromi/backgrounds/<theme>/
```

A theme may also include a `backgrounds/` directory of its own.

## Fetch wallpaper sets

The optional `kromi-backgrounds` helper fetches images from their upstream
source rather than including them in this repository:

```sh
kromi-backgrounds --list          # list available sets and image counts
kromi-backgrounds                 # fetch sets for every known theme
kromi-backgrounds nord kanagawa   # fetch selected themes
```

Files land in `~/.config/kromi/backgrounds/<theme>/`. Existing files are never
overwritten, so custom pictures survive later runs.

The helper defaults to Omarchy v3.8.4. Point it at another compatible
repository with:

```sh
KROMI_BACKGROUNDS_REPO=https://example.com/themes.git \
KROMI_BACKGROUNDS_REF=main \
kromi-backgrounds
```

The repository must store files under `themes/<name>/backgrounds/`.

Downloading artwork does not grant a license to redistribute it. The default
upstream collection contains a mixture of freely licensed photography, film
stills, and other artwork. Check the rights for individual images before
publishing or redistributing them.

## Select and cycle wallpapers

When a theme is set, kromi points
`~/.local/state/kromi/current/background` at its first available image. Cycle
through the rest with:

```sh
kromi background next
```

A theme without images still applies normally. It simply has no wallpaper.

## Hyprpaper

Hyprpaper is the shipped wallpaper integration. Connect it with:

```sh
kromi link hyprpaper
```

This adds the following line to `~/.config/hypr/hyprpaper.conf`:

```text
source = ~/.local/state/kromi/current/hyprpaper.conf
```

The generated config points at the stable wallpaper link, so Hyprpaper restores
the selected image when it starts. Hyprland only needs to launch the daemon:

```text
exec-once = hyprpaper
```

Hyprpaper reads its config at startup. While it is running, kromi uses IPC to
apply switches and wallpaper cycles immediately. `kromi background apply`
reapplies the current image to a running daemon, including in a manually wired
setup.

The generated file also sets `splash = false`, preventing Hyprpaper's own
Hyprland splash overlay. Options below the `source` line in your config remain
in charge.

Linking refuses when there is no generated Hyprpaper config yet because a
missing `source` target prevents Hyprpaper from starting. Run `kromi set
<theme>` first.
