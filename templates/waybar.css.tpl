/* Imported last, so these win over whatever stylesheet is already in place. */

window#waybar {
  background-color: {{ background }};
  color: {{ foreground }};
}

#workspaces button {
  color: {{ foreground }};
  background-color: transparent;
}

#workspaces button.focused,
#workspaces button.active {
  background-color: {{ selection_background }};
  color: {{ selection_foreground }};
}

#workspaces button.urgent {
  background-color: {{ color1 }};
  color: {{ background }};
}

/* Stock stylesheets give each module its own colour; fold them into the palette. */
#backlight, #battery, #bluetooth, #clock, #cpu, #custom-media, #disk,
#idle_inhibitor, #keyboard-state, #language, #memory, #mode, #mpd, #network,
#power-profiles-daemon, #privacy, #pulseaudio, #scratchpad, #temperature,
#tray, #window, #wireplumber {
  background-color: transparent;
  color: {{ foreground }};
}

#battery.warning, #temperature.critical { color: {{ color3 }}; }
#battery.critical, #network.disconnected { color: {{ color1 }}; }

tooltip {
  background-color: {{ background }};
  color: {{ foreground }};
  border: 1px solid {{ accent }};
}
