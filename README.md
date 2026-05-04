# OctoBar ⚡

[![License](https://img.shields.io/github/license/jacko0/octobar)](https://github.com/jacko0/octobar/blob/main/LICENSE)
[![macOS](https://img.shields.io/badge/macOS-13+-orange?logo=apple&logoColor=white)](https://github.com/jacko0/octobar)
[![Swift](https://img.shields.io/badge/Swift-6.0-orange?logo=swift&logoColor=white)](https://swift.org)
[![Latest Release](https://img.shields.io/github/v/release/jacko0/octobar)](https://github.com/jacko0/octobar/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/jacko0/octobar/total)](https://github.com/jacko0/octobar/releases)
[![Stars](https://img.shields.io/github/stars/jacko0/octobar)](https://github.com/jacko0/octobar/stargazers)
[![Last Commit](https://img.shields.io/github/last-commit/jacko0/octobar)](https://github.com/jacko0/octobar/commits/main)

**Real-time Octopus Energy Intelligent Go tariff indicator for your macOS menu bar.**

Never miss a cheap electricity slot again. OctoBar lives in your top bar and instantly shows whether you're on a cheap (green) or standard (red) rate — with flashing alerts on tariff changes.

## Features

- **Live menu bar icon** — Green lightning bolt = cheap rate | Red = standard rate
- **Flashing animation** — Icon pulses when switching between tariffs (4 seconds)
- **Next cheap slot** — Always shows when the next off-peak period starts
- **Full dispatch schedule** — View all planned Intelligent Go cheap slots for the day
- **Notifications** — Get alerted when a cheap rate begins
- **Compact mode** — Icon-only to save menu bar space
- **Settings window** — Easy API key + account number entry
- **Copyable status** — Click any status text to copy for support/debugging
- **Native & lightweight** — Built with SwiftUI + AppKit, no Electron

## Screenshots

(Upload your screenshots to a `screenshots/` folder and update the links)

**Menu bar examples:**

![Green icon](screenshots/green.png)
![Red icon](screenshots/red.png)

**Dropdown menu & Settings:**

![OctoBar menu](screenshots/menu.png)

## Installation

1. Download the latest `.zip` from the [Releases page](https://github.com/jacko0/octobar/releases/latest)
2. Unzip and move `OctoBar.app` to your **Applications** folder
3. Launch OctoBar
4. Click the lightning bolt → **Settings** → enter your Octopus Energy API Key and Account Number

**Requirements:** macOS 13 Ventura or later

## How to Get Your Octopus Credentials

1. Log in at [octopus.energy](https://octopus.energy)
2. Go to **API Access** in your dashboard
3. Generate a new API key
4. Copy your Account Number (starts with `A-`)

## Changelog

### v1.7.2 (29 Mar 2026)
- Fix Swift 6 concurrency warnings (main-actor-isolated Decodable conformance)
- Update app description text
- Version bump

### v1.7.1 (28 Mar 2026) — Flashing icon on tariff change
- **Flashing menu bar icon** — Lightning bolt flashes between red and green for 4 seconds when tariff changes
- **Copyable error text** — Status text in menu can now be selected and copied

### v1.7 (27 Mar 2026) — API fixes & error handling
- Fix HTTP 400 error caused by timezone in date formatting
- Trim whitespace from API key / account number
- Better error messages with endpoint and response body
- Skip retrying on client (4xx) errors

### v1.0.0 (24 Mar 2026)
- Initial release
- Live tariff display (green/red lightning bolt)
- Intelligent Go dispatch schedule
- Notifications on cheap rate start
- Compact mode
- Auto-refresh every 5 minutes

## Tech Stack

- **Swift 6** + **SwiftUI** + **AppKit**
- Modern concurrency (`@MainActor`)
- Native menu bar (`NSStatusItem`)

## Contributing

Pull requests welcome! Ideas include support for other tariffs, WidgetKit, localisation, etc.

## License

MIT © [jacko0](https://github.com/jacko0)

---

**Made for Intelligent Go users who love saving money on electricity** 💰⚡
