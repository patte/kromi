/* Imported last, so these win over whatever stylesheet is already in place. */

window#waybar {
  background-color: {{ background }};
  color: {{ foreground }};
  /* Recoloured, not removed: stock's 3px is the bar's height as laid out. */
  border-bottom: 3px solid {{ color0 }};
}

#workspaces button {
  color: {{ foreground }};
  background-color: transparent;
}

/* Stock draws its indicators as a white inset box-shadow, a property the
   colours above never touch, so each one has to be named to be recoloured. */
button:hover, #mode {
  box-shadow: inset 0 -3px {{ accent }};
}

#workspaces button.focused,
#workspaces button.active {
  background-color: {{ selection_background }};
  color: {{ selection_foreground }};
  box-shadow: inset 0 -3px {{ selection_foreground }};
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

/* The same colours return the moment a module changes state: stock writes those
   as id plus class, which outranks the plain ids above however late this file is
   imported. Every painted state has to be named back. */
#battery.charging, #battery.plugged,
#custom-media.custom-spotify, #custom-media.custom-vlc,
#idle_inhibitor.activated, #keyboard-state > label.locked,
#mpd.disconnected, #mpd.paused, #mpd.stopped,
#network.disconnected, #power-profiles-daemon.balanced,
#power-profiles-daemon.performance, #power-profiles-daemon.power-saver,
#privacy-item.audio-in, #privacy-item.audio-out, #privacy-item.screenshare,
#pulseaudio.muted, #pulseaudio:hover, #temperature.critical,
#tray > .needs-attention, #wireplumber.muted {
  background-color: transparent;
  color: {{ foreground }};
}

/* Read after that block, so the two states worth flagging keep a colour. */
#battery.warning, #temperature.critical { color: {{ color3 }}; }
#battery.critical, #network.disconnected { color: {{ color1 }}; }

/* Stock blinks a critical battery to a white background. One class heavier than
   the rest, to match the selector it is taking over from. */
#battery.critical:not(.charging) {
  background-color: transparent;
  color: {{ color1 }};
  animation: none;
}

/* Stock parks a black background on any label that takes focus. */
label:focus { background-color: transparent; }

tooltip {
  background-color: {{ background }};
  color: {{ foreground }};
  border: 1px solid {{ accent }};
}
