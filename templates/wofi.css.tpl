/* wofi ships no stylesheet of its own, so this is the whole look. */

window {
  background-color: {{ background }};
  color: {{ foreground }};
  border: 2px solid {{ accent }};
  border-radius: 8px;
  font-family: monospace;
}

/* The 8px gutter is on the widgets below, not here, and that is load-bearing.
   wofi sizes its window to 50% by 40% of the screen and re-asserts that on every
   keystroke, while GTK grows the window to whatever the outer box needs. Give
   this box a margin or a padding and the two settle on numbers 16px apart, so the
   launcher twitches out of its bottom-right corner as you type. An inset on the
   search field or the rows costs the window nothing — the scrolled area's own
   minimum already sets the natural size, and these stay well inside it. Putting
   the gutter on `window` does not work either: a GtkWindow draws its border round
   the padding box, which leaves the search field outside the frame. */
#outer-box { padding: 0; }

#input {
  background-color: {{ background }};
  color: {{ foreground }};
  border: none;
  padding: 6px 8px;
  margin: 8px 8px 6px 8px;
}

/* GTK draws its own ring round a focused entry, in the stock Adwaita blue and
   from a box-shadow rather than a border, so `border: none` above never reached
   it. Take it in the selection colour instead, which sits close to the text and
   leaves the accent to the frame round the window. It appears on the first
   keystroke and not when the launcher opens, because GTK3 holds the ring back
   until the window has seen the keyboard. */
#input:focus { box-shadow: inset 0 0 0 1px {{ selection_background }}; }

#input image { color: {{ foreground }}; }

#scroll { margin: 0; }

#entry {
  padding: 5px 8px;
  margin: 0 8px;
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
