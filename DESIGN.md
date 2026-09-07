---
name: DropAgent
description: Menu-bar shelf plus in-panel TUI. Files left, AI right. Paper over a dark desk.
colors:
  desk: "#121212"
  panel: "#f7f7f5"
  panel-2: "#ececea"
  panel-hover: "#e2e2e0"
  panel-press: "#d2d2d0"
  ai: "#f7f7f5"
  text: "#111111"
  muted: "#5a5a5a"
  faint: "#6e6e6e"
  line: "rgba(0,0,0,.1)"
  primary: "#111111"
  primary-press: "#000000"
  on-accent: "#f7f7f5"
  tty-well: "#171717"
  tty-ink: "#e8e8e8"
  tty-muted: "#a8a8a8"
typography:
  body:
    fontFamily: "-apple-system, BlinkMacSystemFont, SF Pro Text, Helvetica Neue, sans-serif"
    fontSize: "13px"
    fontWeight: 500
    lineHeight: 1.35
    letterSpacing: "-0.015em"
  brand:
    fontFamily: "New York, Iowan Old Style, Times New Roman, serif"
    fontSize: "15px"
    fontWeight: 500
    letterSpacing: "-0.02em"
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
  md: "8px"
  panel: "12px"
spacing:
  row: "8px"
  pad: "14px"
components:
  button-primary:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.on-accent}"
    rounded: "{rounded.md}"
    height: "30px"
  tag:
    backgroundColor: "{colors.panel-2}"
    textColor: "{colors.muted}"
    rounded: "{rounded.sm}"
    padding: "0 5px"
---

## Overview

DropAgent is a light paper panel hung from the macOS menu bar. Two columns: files left, AI right. Near-white ground, ink type. Black only for send, selection, and drop. Actions use SF Symbols. File kinds stay letter tags.

## Colors

Paper over a dark desk. No chromatic accent. Status is weight, gray, and icons.

## Typography

SF Pro for chrome. New York for the wordmark. SF Mono only inside the terminal log.

## Layout

680px panel hung from the menu bar. Header 44px; the DropAgent wordmark is centered; engine chip, settings, minimize, and close sit on the right. Shelf column default 240px, draggable 200–320px. AI fills the rest on the same paper. The terminal well is near-black.

## Elevation & Depth

Soft offset shadow. Hairline borders. No glow, no glass, no inset chrome.

## Shapes

Panel 12px. Controls 8px. Type tags 4px.

## Components

- File row: tag + name + time + status. Multi-select shows a leading check. Whole row drags. Shelf chrome: + to pick files, Spotlight search to add from this Mac.
- Header: wordmark centered; engine chip, settings, minimize, and close on the right. Settings overlay: readiness list, editable shortcuts (including add-selected-files), drop/read/write guide, workspace paths, runtime, appearance, language.
- AI tabs: 动作 / 终端 / 结果, each with an icon.
- Composer: count, field, clipboard icon, paperplane send.
- Recipes: icon over short title.
- Terminal well: near-black, including the opening and idle captions.
- Drop: list = stage, AI = send to TUI.

## Do's and Don'ts

Do: keep files beside talk; show results in-tool; copy and drag as the takeaway.

Don't: system blue or pine accents; colored status dots; file pictograms; a separate Terminal window; clipboard history as home.
