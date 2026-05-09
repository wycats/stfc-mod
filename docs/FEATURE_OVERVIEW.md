# STFC Community Mod feature overview

This is a code-oriented map of the mod features and the source files that implement them. It complements the user-facing feature list in the README by naming the runtime systems, hooks, and configuration paths a developer is likely to inspect.

## Platform entry points

### macOS launcher and loader

The macOS flow is split into a Swift launcher and a small native loader:

- the launcher prepares and starts the game
- the loader sets up `DYLD_INSERT_LIBRARIES`
- the injected dylib loads `GameAssembly.dylib` and installs the mod hooks

Related code:

- `macos-launcher/src/`
- `macos-loader/src/main.cc`
- `macos-dylib/src/main.cc`
- `mods/src/patches/patches.cc`

### Windows proxy DLL

On Windows, the mod is loaded through a proxy `version.dll`.

Related code:

- `win-proxy-dll/src/`

## Runtime configuration and diagnostics

The mod creates and reads TOML configuration files, writes a parsed runtime config, and logs hook installation and diagnostics.

Main capabilities:

- create a default settings file when none exists
- write a parsed runtime config showing applied settings
- support custom filenames for config/log/runtime files on Windows
- migrate old macOS preference paths to the current `com.stfcmod.startrekpatch` location
- switch log levels with hotkeys
- enable or disable hook groups through config in `_MODDBG`/`releasedbg` builds

Related code:

- `mods/src/config.cc`
- `mods/src/defaultconfig.h`
- `mods/src/file.cc`
- `mods/src/patches/patches.cc`

## Graphics, scaling, and navigation

### UI scale

The mod can override the game UI scale and adjust it at runtime. It also has a separate scale override for the object viewer canvas.

Main capabilities:

- set base UI scale
- adjust UI scale with hotkeys
- set object viewer scale separately
- account for display scale on supported desktop platforms

Related code:

- `mods/src/patches/parts/ui_scale.cc`
- `mods/src/config.cc`

### System zoom

The mod expands and customizes system zoom behavior.

Main capabilities:

- set maximum system zoom
- set default system zoom
- set keyboard zoom speed
- use zoom presets 1-5
- save current zoom into presets
- zoom around the mouse position

Related code:

- `mods/src/patches/parts/zoom.cc`

### Pan behavior

The mod changes touch/mouse pan behavior and keeps system camera panning smoother after input stops.

Main capabilities:

- convert stationary touch events into movement when needed
- apply momentum falloff to navigation panning
- optionally disable movement-key panning behavior

Related code:

- `mods/src/patches/parts/fix_pan.cc`

### Windowing and display

Windows builds include window-management hooks for free resizing, borderless fullscreen, F11 fullscreen toggling, fullscreen resolution correction, title override, and cursor handling.

There is also a resolution-list hook intended to filter or expose resolutions. Runtime defaults disable it after the Unity 6 update, although the sample config may still enable it if copied directly.

Related code:

- `mods/src/patches/parts/free_resize.cc`
- `mods/src/patches/parts/misc.cc`
- `mods/src/patches/parts/testing.cc`
- `mods/src/config.cc`

## Hotkeys and game actions

The mod adds a broad hotkey layer for UI screens, ships, navigation, fleet actions, cargo panels, zoom, logging, and chat.

Main capabilities:

- enable community hotkeys or defer to Scopely hotkeys
- open common sections such as galaxy, system, station, research, officers, refinery, inventory, missions, events, dailies, exocomp, artifacts, away teams, settings, gifts, alliance, bookmarks, ships, and more
- select ships 1-8
- select current ship
- double-select an already selected ship within `select_timer` to locate/view it
- use Shift+ship selection to attempt Discovery towing
- recall, repair, or cancel warp
- perform primary and secondary target actions
- queue or clear queue actions when Kir'Shara queue is available
- open and focus chat
- switch chat channels
- toggle cargo panel modes
- change UI scale and viewer scale
- change zoom and zoom presets
- change runtime log level
- quit the game with a configured shortcut on Windows
- include experimental-gated alliance help, alliance armada, and lookup shortcuts
- include a commander shortcut, with a known code comment that it does not yet select the intended commander reliably

Related code:

- `mods/src/patches/parts/hotkeys.cc`
- `mods/src/patches/mapkey.cc`
- `mods/src/patches/key.cc`
- `mods/src/patches/gamefunctions.h`
- `KEYMAPPING.md`

## Cargo and object viewers

The mod improves the pre-scan/object-viewer workflow and can show cargo information automatically for several target types.

Main capabilities:

- show default cargo panel
- show player cargo
- show station cargo
- show hostile cargo
- show armada cargo
- toggle preview locate and recall behavior
- hide pre-scan/object viewers with Escape
- use a view hotkey to show or hide rewards/cargo details
- suppress Escape falling through to the game after mod viewer handling when configured

Related code:

- `mods/src/patches/parts/hotkeys.cc`
- `mods/src/patches/parts/object_tracker.cc`

## Chat

The mod adds chat-related hotkeys and optional chat filtering.

Main capabilities:

- open/focus full-screen chat with a hotkey
- open/focus side chat with hotkeys
- switch directly to global, alliance, or private chat
- optionally disable galaxy chat
- optionally disable veil/regional chat
- prevent disabled chat tabs from being selected
- keep the chat preview focused on alliance chat when filtered chats are disabled

The side-chat dock itself is a built-in game feature; the mod mainly provides hotkeys and filtering behavior around it.

Related code:

- `mods/src/patches/parts/hotkeys.cc`
- `mods/src/patches/parts/chat.cc`

## Toast and popup cleanup

The mod can suppress selected toast banners and reduce some unwanted UI interruptions.

Main capabilities:

- disable configured toast/banner types via `disabled_banner_types`
- parse a `disable_toast_banners` setting, though the active toast hook currently checks `disabled_banner_types` instead
- skip chest reveal sections
- dismiss golden reward screens with Escape or primary action
- exit sections when collecting gifts via the bundle action behavior
- contain disabled scaffolding for first-popup suppression; it has no user-visible effect in current code

Related code:

- `mods/src/patches/parts/disable_banners.cc`
- `mods/src/patches/parts/misc.cc`
- `mods/src/patches/parts/hotkeys.cc`

## Game config overrides

The mod can override selected game configuration URLs and queue availability checks. These hooks are installed through the `TestPatches` hook group despite the name.

Main capabilities:

- override the platform settings URL
- override the asset URL
- allow config to disable the action queue availability check
- control Unity cursor behavior on Windows

Related code:

- `mods/src/patches/parts/testing.cc`
- `mods/src/config.cc`
- `mods/src/defaultconfig.h`

## Alliance donation slider

On Windows, the mod can extend the alliance donation slider maximum.

Main capabilities:

- set a larger donation slider maximum
- configure the maximum value

Related code:

- `mods/src/patches/parts/misc.cc`

## Buff behavior fix

The mod can make station-only buffs apply while out of dock by overriding the relevant buff condition check.

Main capabilities:

- treat `CondSelfAtStation` as not blocking out-of-dock power
- controlled by `use_out_of_dock_power`

Related code:

- `mods/src/patches/parts/buff_fixes.cc`

## Loading screen background replacement

The mod can replace loading and login screen backgrounds with either a configured image or an embedded fallback image.

Main capabilities:

- replace transition/loading screen backgrounds
- replace login screen backgrounds
- use a custom configured image path
- fall back to an embedded loading image
- re-apply background sprites as loading assets change
- skip CanvasController fade hooks on macOS; non-macOS still installs those fade hooks

Related code:

- `mods/src/patches/parts/loading_screen_bg.cc`
- `mods/src/patches/parts/embedded_loading_image.h`

## Responsiveness tweaks

The mod adjusts transition timing to make the UI feel faster.

Main capabilities:

- configure transition time
- shorten loading-screen blur transition timing

Related code:

- `mods/src/patches/parts/improve_responsiveness.cc`

## Data sync and export

The sync system observes game API responses and emits normalized data to configured HTTP targets.

Main capabilities:

- send sync payloads to one or more configured targets
- configure per-target token, proxy, TLS verification, and enabled data types
- queue sync work onto worker threads per target
- preserve a small local cache of sent battle logs to avoid repeats
- retrieve additional Scopely data when needed for enrichment
- enrich battle logs with Scopely journal, player, and alliance data
- emit delta/removal-style updates for completed jobs, active/completed missions, expired buffs, and slot changes
- support logging/debug output for sync activity
- treat legacy file sync output as removed/deprecated; current sync targets are HTTP endpoints

Data categories include:

- battle logs
- buffs
- buildings/starbase modules
- inventory
- jobs
- missions
- officers
- research
- resources
- ships
- slots
- forbidden tech
- officer traits
- Emerald Chain / alliance game properties

Related code:

- `mods/src/patches/parts/sync.cc`
- `mods/src/config.h`
- `mods/src/config.cc`

## Object tracking infrastructure

Several hotkey and viewer features need access to live Unity objects. The mod tracks selected object instances and removes them when they are destroyed or collected by the GC.

Tracked object types include:

- pre-scan target widgets
- fleet bar view controller
- armada/celestial/mining/housing/mission/starbase/star-node viewers
- full-screen chat controller
- navigation interaction controller
- reward screen controller

Related code:

- `mods/src/patches/parts/object_tracker.cc`

## Temporary crash fixes and defensive hooks

The mod includes defensive hooks for game-client crash avoidance and stale/invalid data handling.

Main capabilities:

- guard buff extraction from null list entries
- skip reveal sequences when configured
- retain scaffolding for action-queue and popup experiments

Related code:

- `mods/src/patches/parts/misc.cc`

## macOS-specific support

The macOS support layer includes launcher entitlements, loader injection, update handling, and local packaging helpers.

Main capabilities:

- open or create the macOS settings TOML
- detect installed game version and available Xsolla updates
- download, extract, and apply game updates using Xsolla metadata, 7z extraction, and rsync patches
- package a local app bundle matching the CI layout
- sign the launcher, loader, and dylib for local use
- verify and apply required loader entitlements to the game executable
- handle unsigned game executables by signing a temporary executable copy before replacement
- detect macOS display scale for UI scaling

Related code:

- `scripts/mac-build-test-debug.sh`
- `scripts/create-mac-dmg.sh`
- `macos-launcher/src/PatchEntitlements.swift`
- `macos-loader/src/main.cc`
- `mods/src/config.cc`
- `mods/xmake.lua`

## Known inactive or partial paths

Some parsed settings and code paths are not fully active user-facing features in the current code:

- `disable_first_popup` is parsed and a hook exists, but the hook condition is explicitly disabled.
- `disable_toast_banners` is parsed, but the active toast hook currently checks `disabled_banner_types`.
- `system_pan_momentum` is parsed behind `enable_experimental`, but the active pan hook uses `system_pan_momentum_falloff`.
- movement-key defaults exist, but movement-key shortcut parsing is currently commented out; `disable_move_keys` only controls whether the original pan update runs.
- native Linux injection is not present; Linux installation docs describe running the Windows build under Wine.
