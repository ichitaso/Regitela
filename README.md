<p align="center">
  <img src="Regitela/Assets.xcassets/AppIcon.appiconset/AppIcon.png" width="128" alt="Regitela icon">
</p>

<h1 align="center">Regitela</h1>

<p align="center">
  A file explorer and tweak toolbox for iOS, built on the <a href="https://github.com/forcequitOS/worse_query">worse_query</a> sandbox escape.
</p>

## Installation

> [!IMPORTANT]
> **Install the IPA with [Impactor](https://github.com/claration/impactor/releases). Regitela does not work when installed with Sideloadly.**
>
> Regitela needs its App Group entitlement for worse_query. Sideloadly signs the app without it, so every feature fails with "no accessible app group" and "Couldn't get access to the container". Impactor keeps the App Group when it signs the app.

1. Download `Regitela_<version>.ipa` from the [Releases](../../releases) page.
2. Install it with [Impactor](https://github.com/claration/impactor/releases).
3. Open Regitela. If the Log tab shows `app group: none`, the App Group was lost while signing. Reinstall with Impactor.

## Before You Begin

> [!WARNING]
> **Use Regitela at your own risk.** It edits files that iOS normally keeps out of reach, and a wrong edit can make apps or iOS misbehave. **Back up your device first.** The developers are not responsible for any damage or data loss.

> [!CAUTION]
> Don't enable Supervised Mode on a device that is already managed by MDM.

## Features

- **Supervised Mode**: turn it on or off. Quit the Settings app to apply.
- **Region**: change the region code and sales region in the MobileGestalt cache to US (LL/A). Reboot to apply; the change stays after later reboots. The original values are backed up and can be restored.
- **Browse**: open App Group and system containers directly. Edit and save text files, create new ones, and delete files.
- **Containers**: find the containers of apps, extensions and system services with pathleak. They are listed by app name or bundle ID, and you can open any of them.
- **Advanced**: the original worse_query tools, which work on any path. You can hold a sandbox extension, share a path's contents and list the folders under a path.
- Liquid Glass UI, localized into 17 languages.

## Supported Versions

| Install | iOS | Notes |
|---|---|---|
| IPA (sideload) | 26.0 - 26.7.2, 27.0 - 27.2 | Supervised Mode, Region and Browse need iOS 27 |

> [!NOTE]
> Versions not listed are unsupported. worse_query may be patched in a future iOS update.

## Building

You need [Theos](https://theos.dev) and Xcode 26.

```sh
make package
```

This command creates both the IPA and the rootless .deb in `packages/`.

To target a different region, edit `targetCountry`, `targetCode` and `targetRegion` in `Regitela/Region.swift` (for example `J` and `J/A` for Japan, or `B` and `B/A` for the UK) and rebuild. The sales region (RegionInfo) is changed only under the key the device already has: on iOS 27, adding a key that isn't there makes iOS rebuild the cache at the next boot.

## FAQ

1. **Nothing works, and the Log tab shows "no accessible app group".**
   The app was signed without its App Group, which happens with Sideloadly. Reinstall it with [Impactor](https://github.com/claration/impactor/releases).
2. **Supervised Mode, Region or Browse don't work on iOS 26.**
   They need iOS 27. On iOS 26, worse_query can't reach the SystemGroup containers.
3. **The Containers scan takes a long time.**
   pathleak brute-forces inodes, so the first scan is slow. The results are kept until the app quits.
4. **Some containers show a bundle ID instead of an app name.**
   iOS only gives a sandboxed app the names of some installed apps.
5. **What does the Log tab show?**
   It shows what the app is doing and why something failed. Long-press the text to copy it.

## Credits

- [ichitaso](https://github.com/ichitaso): Regitela
- [forcequit (Taj C)](https://github.com/forcequitOS): [worse_query](https://github.com/forcequitOS/worse_query) and pathleak. Regitela is based on worse_query.

## License

Regitela is licensed under [GPL-3.0](LICENSE), the same license as worse_query.
