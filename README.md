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

By default, window edges snap to screen edges (minus the menu bar and the
Dock) and to the edges of neighbouring windows when they come within 16
points. The distance is configurable, and `0` turns snapping off.

### Grid

Turn on the grid to divide each screen into columns and rows: moved and
resized edges then always land on a grid line. The grid follows the screen
under the pointer, and its lines can be shown while you move or resize, with
the other windows dimmed. Windows stacked above the one you are moving stay
bright, so turn on "Raise window" if you want everything else dimmed.

Each display can have its own grid size, e.g. 2 × 2 on the laptop screen and
6 × 2 on an ultrawide monitor. Displays without one use the default grid.
Sizes are remembered per physical display, so plugging the laptop into your
monitors at home or at the office brings their grids back. In the settings,
**Preview Grid** briefly draws a display's grid on it to tell displays apart,
and displays that aren't plugged in are listed under **Other Displays**, where
they can be forgotten.

## Menu bar

Souris facile pomme has no Dock icon: everything is in the mouse icon in the menu
bar.

- **About Souris facile pomme**: version and project page.
- **Enabled**: turns moving and resizing on or off.
- **Grant Accessibility Access…**: shown until access is granted.
- **Settings…** (`⌘,`)
- **Quit Souris facile pomme** (`⌘Q`)

## Settings

Click the mouse icon in the menu bar, then **Settings…**.

| Setting                    | Default                 |
| -------------------------- | ----------------------- |
| Move keys                  | `⌃` + `⌥`               |
| Resize keys                | `⌃` + `⌥` + `⌘`         |
| Raise window               | Off                     |
| Resize from nearest corner | On                      |
| Launch at login            | Off                     |
| Snap distance              | 16 pt                   |
| Snap to other windows      | On                      |
| Snap to grid               | Off (4 × 3)             |
| Grid size per display     | Default grid            |
| Show grid                  | On                      |
| Dim other windows          | On                      |

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
