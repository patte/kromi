{
  "workbench.colorCustomizations": {
    "editor.background": "{{ background }}",
    "editor.foreground": "{{ foreground }}",
    "editorLineNumber.foreground": "{{ color8 }}",
    "editorLineNumber.activeForeground": "{{ accent }}",
    "editorCursor.foreground": "{{ cursor }}",
    "editor.selectionBackground": "{{ selection_background }}",
    "editor.lineHighlightBackground": "{{ color0 }}",
    "editorWhitespace.foreground": "{{ color8 }}",
    "editorIndentGuide.background1": "{{ color0 }}",
    "editorIndentGuide.activeBackground1": "{{ color8 }}",

    "editorGutter.background": "{{ background }}",
    "editorPane.background": "{{ background }}",
    "minimap.background": "{{ background }}",
    "breadcrumb.background": "{{ background }}",
    "breadcrumb.foreground": "{{ color8 }}",
    "breadcrumb.focusForeground": "{{ foreground }}",
    "breadcrumb.activeSelectionForeground": "{{ foreground }}",
    "editorStickyScroll.background": "{{ background }}",
    "editorStickyScrollGutter.background": "{{ background }}",

    "editorWidget.background": "{{ background }}",
    "editorWidget.foreground": "{{ foreground }}",
    "editorWidget.border": "{{ color8 }}",
    "editorHoverWidget.background": "{{ background }}",
    "editorHoverWidget.foreground": "{{ foreground }}",
    "editorHoverWidget.border": "{{ color8 }}",
    "editorSuggestWidget.background": "{{ background }}",
    "editorSuggestWidget.foreground": "{{ foreground }}",
    "editorSuggestWidget.border": "{{ color8 }}",
    "editorSuggestWidget.selectedBackground": "{{ selection_background }}",
    "editorSuggestWidget.selectedForeground": "{{ selection_foreground }}",
    "peekViewEditor.background": "{{ background }}",
    "notifications.background": "{{ background }}",
    "notifications.foreground": "{{ foreground }}",

    "activityBar.background": "{{ background }}",
    "activityBar.foreground": "{{ foreground }}",
    "activityBar.inactiveForeground": "{{ color8 }}",
    "activityBarBadge.background": "{{ accent }}",
    "activityBarBadge.foreground": "{{ background }}",

    "sideBar.background": "{{ background }}",
    "sideBar.foreground": "{{ foreground }}",
    "sideBarTitle.foreground": "{{ foreground }}",
    "sideBarSectionHeader.background": "{{ color0 }}",
    "sideBarSectionHeader.foreground": "{{ foreground }}",

    "editorGroup.emptyBackground": "{{ background }}",
    "editorGroupHeader.tabsBackground": "{{ background }}",
    "editorGroupHeader.noTabsBackground": "{{ background }}",
    "tab.activeBackground": "{{ color0 }}",
    "tab.activeForeground": "{{ foreground }}",
    "tab.inactiveBackground": "{{ background }}",
    "tab.inactiveForeground": "{{ color8 }}",
    "tab.activeBorderTop": "{{ accent }}",
    "tab.border": "{{ background }}",

    "statusBar.background": "{{ background }}",
    "statusBar.foreground": "{{ foreground }}",
    "statusBar.noFolderBackground": "{{ background }}",
    "statusBar.debuggingBackground": "{{ accent }}",
    "statusBar.debuggingForeground": "{{ background }}",

    "titleBar.activeBackground": "{{ background }}",
    "titleBar.activeForeground": "{{ foreground }}",
    "titleBar.inactiveBackground": "{{ background }}",
    "titleBar.inactiveForeground": "{{ color8 }}",

    "panel.background": "{{ background }}",
    "panel.border": "{{ color8 }}",
    "panelTitle.activeForeground": "{{ foreground }}",
    "panelTitle.inactiveForeground": "{{ color8 }}",

    "dropdown.background": "{{ color0 }}",
    "dropdown.foreground": "{{ foreground }}",
    "input.background": "{{ color0 }}",
    "input.foreground": "{{ foreground }}",
    "input.placeholderForeground": "{{ color8 }}",
    "focusBorder": "{{ accent }}",

    "list.activeSelectionBackground": "{{ selection_background }}",
    "list.activeSelectionForeground": "{{ selection_foreground }}",
    "list.inactiveSelectionBackground": "{{ color0 }}",
    "list.hoverBackground": "{{ color0 }}",
    "list.highlightForeground": "{{ accent }}",

    "quickInput.background": "{{ background }}",
    "quickInputList.focusBackground": "{{ selection_background }}",
    "quickInputList.focusForeground": "{{ selection_foreground }}",

    "menu.background": "{{ background }}",
    "menu.foreground": "{{ foreground }}",
    "menu.selectionBackground": "{{ selection_background }}",
    "menu.selectionForeground": "{{ selection_foreground }}",

    "button.background": "{{ accent }}",
    "button.foreground": "{{ background }}",
    "badge.background": "{{ accent }}",
    "badge.foreground": "{{ background }}",
    "progressBar.background": "{{ accent }}",

    "editorError.foreground": "{{ color1 }}",
    "editorWarning.foreground": "{{ color3 }}",
    "editorInfo.foreground": "{{ color4 }}",

    "gitDecoration.modifiedResourceForeground": "{{ color3 }}",
    "gitDecoration.deletedResourceForeground": "{{ color1 }}",
    "gitDecoration.untrackedResourceForeground": "{{ color2 }}",
    "gitDecoration.ignoredResourceForeground": "{{ color8 }}",

    "terminal.background": "{{ background }}",
    "terminal.foreground": "{{ foreground }}",
    "terminal.ansiBlack": "{{ color0 }}",
    "terminal.ansiRed": "{{ color1 }}",
    "terminal.ansiGreen": "{{ color2 }}",
    "terminal.ansiYellow": "{{ color3 }}",
    "terminal.ansiBlue": "{{ color4 }}",
    "terminal.ansiMagenta": "{{ color5 }}",
    "terminal.ansiCyan": "{{ color6 }}",
    "terminal.ansiWhite": "{{ color7 }}",
    "terminal.ansiBrightBlack": "{{ color8 }}",
    "terminal.ansiBrightRed": "{{ color9 }}",
    "terminal.ansiBrightGreen": "{{ color10 }}",
    "terminal.ansiBrightYellow": "{{ color11 }}",
    "terminal.ansiBrightBlue": "{{ color12 }}",
    "terminal.ansiBrightMagenta": "{{ color13 }}",
    "terminal.ansiBrightCyan": "{{ color14 }}",
    "terminal.ansiBrightWhite": "{{ color15 }}"
  },
  "editor.tokenColorCustomizations": {
    "textMateRules": [
      {
        "scope": ["comment", "punctuation.definition.comment"],
        "settings": { "foreground": "{{ color8 }}", "fontStyle": "italic" }
      },
      {
        "scope": ["string", "string.quoted", "punctuation.definition.string"],
        "settings": { "foreground": "{{ color2 }}" }
      },
      {
        "scope": ["constant.numeric", "constant.language", "constant.character"],
        "settings": { "foreground": "{{ color5 }}" }
      },
      {
        "scope": ["keyword", "keyword.control", "storage.type", "storage.modifier"],
        "settings": { "foreground": "{{ color5 }}" }
      },
      {
        "scope": ["keyword.operator"],
        "settings": { "foreground": "{{ color6 }}" }
      },
      {
        "scope": ["entity.name.function", "support.function", "meta.function-call"],
        "settings": { "foreground": "{{ color4 }}" }
      },
      {
        "scope": ["entity.name.type", "entity.name.class", "support.type", "support.class"],
        "settings": { "foreground": "{{ color3 }}" }
      },
      {
        "scope": ["variable", "variable.other", "meta.definition.variable"],
        "settings": { "foreground": "{{ foreground }}" }
      },
      {
        "scope": ["variable.parameter"],
        "settings": { "foreground": "{{ color6 }}" }
      },
      {
        "scope": ["entity.name.tag"],
        "settings": { "foreground": "{{ color1 }}" }
      },
      {
        "scope": ["entity.other.attribute-name"],
        "settings": { "foreground": "{{ color3 }}" }
      },
      {
        "scope": ["invalid", "invalid.illegal"],
        "settings": { "foreground": "{{ color1 }}" }
      },
      {
        "scope": ["markup.heading", "entity.name.section"],
        "settings": { "foreground": "{{ accent }}", "fontStyle": "bold" }
      }
    ]
  }
}
