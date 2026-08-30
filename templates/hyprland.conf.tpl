# Pre-0.5x hyprlang config.

general {
    col.active_border = rgb({{ accent_strip }})
    col.inactive_border = rgb({{ color8_strip }})
}

group {
    col.border_active = rgb({{ accent_strip }})
    col.border_inactive = rgb({{ color8_strip }})
}

# What shows where there is no wallpaper. Hyprland paints its own logo there
# unless told not to, and only then does the colour apply.
misc {
    disable_hyprland_logo = true
    background_color = rgb({{ background_strip }})
}
