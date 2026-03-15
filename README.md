[![noTunes Logo](/screenshots/app-icon.png)](https://github.com/tombonez/noTunes)

[![GitHub release (latest by date)](https://img.shields.io/github/v/release/tombonez/notunes)](https://github.com/tombonez/noTunes/releases/latest)
[![GitHub all releases](https://img.shields.io/github/downloads/tombonez/notunes/total)](https://github.com/tombonez/noTunes/releases)
[![GitHub](https://img.shields.io/github/license/tombonez/notunes)](https://github.com/tombonez/noTunes/blob/master/LICENSE)
[![GitHub Sponsors](https://img.shields.io/badge/sponsor-tombonez-ec5cc7.svg)](https://github.com/sponsors/tombonez)

# noTunes

noTunes is a macOS application that will prevent iTunes _or_ Apple Music from launching.

Simply launch the noTunes app and iTunes/Music will no longer be able to launch. For example, when bluetooth headphones reconnect.

When noTunes is enabled, the Play/Pause media key is intercepted so Music does not open.

noTunes can also remap Play/Pause to FaceTime mute/unmute while preserving the original iTunes/Music kill fallback.

You can toggle noTunes on/off via the menu bar icon with a simple left click.

## Installation

### Direct Download

Download the latest build from [Releases](https://github.com/tombonez/noTunes/releases/latest).

### Homebrew

```bash
brew install --cask notunes
```

## Usage

### Set noTunes to launch at startup

#### Ventura and later:

1. Navigate to System Settings
2. Select General
3. Select Login Items
4. Click the + under Open at Login and select noTunes

#### Before Ventura:

Navigate to System Preferences -> Users & Groups. Under your user, select "Login Items", click the lock on the bottom left and enter your login password to make changes. Click the plus sign (+) in the main panel and search for noTunes. Select it and click "Add".

### Toggle noTunes Functionality

Left click the menu bar icon to toggle between its active states.

**Enabled (prevents iTunes/Music from opening)**

![noTunes Enabled](/screenshots/menubar-enabled.png)

**Disabled (allows iTunes/Music to open)**

![noTunes Disabled](/screenshots/menubar-disabled.png)

### Hide Menu Bar Icon

Right click or control-click the menu bar icon and click `Hide Icon`.

### Toggle FaceTime Mute Remap

Right click or two-finger click the menu bar icon and toggle `FaceTime Mute Remap`.

- Enabled (default): noTunes attempts FaceTime mute/unmute on Play/Pause.
- Disabled: noTunes still blocks Music/iTunes from Play/Pause, but skips FaceTime mute automation.

### Restore Menu Bar Icon

[Quit noTunes](#quit-notunes), run the following command in Terminal and re-open the app:

```bash
defaults delete digital.twisted.noTunes
```

### Quit noTunes

To quit the app either:

**With menu bar icon visible**

Right click or control-click the menu bar icon and click quit.

**With menu bar icon hidden**

Quit the app via Activity Monitor or run the following command in Terminal:

```bash
osascript -e 'quit app "noTunes"'
```

### Set replacement for iTunes / Apple Music

Replace `YOUR_MUSIC_APP` with the name of your music app in the following command.

```bash
defaults write digital.twisted.noTunes replacement /Applications/YOUR_MUSIC_APP.app
```

Then `/Applications/YOUR_MUSIC_APP.app` will launch when iTunes/Music attempts to launch.

This can be used to open a website too, for example, YouTube Music.

```bash
defaults write digital.twisted.noTunes replacement https://music.youtube.com/
```

The following command will disable the replacement.

```bash
defaults delete digital.twisted.noTunes replacement
```

## Publishing Releases on GitHub

This repo includes a release workflow at [.github/workflows/release.yml](./.github/workflows/release.yml).

How to publish a downloadable release:

1. Commit and push your changes to GitHub.
2. Create and push a version tag:

```bash
git tag v3.6
git push origin v3.6
```

3. GitHub Actions will build `noTunes.app`, zip it, and attach it to a GitHub Release automatically.
4. Share the `releases/latest` link so users can always get the newest download.

## Support

If you like my work, consider supporting me through [GitHub Sponsors](https://github.com/sponsors/tombonez) 🩷

## License

The code is available under the [MIT License](https://github.com/tombonez/notunes/blob/master/LICENSE).
