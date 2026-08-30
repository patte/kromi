/* Firefox's own pages: a new tab, settings, add-ons, history, about:config.
   Reached from <profile>/chrome/userContent.css, through a symlink in that
   directory: content documents are loaded by a sandboxed process that may not
   read outside the profile, so an import naming this file where it lies would
   fail without saying so.

   Scoped to about: on purpose. userContent.css can restyle every site you
   visit, and a palette that repaints the web is a different thing from one
   that paints the browser — kromi stops at the pages Firefox itself draws.
   Which side of light and dark the web gets is a pref, not a colour, and
   firefox.sh sets it; see the README.

   Both spellings of the page colours are set: the design-system tokens
   current Firefox uses, and the --in-content-* names it used before them. */

@-moz-document url-prefix(about:) {
  :root {
    color-scheme: {{ mode }} !important;

    --background-color-canvas: {{ background }} !important;
    --background-color-box: {{ lighter_background }} !important;
    --text-color: {{ foreground }} !important;
    --text-color-deemphasized: {{ dim_text }} !important;

    --button-background-color: {{ lighter_background }} !important;
    --button-background-color-hover: {{ selection }} !important;
    --button-background-color-active: {{ selection_background }} !important;
    --button-text-color: {{ foreground }} !important;
    --button-background-color-primary: {{ accent }} !important;

    --border-color: {{ muted }} !important;
    --border-color-interactive: {{ muted }} !important;
    --color-accent-primary: {{ accent }} !important;
    --focus-outline-color: {{ accent }} !important;

    --link-color: {{ accent }} !important;
    --link-color-hover: {{ accent }} !important;
    --link-color-visited: {{ color5 }} !important;

    --in-content-page-background: {{ background }} !important;
    --in-content-page-color: {{ foreground }} !important;
    --in-content-box-background: {{ lighter_background }} !important;
    --in-content-box-background-hover: {{ selection }} !important;
    --in-content-box-border-color: {{ muted }} !important;
    --in-content-border-color: {{ muted }} !important;
    --in-content-text-color: {{ foreground }} !important;
    --in-content-deemphasized-text: {{ dim_text }} !important;
    --in-content-accent-color: {{ accent }} !important;
    --in-content-link-color: {{ accent }} !important;
    --in-content-button-background: {{ lighter_background }} !important;
    --in-content-button-background-hover: {{ selection }} !important;
    --in-content-button-text-color: {{ foreground }} !important;
    --in-content-selected-text: {{ selection_foreground }} !important;
    --in-content-item-selected: {{ selection_background }} !important;
    --in-content-item-hover: {{ selection }} !important;

    /* A new tab is its own page with its own names for the same surfaces. */
    --newtab-background-color: {{ background }} !important;
    --newtab-background-color-secondary: {{ lighter_background }} !important;
    --newtab-background-card: {{ lighter_background }} !important;
    --newtab-text-primary-color: {{ foreground }} !important;
    --newtab-text-secondary-color: {{ dim_text }} !important;
    --newtab-primary-action-background: {{ accent }} !important;
    --newtab-primary-element-text-color: {{ background }} !important;
    --newtab-element-hover-color: {{ selection }} !important;
    --newtab-element-active-color: {{ selection_background }} !important;

    background-color: {{ background }} !important;
    color: {{ foreground }} !important;
  }

  body {
    background-color: {{ background }} !important;
    color: {{ foreground }} !important;
  }

  ::selection {
    background-color: {{ selection_background }} !important;
    color: {{ selection_foreground }} !important;
  }
}
