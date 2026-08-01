-- Generated colorscheme. Works in a bare nvim: no plugin manager, no network.

vim.o.background = "{{ mode }}"
if vim.fn.has("termguicolors") == 1 then
  vim.o.termguicolors = true
end

vim.cmd("highlight clear")
if vim.fn.exists("syntax_on") == 1 then
  vim.cmd("syntax reset")
end
vim.g.colors_name = "narchy"

-- surface and muted are not color0 and color8: several palettes hold the same
-- value in both slots, which paints a statusline's text its own background.
local c = {
  bg = "{{ background }}",
  fg = "{{ foreground }}",
  surface = "{{ lighter_background }}",
  muted = "{{ muted }}",
  dim = "{{ dim_text }}",
  accent = "{{ accent }}",
  cursor = "{{ cursor }}",
  sel = "{{ selection }}",
  sel_bg = "{{ selection_background }}",
  sel_fg = "{{ selection_foreground }}",
  red = "{{ color1 }}",
  green = "{{ color2 }}",
  yellow = "{{ color3 }}",
  blue = "{{ color4 }}",
  magenta = "{{ color5 }}",
  cyan = "{{ color6 }}",
  white = "{{ color7 }}",
}

local groups = {
  Normal = { fg = c.fg, bg = c.bg },
  NormalFloat = { fg = c.fg, bg = c.bg },
  FloatBorder = { fg = c.muted },
  Cursor = { fg = c.bg, bg = c.cursor },
  CursorLine = { bg = c.surface },
  CursorLineNr = { fg = c.accent, bold = true },
  LineNr = { fg = c.dim },
  SignColumn = { bg = c.bg },
  Visual = { bg = c.sel },
  Search = { fg = c.bg, bg = c.yellow },
  IncSearch = { fg = c.bg, bg = c.accent },
  MatchParen = { fg = c.accent, bold = true },
  NonText = { fg = c.muted },
  Whitespace = { fg = c.muted },
  WinSeparator = { fg = c.muted },
  Folded = { fg = c.dim, bg = c.surface },
  Title = { fg = c.accent, bold = true },
  Directory = { fg = c.blue },
  Question = { fg = c.green },
  MoreMsg = { fg = c.green },
  ModeMsg = { fg = c.fg, bold = true },
  ErrorMsg = { fg = c.red },
  WarningMsg = { fg = c.yellow },
  Todo = { fg = c.bg, bg = c.yellow, bold = true },

  StatusLine = { fg = c.fg, bg = c.surface },
  StatusLineNC = { fg = c.dim, bg = c.surface },
  TabLine = { fg = c.dim, bg = c.surface },
  TabLineSel = { fg = c.fg, bg = c.bg },
  TabLineFill = { bg = c.surface },
  Pmenu = { fg = c.fg, bg = c.surface },
  PmenuSel = { fg = c.sel_fg, bg = c.sel_bg },
  PmenuSbar = { bg = c.surface },
  PmenuThumb = { bg = c.muted },

  Comment = { fg = c.dim, italic = true },
  Constant = { fg = c.cyan },
  String = { fg = c.green },
  Character = { fg = c.green },
  Number = { fg = c.magenta },
  Boolean = { fg = c.magenta },
  Float = { fg = c.magenta },
  Identifier = { fg = c.fg },
  Function = { fg = c.blue },
  Statement = { fg = c.magenta },
  Conditional = { fg = c.magenta },
  Repeat = { fg = c.magenta },
  Label = { fg = c.magenta },
  Operator = { fg = c.cyan },
  Keyword = { fg = c.magenta },
  Exception = { fg = c.red },
  PreProc = { fg = c.yellow },
  Include = { fg = c.magenta },
  Define = { fg = c.magenta },
  Macro = { fg = c.yellow },
  Type = { fg = c.yellow },
  StorageClass = { fg = c.yellow },
  Structure = { fg = c.yellow },
  Typedef = { fg = c.yellow },
  Special = { fg = c.cyan },
  Delimiter = { fg = c.fg },
  Underlined = { fg = c.blue, underline = true },
  Error = { fg = c.red },

  DiffAdd = { fg = c.green },
  DiffChange = { fg = c.yellow },
  DiffDelete = { fg = c.red },
  DiffText = { fg = c.accent, bold = true },

  DiagnosticError = { fg = c.red },
  DiagnosticWarn = { fg = c.yellow },
  DiagnosticInfo = { fg = c.blue },
  DiagnosticHint = { fg = c.cyan },

  -- Treesitter, for the nvim versions that ship it.
  ["@variable"] = { fg = c.fg },
  ["@function"] = { fg = c.blue },
  ["@keyword"] = { fg = c.magenta },
  ["@string"] = { fg = c.green },
  ["@comment"] = { fg = c.dim, italic = true },
  ["@type"] = { fg = c.yellow },
  ["@constant"] = { fg = c.cyan },
  ["@punctuation"] = { fg = c.fg },
}

for group, opts in pairs(groups) do
  vim.api.nvim_set_hl(0, group, opts)
end

-- The terminal palette, so :terminal matches everything else.
local ansi = {
  "{{ color0 }}", "{{ color1 }}", "{{ color2 }}", "{{ color3 }}",
  "{{ color4 }}", "{{ color5 }}", "{{ color6 }}", "{{ color7 }}",
  "{{ color8 }}", "{{ color9 }}", "{{ color10 }}", "{{ color11 }}",
  "{{ color12 }}", "{{ color13 }}", "{{ color14 }}", "{{ color15 }}",
}
for i, colour in ipairs(ansi) do
  vim.g["terminal_color_" .. (i - 1)] = colour
end
