# Product

<!-- impeccable:product-schema 1 -->

## Platform

web

## Stack

delegated: static HTML/CSS/JS for the design prototype. Shipping product is a macOS menu bar extra (AppKit + SwiftUI). This repository currently holds requirements and the HTML prototype only.

## Users

Primary: people who already have Codex, Claude Code, or Gemini CLI installed and signed in on their Mac. They have a PDF, screenshot, URL, or text that is not a git project, and they do not want to `cd` into a repo or let the agent touch the original file.

Not in v1: people with no local agent. DropAgent does not offer a cloud model or Ollama fallback.

## Product Purpose

DropAgent is a menu-bar Agent + Shelf utility. Drop content onto the shelf, optionally leave it there, pick a recipe, run the already-installed agent on a one-shot copy, then drag the new result out of the right-hand results stack. The left-hand input stays put. Original files are never overwritten by DropAgent.

Success is: original file hash unchanged; a new file appears in the tray; the user can drag it to Finder, Desktop, or an upload field; before run they can see who runs, where it writes, network, and which isolation grade.

## Positioning

Not a clipboard manager, not a pure shelf (Yoink), not an AI clipboard (Stash), not an agent launcher (GroAsk). The mechanism is: Artifact in → isolated job on a copy → Artifact out as a draggable object.

## Operating Context

Lives in the macOS menu bar. Also needs a six-slice drop wheel around the pointer while dragging, because the status item is small and the menu bar can hide in fullscreen. The wheel stays off the top tab strip so fullscreen browser tab reordering is not blocked; leaving the ring dismisses it. First look after open is staged items, not clipboard history. Typical session: two to six items, one recipe, one result to drag. Used between other apps, in short bursts, often at night at a desk.

## Capabilities and Constraints

- Inputs: files, folders, PDF, images, text/Markdown, URL, website capture (title, URL, markdown body, screenshot), multi-file sets.
- Global hotkey while Safari/Chrome (Edge best-effort) is frontmost adds the current page to the shelf as one WEB item containing URL, `page.md`, and `snapshot.png`. Dropping or pasting an http(s) URL onto the shelf does the same fetch (no front-window screenshot). Dropping onto the AI pane sends the link only. No browser extension. Does not auto-run. Partial capture is allowed; missing body or screenshot is labeled. DropAgent fetches the page itself (network). Logged-in article body is not promised in v1. Details: `02-prototype-design.md` section 7.
- A third global hotkey adds the front app’s selected local files: Finder selection (AppleScript); other apps simulate ⌘C and keep only files, restoring the clipboard, then fall back to the open local file (`AXDocument`). Browsers are refused (use page capture). Originals stay put. No per-app plugins.
- First open shows a skippable readiness checklist when Accessibility or browser automation is not granted. The same list lives at the top of Settings. Authorizing a browser must present the system control prompt; opening an empty Automation pane is not enough.
- Settings lists every shortcut (global toggle/capture and in-panel hide/paste/copy/delete are editable; up/down is display-only) and a capability guide: drop targets, accepted types, shelf URL capture vs AI-pane link, what is read, where files are written, and drag-out payloads. Originals are never overwritten. Dropping on the wheel does not open or close the panel.
- Shelf can hold items without running.
- Recipes (v1 names only): summarize, extract, translate keeping format, redact, convert to Markdown, assemble a new brief from several materials.
- Files drag out as standard Mac pasteboard types (file, text, image, URL). Promise Finder, Desktop, file upload fields, Office attachments, most IM threads, most AI-desktop composers, and text editors when the payload is text. No per-app plugins. Spring back if the target refuses. Copy, not move. One item at a time. Staged originals may drag out too. Details: `02-prototype-design.md` section 6.
- Isolation labels: Safe Copy (Claude / custom CLI), Workspace Sandbox (Codex / Gemini when their flags support it), Strict Isolation not in v1.
- Never load the user's global MCP, hooks, or project rules by default.
- Prototype scope from `01-requirements.md` section 8: stage, hash, Codex, drag out. This design prototype shows the full tray loop including recipes and empty/no-agent states as UI, even when the engineering prototype will only wire summarize + Codex.

## Brand Commitments

Name: DropAgent. Binding aesthetic from the user: tool-like, tactile, appropriate density, a clear path, functions that are obvious. Sit with Yoink, Dropover, and menu-bar developer utilities, not with AI command centers. Chinese UI by default; English available in Settings. No product name besides DropAgent.

## Evidence on Hand

`01-requirements.md` is the locked product record. No real screenshots, logos, or customer quotes. Prototype shelf items are labeled synthetic.

## Product Principles

1. The tray is a shelf, not a dashboard.
2. Originals stay put; results are new files the user takes away.
3. Isolation grade is spoken honestly on the run confirmation.
4. Density serves an ~800px menu-bar panel used for seconds: inputs left, work in the middle, results right — not a workspace window.
5. No agent means a clear miss, never a silent cloud call.

## Accessibility & Inclusion

No product-specific legal standard recorded yet. Prototype should be keyboard-reachable for the panel controls and keep body text contrast at least 4.5:1.
