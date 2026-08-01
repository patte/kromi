/* wofi ships no stylesheet of its own, so this is the whole look. */

window {
  background-color: {{ background }};
  color: {{ foreground }};
  border: 2px solid {{ accent }};
  border-radius: 8px;
  font-family: monospace;
}

#outer-box { margin: 8px; }

#input {
  background-color: {{ background }};
  color: {{ foreground }};
  border: none;
  border-bottom: 1px solid {{ color8 }};
  padding: 6px 8px;
  margin-bottom: 6px;
}

#input image { color: {{ foreground }}; }

#scroll { margin: 0; }

#entry {
  padding: 5px 8px;
  border-radius: 4px;
  background-color: transparent;
}

#entry:selected {
  background-color: {{ selection_background }};
  color: {{ selection_foreground }};
}

#text { color: {{ foreground }}; }
#text:selected { color: {{ selection_foreground }}; }

#entry:selected #text { color: {{ selection_foreground }}; }
