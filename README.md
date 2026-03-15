[![noTunesMute Logo](/screenshots/app-icon.png)](https://github.com/rayanical/noTunesMute)

[![GitHub release (latest by date)](https://img.shields.io/github/v/release/rayanical/noTunesMute)](https://github.com/rayanical/noTunesMute/releases/latest)
[![GitHub all releases](https://img.shields.io/github/downloads/rayanical/noTunesMute/total)](https://github.com/rayanical/noTunesMute/releases)
[![GitHub](https://img.shields.io/github/license/rayanical/noTunesMute)](https://github.com/rayanical/noTunesMute/blob/main/LICENSE)

# noTunesMute

`noTunesMute` is a macOS menu bar app that blocks Apple Music/iTunes launches and remaps Play/Pause to FaceTime mute/unmute.

## What It Does

- Blocks Play/Pause from launching Apple Music/iTunes when protection is enabled.
- Keeps the original launch-kill safety net for `com.apple.Music` and `com.apple.iTunes`.
- Remaps Play/Pause to FaceTime mute/unmute with a learned fast strategy cache.
- Lets you toggle the FaceTime remap feature from the right-click menu.

## Installation

Download the latest build from [Releases](https://github.com/rayanical/noTunesMute/releases/latest).

## Usage

### Set noTunesMute to Launch at Startup

#### Ventura and later

1. Open System Settings.
2. Go to General.
3. Go to Login Items.
4. Click `+` under Open at Login and select `noTunesMute`.

#### Before Ventura

Open System Preferences -> Users & Groups -> Login Items and add `noTunesMute`.

### Toggle Protection

Left click the menu bar icon to toggle protection.

**Enabled (blocks iTunes/Music launch)**

![noTunes Enabled](/screenshots/menubar-enabled.png)

**Disabled (allows iTunes/Music launch)**

![noTunes Disabled](/screenshots/menubar-disabled.png)

### Toggle FaceTime Mute Remap

Right click or two-finger click the menu bar icon and toggle `FaceTime Mute Remap`.

- Enabled (default): Play/Pause attempts FaceTime mute/unmute.
- Disabled: Play/Pause is still blocked from opening Music/iTunes, but FaceTime mute remap is skipped.

### Hide Menu Bar Icon

Right click or control-click the menu bar icon and click `Hide Icon`.

### Restore Menu Bar Icon

Quit the app and run:

```bash
defaults delete digital.twisted.noTunes
```

Then reopen `noTunesMute`.

### Quit

With the menu bar icon visible, right click/control-click and choose `Quit`.

With the icon hidden:

```bash
osascript -e 'quit app "noTunes"'
```

### Optional Replacement App (Music/iTunes launch fallback)

```bash
defaults write digital.twisted.noTunes replacement /Applications/YOUR_MUSIC_APP.app
```

Or open a URL:

```bash
defaults write digital.twisted.noTunes replacement https://music.youtube.com/
```

Disable replacement:

```bash
defaults delete digital.twisted.noTunes replacement
```

## License

The code is available under the [MIT License](https://github.com/rayanical/noTunesMute/blob/main/LICENSE).
