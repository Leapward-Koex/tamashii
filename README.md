# Tamashii

Tamashii is a personal project for tracking anime episode releases, maintaining
a weekly watching list, and managing torrent downloads. It supports Android 12
and newer and Windows.

Tamashii is a release tracker and download manager. It does not stream or play
video.

[Releases](https://github.com/Leapward-Koex/tamashii/releases) ·
[Issues](https://github.com/Leapward-Koex/tamashii/issues)

## Features

- Home lists recent episode releases from SubsPlease and supports title search.
- Bookmarking a show on Home adds it to the watching list and Schedule.
- Schedule groups saved shows by weekday. Add a show by title or choose a match
  from Tenrai's catalog.
- Available episode downloads can be started from Home or the Android home
  screen widget. New downloads use the highest resolution offered by the source.
- Downloads shows live progress, rates, estimated time remaining, peers, and
  paused, waiting, or failed transfers. Individual and bulk pause/resume are
  available.
- A download base folder and per-series folders can be configured in Settings.

## Installation

Release packages are published on the
[Releases page](https://github.com/Leapward-Koex/tamashii/releases). Check the
release notes to see whether a build is a prerelease.

### Android

Android 12 or newer is required.

1. Download the APK from a release.
2. Open the APK and complete Android's install prompt.
3. If asked, allow the browser or file manager to install apps from that
   source.

### Windows

1. Download the Windows ZIP from a release.
2. Extract the entire ZIP to a folder.
3. Run `tamashii.exe` from the extracted folder.

Keep the extracted files together. The executable requires the files beside it.

## Basic use

1. In **Settings**, choose a **Download Base Folder** if automatic per-series
   folders are wanted.
2. On **Home**, browse, search, or refresh the release list. Bookmark a show to
   add it to the watching list.
3. In **Schedule**, move a saved show to another weekday or use **+** to add a
   manual planning entry. Choose **Add by title** to save it without a search
   result, then use **Match with Tenrai** from the entry if you want to link it
   later.
4. Select **Download** on an available episode. On Android, grant folder access
   when prompted.
5. Open **Downloads** from Home to view active transfers or pause and resume
   them.

### Android home screen widget

Open your launcher's widget picker and add **Tamashii → Today on your watchlist**.
The compact agenda lists watched shows expected today. Once the feed confirms
an episode was released on your phone's current local date, tap **Download**
to start it. **Set up** lets you grant permissions or choose a series folder.
Android refreshes the feed periodically while the app is closed.

Resize the widget taller for the release inbox. During a transfer the wide
button becomes a progress bar, or a ring in the inbox. Queued, waiting for
network, paused and downloaded episodes have their own status.

### Schedule entries and downloads

Saving a show does not subscribe it to downloads. Download buttons appear only
for episodes currently available through the SubsPlease feed, and every
transfer is started manually.

Manual Schedule entries are for planning only. They do not appear in Home or
provide download options.

Folders are independent of the watching list. A show can have a download folder
without being on Schedule, and a scheduled show does not need a download folder.

Deleting a series folder in **Settings** deletes that folder and all of its
contents.

## Downloads and Android settings

On Android, downloads over mobile data and metered networks are disabled by
default. They are separate settings in **Settings**. A transfer waits when its
network is not allowed and can continue when the network becomes suitable.

Android requests access to the selected download folder. It may also request
notification and battery-optimisation permissions when a download starts.
Notifications show active download status; the battery-optimisation exemption
helps long downloads continue when the app is not visible.

On Windows, leave Tamashii running while a download is active. Ensure the
selected drive has enough free space for the episode.

The Downloads screen is a live transfer monitor, not a history. Completed
episodes remain in their selected folders and leave the queue.

## Development

Use the Flutter version in `.fvmrc` and run `flutter pub get` (or
`fvm flutter pub get` when using FVM). Enable the versioned pre-commit hook once
per clone:

```sh
git config --local core.hooksPath .githooks
```

The hook formats and restages staged Dart files, then runs
`flutter analyze --no-pub` on the working tree. It stops if a staged Dart file
also has unstaged edits, so partial staging is preserved.

## Data sources and torrent use

Tamashii does not require an account. Watching-list data, folder choices, and
download markers are stored locally.

Recent release information and torrent magnets come from
[SubsPlease](https://subsplease.org). The [Tenrai API](https://tenrai.org)
supplies MyAnimeList title matches for Schedule. These services control their
own availability and metadata.

Tamashii does not host media. Torrent transfers can expose your IP address to
peers and trackers. Download only material you are entitled to access and
follow applicable laws and source terms.

## Troubleshooting

| Problem | Check |
| --- | --- |
| A download is waiting for a network | On Android, check the mobile-data and metered-network settings. Both are opt-in. |
| A download cannot start | Choose a writable folder, grant Android folder access, and check free disk space. |
| An Android download stops in the background | Check notification permission and Android battery settings. |
| A completed episode is absent from Downloads | Downloads is a live queue. Check the selected series folder. |

For bugs or suggestions, [open an issue](https://github.com/Leapward-Koex/tamashii/issues)
with the platform, app version, expected result, and actual result.
