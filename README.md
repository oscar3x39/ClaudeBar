# ClaudeBar

![Platform](https://img.shields.io/badge/platform-macOS%2013%2B-lightgrey)

A tiny macOS menu-bar app that shows your **official Claude 5-hour usage** at a glance, plus a per-day usage chart.

## Features

- **Official usage** — your real 5-hour utilization and reset time, the same numbers Claude Code's `/usage` shows.
- **Menu-bar glance** — a mini `5h` bar in the menu bar; one click for the details.
- **Daily chart** — per-day usage for the last week; toggle between percent and dollars.
- **Launch at Login** — optional, one toggle.
- **Private** — talks only to Anthropic; your token never leaves your machine.

## Install

Download `ClaudeBar.app.zip` from [Releases](../../releases), unzip, and move `ClaudeBar.app` to `/Applications`.

The app is ad-hoc signed (not notarized), so Gatekeeper warns on first launch. Either right-click the app and choose **Open**, or clear quarantine:

```bash
xattr -dr com.apple.quarantine /Applications/ClaudeBar.app
```

Or build it yourself:

```bash
swift build -c release && bash scripts/build-app.sh
```

## Usage

1. Click the menu-bar icon → **Sign in with Claude**.
2. Authorize in the browser, then paste the returned code (`code#state`) back into the app.
3. Done — the menu bar shows your 5-hour usage. Click for the progress bar, reset countdown, and daily chart.

Turn on **Launch at Login** from the popover if you want it to start automatically.
