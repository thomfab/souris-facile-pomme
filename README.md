# Souris facile pomme

A macOS menu bar app to move or resize the window under the pointer by holding
modifier keys and moving the mouse: no clicking, no dragging, no aiming for a
title bar or a window border.

It's the macOS version of the [Souris Facile GNOME Shell
extension](https://github.com/thomfab/souris-facile).

(Disclaimer: Claude Code helped me)

## How it works

Hold a key combination and move the mouse:

| Keys (default)                    | Action                              |
| --------------------------------- | ----------------------------------- |
| `⌃ Control` + `⌥ Option`          | Move the window under the pointer   |
| `⌃ Control` + `⌥ Option` + `⌘ Command` | Resize the window under the pointer |

Press and hold the click (a normal click on the trackpad) while holding the
keys to snap to the grid. Releasing it drops the window where it snapped and
ends the move or resize: release the keys and press them again to start
another one.

Release the keys to stop. The combination must match exactly, and both can be
changed (or disabled) in the settings, which warn about combinations that
can't work well (the same keys for both, or a single key held for ordinary
shortcuts). Since the resize keys include the move
keys, adding `⌘` while moving switches to resizing, and releasing it switches
back.

- **Moving** keeps the window at the same spot under the pointer.
- **Resizing** pulls the corner nearest the pointer, so you can grow or shrink
  a window from any side. It can also be set to always use the bottom-right
  corner.
- Fullscreen and minimized windows are left alone.

### Snapping

Window edges snap to screen edges (minus the
menu bar and the Dock) and to the edges of neighbouring windows when they
come within 16 points. The distance is configurable, and `0` turns snapping
off.

### Grid

Each display is divided into a grid of columns and rows. While you hold the
click, moved and resized edges always land on a grid line; the click itself
doesn't reach the app under the pointer. The grid follows the display under
the pointer, and its lines are shown while you hold the click, with the other
windows dimmed. Windows stacked above the one you are moving stay bright, so
turn on "Raise window" if you want everything else dimmed.

Each display has its own grid size, e.g. 2 × 2 on the laptop screen and
8 × 4 on an ultrawide monitor. A display seen for the first time gets a grid
suiting its size: 2 × 2 for 13–14″ laptops, 3 × 2 for 15–16″ laptops and
1080p, 4 × 3 for larger displays, 8 × 4 for ultrawides and 2 × 3 for
portrait displays.

Grids are remembered per physical display, so plugging the laptop into your
monitors at home or at the office brings their grids back. In the settings,
**Preview Grid** briefly draws a display's grid on it to tell displays apart,
and displays that aren't plugged in are listed under **Unplugged Displays**,
where they can be forgotten.

### Sending a window to another display

While holding the move keys over a window:

- **Swipe two fingers** on a trackpad or a Magic Mouse toward another
  display: the window goes to the display in that direction, following the
  arrangement in System Settings → Displays. One swipe moves it once.
- **Scroll the mouse wheel**: the window goes to the next or previous
  display, left to right.
- **Press an arrow key**: the window goes to the display in that direction.

The window keeps its relative place and size (a window on the left half of
the laptop screen lands on the left half of the monitor), fits the grid of
that display if you hold the click, and the pointer goes with it, so you can
keep moving it. Swipes, scrolls and arrow keys used this way don't reach the
app under the pointer. Both can be turned off in the settings.

### Window sizes per display

Each display remembers where each app's windows last were on it. A window
sent to a display, or dragged onto it, gets that size and place back: for
example Safari half the laptop screen and a third of the office monitor.
Sizes are remembered when you move or resize a window with Souris facile
pomme, and when a window leaves a display. macOS gives windows no ID that
survives an app restart, so this is per app: an app's windows share the same
remembered size on a display. It can be turned off, and the remembered sizes
forgotten, in the settings.

If Accessibility Zoom is set to zoom with a scroll gesture and the Control
key, it may react to the same swipes: pick another modifier for it in System
Settings → Accessibility → Zoom.

## Menu bar

Souris facile pomme has no Dock icon: everything is in the mouse icon in the menu
bar.

- **About Souris facile pomme**: version and project page.
- **Enabled**: turns moving and resizing on or off.
- **Grant Accessibility Access…**: shown until access is granted.
- **Settings…** (`⌘,`)
- **Quit Souris facile pomme** (`⌘Q`)

## Settings

Click the mouse icon in the menu bar, then **Settings…**. The sidebar has a
page per topic, then one per connected display, and **Unplugged Displays**
when some are remembered.

| Page            | Setting                         | Default         |
| --------------- | ------------------------------- | --------------- |
| General         | Enabled                         | On              |
|                 | Launch at login                 | Off             |
|                 | Raise window                    | Off             |
| Move            | Keys                            | `⌃` + `⌥`       |
| Resize          | Keys                            | `⌃` + `⌥` + `⌘` |
|                 | Resize from nearest corner      | On              |
| Snapping        | Snap distance                   | 16 pt           |
|                 | Snap to other windows           | On              |
|                 | Show grid                       | On              |
|                 | Dim other windows               | On              |
| Send to Display | Swipe or scroll                 | On              |
|                 | Arrow keys                      | On              |
|                 | Remember window sizes           | On              |
| Each display    | Grid size                       | Suits the display |
|                 | Remembered window sizes, forget |                 |

## Building

Requires macOS 13 or later and Xcode (or the Xcode command line tools).

```sh
make app       # universal (Apple Silicon + Intel) build in "build/Souris facile pomme.app"
make run       # build and launch
make install   # copy to /Applications
make test      # run the unit tests
```

On first launch, macOS asks to grant Souris facile pomme **Accessibility** access
(System Settings → Privacy & Security → Accessibility). It's needed to see the
keys you hold and to move other apps' windows. The app notices when access is
granted, so there's no need to relaunch it.

The app is signed ad hoc by default, so macOS treats every rebuild as a new
app: after rebuilding, remove Souris facile pomme from the Accessibility list and
add it again. Signing with a stable identity avoids that:

```sh
make app SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"
```

To open the project in Xcode, run `open Package.swift`.

### Releasing

`make release` builds `build/SourisFacilePomme-<version>.zip`, with the version
taken from `Resources/Info.plist`. To share it beyond your own Macs, sign
with a Developer ID and have Apple notarize it, after saving your notary
credentials once with `xcrun notarytool store-credentials souris-facile-pomme`:

```sh
make notarize SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"
```

## License

GPL-2.0-or-later, see [LICENSE](LICENSE).
