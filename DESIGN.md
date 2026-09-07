---
name: DropAgent
description: Quiet menu-bar shelf. Cool sage paper over a night desk, after GoalBoard Onboarding.
colors:
  desk: "#050607"
  panel: "#f1f3f2"
  panel-2: "#ecefee"
  panel-hover: "#e9eceb"
  panel-press: "#e2e5e4"
  ai: "#f1f3f2"
  text: "#1f272b"
  muted: "#59656b"
  faint: "#5d696f"
  icon: "#718086"
  line: "#d4dad9"
  primary: "#222b30"
  primary-press: "#11181c"
  on-accent: "#f7f8f7"
  field: "#e6eae9"
  tty-well: "#17191c"
  tty-ink: "#e8e8e3"
  tty-muted: "rgba(237,237,232,.62)"
  tag-pdf: "#ead6c2"
  tag-pdf-ink: "#5a3824"
  tag-image: "#d5e6db"
  tag-image-ink: "#2f5340"
  tag-url: "#d9e0ec"
  tag-url-ink: "#33445c"
  tag-web: "#d4e4e6"
  tag-web-ink: "#2f4d52"
  tag-md: "#dde3dc"
  tag-md-ink: "#334038"
  tag-clip: "#ece0c8"
  tag-clip-ink: "#5a4320"
typography:
  body:
    fontFamily: "-apple-system, BlinkMacSystemFont, SF Pro Text, PingFang SC, sans-serif"
    fontSize: "13px"
    fontWeight: 570
    lineHeight: 1.35
    letterSpacing: "-0.015em"
  brand:
    fontFamily: "-apple-system, BlinkMacSystemFont, SF Pro Text, PingFang SC, sans-serif"
    fontSize: "10px"
    fontWeight: 760
    letterSpacing: "0.1em"
  meta:
    fontFamily: "ui-monospace, SF Mono, Menlo, monospace"
    fontSize: "10px"
    fontWeight: 620
    lineHeight: 1.5
    letterSpacing: "0.08em"
  tty:
    fontFamily: "ui-monospace, SF Mono, Menlo, monospace"
    fontSize: "12px"
    fontWeight: 400
    lineHeight: 1.72
    letterSpacing: "normal"
rounded:
  sm: "4px"
  md: "6px"
  lg: "9px"
  panel: "12px"
  pill: "99px"
spacing:
  row: "10px"
  pad: "18px"
components:
  button-primary:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.on-accent}"
    rounded: "5px"
    height: "38px"
  tag:
    backgroundColor: "transparent"
    textColor: "{colors.faint}"
    rounded: "0px"
    padding: "0"
---

## Overview

DropAgent is a quiet sage panel hung from the macOS menu bar. It borrows GoalBoard Onboarding’s calm: leftover space, a short guide, stroke icons, and no shouting. Three columns: inputs left, work middle, results right. No chromatic accent. No glass.

## Colors

Cool sage `#f1f3f2` over night `#050607`. Ink `#1f272b`. Selection is a deeper wash, not a color bar. The only solid fill is 拖出. File kinds get a dusty tag wash (PDF brown, image green, URL slate, WEB teal, MD moss, CLIP ochre). Color stays on the tag, not the row.

## Typography

SF Pro / PingFang. Tracked 10px wordmark. Intro 15px. Meta in tiny mono. SF Mono only in the terminal.

## Layout

800px panel. Header 48px, brand left. Input 196px, results 196px, work fills the rest. Work pane is a single column of action rows: a 120px paper button on the left, one muted sentence on the right. 其他 is the last row. The bottom field stays hidden until 其他 is on, then expands in place. The terminal tab does not show the composer.

## Elevation & Depth

One offset shadow on the panel. Hierarchy is tone, not a grid of borders. Splitters are invisible until hover.

## Shapes

Panel 12px. Choice rows 6px. Send is a circle. 拖出 is 5px.

## Components

- File row: mono tag + name + time. Hover wash. Whole row drags.
- Header: tracked DROPAGENT; engine as underline; settings / minimize / close as 13px strokes.
- Work tabs: 动作 / 终端 / 预览 as text with an underline on the current one.
- Recipes: one vertical list. Each row is a paper button (stroke icon + short name) plus a muted one-line blurb. Click the button, not the sentence. 其他 is the seventh row.
- 其他: only the button latches on; the composer appears at the bottom in place, not as a modal. The terminal tab does not show the composer.
- Confirm: option rows + review list, no questionnaire title.
- Empty: title + one guiding sentence.
- Terminal well: `#17191c`, no chrome frame.
- Drop: list = stage, middle = send to TUI.

## Do's and Don'ts

Do: leave space; teach in empty states; keep icons quiet; let 拖出 be the one solid action.

Don't: cobalt as brand; glass; serif wordmark; boxed recipe tiles; file pictograms; a separate Terminal window.

Status color is reserved: running teal, waiting amber, failed dusty red, sent slate, ready sage. Icons sit with those states. The work pane fills the middle column; running is centered with a spinner.
