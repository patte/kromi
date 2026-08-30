# Rendered by kromi on every `kromi set`. Your own hyprpaper.conf sources
# this one, and anything you write below that source line wins.

# hyprpaper draws Hyprland's splash string over the wallpaper itself, asking
# the compositor for it over IPC. misc:disable_splash_rendering silences
# Hyprland's own copy and has nothing to say about this one.
splash = false

# An empty monitor is the fallback every output takes, so this covers a laptop
# panel and a desk full of screens alike. Naming a monitor in your own config
# overrides it for that one.
#
# The path is the symlink kromi keeps pointing at the current wallpaper, and
# hyprpaper resolves it at startup — extensionless, which it does not mind. A
# theme with no pictures leaves the link absent; hyprpaper logs that it could
# not resolve the path, sets no wallpaper, and carries on running.
wallpaper {
    monitor =
    path = {{ wallpaper }}
}
