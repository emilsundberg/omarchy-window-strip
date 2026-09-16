# Window Strip for Omarchy

A compact window switcher with large application icons and a single
window-title line. Each window gets its own entry, including multiple windows
from the same app.

- Hold **Ctrl** and tap **Tab** to cycle through recently used windows.
- Press **Ctrl+Shift+Tab** to go backward.
- Release **Ctrl** to activate the selected window.
- Press **Ctrl+Escape** to cancel.

The strip follows your Omarchy theme, has no dimmed backdrop, and disables its
own compositor fade animation. Installed icon files provide a fallback when
Qt cannot resolve an application's icon through the icon theme.

Windows from all regular workspaces and monitors are included. Special and
scratchpad workspaces are excluded. Focus changes only when you release Ctrl.

## Requirements

- Omarchy Quattro with Omarchy Shell and its plugin system.
- Hyprland 0.56 or newer, configured in Lua.
- The Bash and find utilities included with Omarchy.

## Install

```bash
omarchy plugin add https://github.com/emilsundberg/omarchy-window-strip.git --enable
```

Add this line to `~/.config/hypr/bindings.lua`:

```lua
dofile(os.getenv("HOME") .. "/.config/omarchy/plugins/emil.altswitch/altswitch.lua")
```

Then reload Hyprland:

```bash
hyprctl reload
hyprctl configerrors
```

These bindings replace existing **Ctrl+Tab**, **Ctrl+Shift+Tab**, and
**Ctrl+Escape** bindings. Ctrl+Tab will switch windows instead of tabs inside
applications. Alt+Tab is unchanged.

If migrating from the original `omarchy-altswitch`, remove its `dofile` line
from your Hyprland configuration and disable its panel:

```bash
omarchy plugin disable io.github.pablo-merino.altswitch
```

Load only one copy of this plugin's keyboard script. If you previously kept a
copy in `~/.config/hypr/altswitch.lua`, replace that old `dofile` line with the
installation line above.

## Web-app names and icons

A web app needs a desktop launcher that matches its window class. If it displays
a browser-generated name or a letter, find its class with `hyprctl clients`
and add a matching `StartupWMClass` to its launcher under
`~/.local/share/applications/`.

For example, a Basecamp launcher opened through the 37signals launchpad can use:

```ini
Name=Basecamp
Icon=basecamp
StartupWMClass=chrome-launchpad.37signals.com__-Default
```

Use your actual window class; it can differ with the launch URL or browser
profile. Keep the launcher's other fields intact. The icon must already be
installed or specified as an absolute file path. After editing the launcher:

```bash
update-desktop-database ~/.local/share/applications
omarchy restart shell
```

## Remove

Remove the plugin's `dofile` line from `~/.config/hypr/bindings.lua`, then run:

```bash
hyprctl reload
omarchy plugin remove emil.altswitch
```

Any earlier custom bindings that you removed must be restored separately.

## Development

The QML panel renders the window list; `altswitch.lua` handles window ordering,
key bindings, and modifier release inside Hyprland. A ten-second watchdog
closes an abandoned switcher.

```bash
lua tests/switcher.lua
luac -p altswitch.lua
```

The panel does not grab keyboard input. Unbound keys can reach the underlying
application while the strip is open. Window thumbnails are not included.

## Credits

Adapted from [Pablo Merino's Alt-tab switcher](https://github.com/Pablo-Merino/omarchy-altswitch)
(commit `8f54d684c89d66ecf51e6e5a9c5c574758de79be`), under the MIT license.
The icon-index fallback is adapted from
[Omarchy's AppLibrary](https://github.com/basecamp/omarchy/blob/master/shell/services/AppLibrary.qml).
See [LICENSE](LICENSE) and [OMARCHY-LICENSE](OMARCHY-LICENSE).
