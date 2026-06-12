# ClaudeBar

**English** | [繁體中文](README.zh-TW.md)

![Platform](https://img.shields.io/badge/platform-macOS%2013%2B-lightgrey)

A tiny macOS menu-bar app that shows your **official Claude 5-hour usage** at a glance, plus a per-day usage chart.

<p align="center">
  <img src="assets/demo.png" width="400" alt="ClaudeBar screenshot">
</p>

## Features

- **Official usage** — your real 5-hour utilization and reset time, the same numbers Claude Code's `/usage` shows.
- **Menu-bar glance** — the Claude logo next to a mini progress bar with your 5-hour percentage printed right on it; one click for the details.
- **Daily chart** — per-day usage for the last week, stacked by model family (Opus / Sonnet / Haiku); toggle between percent and dollars.
- **Settings panel** — a gear in the top-right opens an in-app settings page: account, switch account, sign out, launch at login, version, and updates.
- **Self-update** — checks GitHub Releases for a newer version and updates itself with one click.
- **Launch at Login** — optional, one toggle.
- **Private** — talks only to Anthropic; your token never leaves your machine.

## Install

Download the `.zip` from [Releases](../../releases), unzip, and move `ClaudeBar.app` to `/Applications`.

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

Open the **gear** (top-right) for settings: switch account, **Launch at Login**, version, and **Check for Updates**.

## Updating

When a newer version is published to GitHub Releases, the app shows an **update banner** — click **Update** to download, swap, and relaunch automatically. You can also trigger it from **Settings → Check for Updates**.
