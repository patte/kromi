/* The window around the page: tab strip, toolbars, address bar, menus,
   sidebar. Reached from <profile>/chrome/userChrome.css, through a symlink in
   that directory.

   Everything here is !important, which is not shouting: userChrome is a
   user-origin stylesheet, and user !important is the one thing that outranks
   the browser's own !important. Without it almost none of this lands.

   Custom properties do most of the work — Firefox paints its chrome from a
   few dozen of them, so setting those reaches widgets no selector below
   names. They are set on :root unconditionally rather than under [lwtheme],
   the attribute Firefox adds when a theme add-on is installed: there is no
   add-on here, so the values behind that attribute would never be read. */

:root {
  /* Scrollbars, form controls, and every system colour left unnamed below
     resolve from this rather than from a colour kromi can set. */
  color-scheme: {{ mode }} !important;

  /* Titlebar and the strip the tabs sit in. */
  --lwt-accent-color: {{ lighter_background }} !important;
  --lwt-accent-color-inactive: {{ lighter_background }} !important;
  --lwt-text-color: {{ foreground }} !important;
  --toolbox-background-color: {{ lighter_background }} !important;
  --toolbox-background-color-inactive: {{ lighter_background }} !important;
  --toolbox-text-color: {{ foreground }} !important;
  --toolbox-text-color-inactive: {{ dim_text }} !important;

  /* Toolbars: navigation, bookmarks, anything customised onto them. */
  --toolbar-background-color: {{ lighter_background }} !important;
  --toolbar-text-color: {{ foreground }} !important;
  --toolbar-color: {{ foreground }} !important;
  --toolbarbutton-icon-fill: {{ foreground }} !important;
  --toolbarbutton-icon-fill-attention: {{ accent }} !important;
  --toolbarbutton-background-color-hover: {{ selection }} !important;
  --toolbarbutton-background-color-active: {{ selection_background }} !important;
  --toolbarseparator-color: {{ muted }} !important;

  /* Tabs. The selected one takes the page's background rather than the
     toolbar's, so it reads as the sheet of paper the content is on. */
  --tab-background-color-selected: {{ background }} !important;
  --tab-selected-textcolor: {{ foreground }} !important;
  --tab-background-color-hover: {{ selection }} !important;
  --lwt-background-tab-separator-color: {{ muted }} !important;
  --lwt-tab-line-color: {{ accent }} !important;
  --tab-loading-fill: {{ accent }} !important;
  --tab-attention-dot-color: {{ accent }} !important;
  --tabs-navbar-separator-color: {{ muted }} !important;
  --chrome-content-separator-color: {{ muted }} !important;

  /* Address bar and search bar. */
  --toolbar-field-background-color: {{ background }} !important;
  --toolbar-field-text-color: {{ foreground }} !important;
  --toolbar-field-border-color: {{ muted }} !important;
  --toolbar-field-background-color-focus: {{ background }} !important;
  --toolbar-field-text-color-focus: {{ foreground }} !important;
  --toolbar-field-border-color-focus: {{ accent }} !important;
  --lwt-toolbar-field-highlight: {{ selection_background }} !important;
  --lwt-toolbar-field-highlight-text: {{ selection_foreground }} !important;
  --urlbar-box-background-color: {{ selection }} !important;
  --urlbar-box-text-color: {{ foreground }} !important;
  --urlbar-box-background-color-hover: {{ selection_background }} !important;
  --urlbar-box-text-color-hover: {{ selection_foreground }} !important;

  /* The results that drop out of it. */
  --urlbarview-background-color-hover: {{ selection }} !important;
  --urlbarview-background-color-selected: {{ selection_background }} !important;
  --urlbarview-text-color-selected: {{ selection_foreground }} !important;
  --urlbarview-text-color-action: {{ dim_text }} !important;
  --urlbarview-separator-color: {{ muted }} !important;

  /* Doorhangers and the app menu. --arrowpanel-* are the older spelling and
     cost nothing to keep for a Firefox that still reads them. */
  --panel-background-color: {{ lighter_background }} !important;
  --panel-text-color: {{ foreground }} !important;
  --panel-border-color: {{ muted }} !important;
  --arrowpanel-background: {{ lighter_background }} !important;
  --arrowpanel-color: {{ foreground }} !important;
  --arrowpanel-border-color: {{ muted }} !important;
  --arrowpanel-dimmed: {{ selection }} !important;

  --sidebar-background-color: {{ lighter_background }} !important;
  --sidebar-text-color: {{ foreground }} !important;
  --sidebar-border-color: {{ muted }} !important;

  --link-color: {{ accent }} !important;
  --link-color-hover: {{ accent }} !important;
  --link-color-active: {{ accent }} !important;
  --focus-outline-color: {{ accent }} !important;
  --color-accent-primary: {{ accent }} !important;
}

/* Menus declare these colours on themselves, and a declaration on the element
   beats one inherited from :root whatever its origin — so the block above
   never reaches them and they have to be named again here. */
:is(menupopup, panel) {
  color-scheme: {{ mode }} !important;
  --panel-background-color: {{ lighter_background }} !important;
  --panel-text-color: {{ foreground }} !important;
  --panel-border-color: {{ muted }} !important;
}

/* A highlighted menu row is painted from -moz-menuhover, a system colour that
   comes from the desktop theme rather than from anything above. */
:is(menu, menuitem):where([_moz-menuactive]:not([disabled])) {
  background-color: {{ selection_background }} !important;
  color: {{ selection_foreground }} !important;
}

/* Where the space behind the tabs or beside the sidebar shows through. */
#navigator-toolbox,
#sidebar-box,
#sidebar-header {
  background-color: {{ lighter_background }} !important;
}

/* The gap left while a page is still painting. Firefox fills it from its own
   default, which is white under every palette. */
#tabbrowser-tabbox,
#tabbrowser-tabpanels {
  background-color: {{ background }} !important;
}

#findbar,
findbar {
  background-color: {{ lighter_background }} !important;
  color: {{ foreground }} !important;
}
