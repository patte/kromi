-- Hyprland 0.5x lua config.

hl.config({
  general = {
    col = {
      active_border = "{{ accent }}",
      inactive_border = "{{ color8 }}",
    },
  },

  group = {
    col = {
      border_active = "{{ accent }}",
      border_inactive = "{{ color8 }}",
    },
  },

  -- What shows where there is no wallpaper. Hyprland paints its own logo
  -- there unless told not to, and only then does the colour apply.
  misc = {
    disable_hyprland_logo = true,
    background_color = "{{ background }}",
  },
})
