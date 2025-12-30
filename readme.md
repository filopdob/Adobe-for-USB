# Adobe Downloader

![Adobe Downloader 2.0.0](imgs/Adobe%20Downloader%202.0.0.png)

## Before Use

> ⚠️ This repository does not support PR submissions

**Due to the rewritten Helper in v2.1, the minimum macOS requirement is now 13.0+ (no longer supports 12.0).**
**🍎Only for macOS 13.0+.**

> **If you like Adobe Downloader, or it helps you, please Star 🌟 it.**
>
> 1. Before installing Adobe products, the Adobe Setup component must be present on your system; otherwise, the
>    installation feature will not work. You can download it through the built-in Settings in the app or
>    from [Adobe Creative Cloud](https://creativecloud.adobe.com/apps/download/creative-cloud).
> 2. To enable smooth installation after downloading, Adobe Downloader needs to modify Adobe’s Setup program. This
>    process is fully automated by the app and requires no user intervention.
> 3. If you encounter any problems, contact [@X1a0He](https://t.me/X1a0He_bot) on Telegram.
> 4. ⚠️⚠️⚠️ **All Adobe apps in Adobe Downloader are from official Adobe channels and are not cracked versions.**
> 5. ✅ You can choose an external drive or USB for both download and installation, but keep the drive connected and
>    ensure it is writable to avoid permission issues.

## What’s New

- Download directory is also the install directory
- Menu bar app with quick actions
- Daily update checks for Adobe Downloader
- Installed Apps tab with version tracking and optional auto-update
- Downloaded Apps tab with size/date/features info
- Maintenance: cleaned up Xcode build warnings and script phase dependencies

See [Changes](changes.md) for details.

## How It Works (Simple)

1. Pick a download directory in Settings (this is also where apps will be installed).
2. Download a product, then click Install.
3. Use the Installed tab to track versions and update apps.
4. Use the Downloaded tab to see what you already have on disk.

## Features

- Downloads official Adobe products
- Installs to your chosen directory
- Menu bar quick access
- Daily app update checks
- Download manager with resume/pause
- Installed Apps tab: detect apps, show current/latest version, optional auto-update
- Downloaded Apps tab: show size, date, and feature list
- Cleanup tools

## FAQ

**Why does it install to my selected download directory?**
The installer uses the same directory you choose in Settings, which allows installs to external drives if needed.

**Does auto-update change my system without asking?**
Auto-update only runs for apps where you enable it in the Installed tab.

## Preview

### Light Mode & Dark Mode

![light](imgs/preview-light.png)
![dark](imgs/preview-dark.png)

### Version Picker

![version picker](imgs/version.png)

### Language Picker

![language picker](imgs/language.png)

### Download Management

![download management](imgs/download.png)

## References

- [QiuChenly/InjectLib](https://github.com/QiuChenly/InjectLib/)

## Author

Adobe Downloader © X1a0He

Released under GPLv3. Created on 2024.11.05.

> GitHub [@X1a0He](https://github.com/X1a0He) \
> Telegram [@X1a0He](https://t.me/X1a0He_bot)

## Languages

- English (default)
- [中文](readme-zh.md)
