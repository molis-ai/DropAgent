---
name: DropAgent
description: Menu-bar shelf plus in-panel Codex TUI. Files above, AI below.
colors:
  desk: "#1c1c1e"
  panel: "#2c2c2e"
  panel-2: "#3a3a3c"
  ai: "#262628"
  text: "#f5f5f7"
  muted: "#c7c7cc"
  faint: "#8e8e93"
  line: "rgba(255,255,255,.09)"
  primary: "#0a84ff"
  primary-press: "#0071e3"
  success: "#30d158"
  danger: "#ff453a"
typography:
  body:
    fontFamily: "-apple-system, BlinkMacSystemFont, SF Pro Text, Helvetica Neue, sans-serif"
    fontSize: "13px"
    fontWeight: 500
    lineHeight: 1.35
    letterSpacing: "-0.015em"
  meta:
    fontFamily: "-apple-system, BlinkMacSystemFont, SF Pro Text, Helvetica Neue, sans-serif"
    fontSize: "11px"
    fontWeight: 400
    lineHeight: 1.4
    letterSpacing: "normal"
  tty:
    fontFamily: "ui-monospace, SF Mono, Menlo, monospace"
    fontSize: "12px"
    fontWeight: 400
    lineHeight: 1.55
    letterSpacing: "normal"
rounded:
  sm: "4px"
  md: "6px"
  panel: "10px"
spacing:
  row: "8px"
  pad: "10px"
components:
  button-primary:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.text}"
    rounded: "{rounded.md}"
    height: "28px"
  tag:
    backgroundColor: "rgba(255,255,255,.08)"
    textColor: "{colors.muted}"
    rounded: "{rounded.sm}"
    padding: "0 5px"
---

## Overview

DropAgent is a dark macOS menu extra. The panel is one column: a resizable file list on top, an AI pane (actions, PTY, results) below. Type tags name file kinds. System blue is only for send, selection, and drop.

## Colors

Night-desk charcoal. One accent. Status uses green for connected, red for missing Agent, blue pills for sent-to-TUI, green pills for drag-ready.

## Typography

System UI for chrome. SF Mono only inside the terminal log. No display face.

## Layout

400px panel hung from the status item. Header 36px. List 108–320px via splitter. AI fills the rest. Desktop chips sit left of the panel; a Finder well receives drag-out.

## Elevation & Depth

Inset 1px highlight plus offset shadow. No glow halo. No decorative blur on the panel body; menubar may use system blur.

## Shapes

Panel 10px. Controls 6px. Type tags 4px. Pills only on status words.

## Components

- File row: tag + name + time + status line. Whole row drags.
- AI tabs: 动作 / 终端 / 结果.
- Composer: count, field, 粘贴, 发送.
- Drop: list = stage, AI = send to TUI.

## Do's and Don'ts

Do: keep files above talk; show results in-tool; copy and drag as the takeaway. Drag out is a standard file/text/image/URL, not a per-app integration. A site hotkey adds one WEB row (title, URL, markdown, screenshot) without an extension.

Don't: left-right split; clipboard history as home; file pictograms; a separate Terminal window beside the panel; promise Figma/Notion internals or auto-send in chat apps; ship a browser extension for v1 capture.
