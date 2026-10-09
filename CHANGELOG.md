## 0.1.8

* Linux, debug builds only: a Flutter hot restart no longer crashes apps that
  use media_kit with live players. Hot restart frees the old isolate's
  NativeCallables while the mpv handles live on; media_kit then sends the
  leftovers "quit" and mpv calls a dead wakeup callback (SIGSEGV on mpv's
  "core" thread). The plugin clears every live handle's wakeup callback on
  the engine's `on-pre-engine-restart` signal (handles found through
  media_kit's NativeReferenceHolder file). Automatic: depending on fox_utils
  is enough. Relies on media_kit internals (checked against 1.2.6).

## 0.1.7

* Add `DesktopDropX` + `DropTarget` — OS-level drag & drop of files and
  images into the app, powered by a vendored desktop_drop engine (v0.7.1,
  Apache-2.0): GTK uri-list drag destination on Linux, OLE `IDropTarget`
  (`CF_HDROP`) on Windows, dead code on mobile and web. `DesktopDropX`
  provides `pathsOf` (dropped file paths) and `readImage` (magic-byte
  image sniffing, same table as `ClipboardX.pasteImage`).
* The Linux/Windows plugin entry is now a combined `FoxUtilsPlugin`
  registration that wires the vendored pasteboard and desktop_drop engines
  from one native entry per platform (the registered plugin class changed
  from `PasteboardPlugin` to `FoxUtilsPlugin` — generated registrants
  regenerate on the next build).
* New dependencies: `cross_file` (drop items are `XFile`s) and
  `universal_platform` (web-safe platform checks), both required by the
  vendored engine.

## 0.1.6

* Add `ClipboardX.pasteImage` — reads an image from the clipboard whether it
  was copied as image data (browser) or as a file reference (file manager),
  on Windows, Linux and Android. Adds a `readFileBytes` channel method for
  resolving Android content URIs.

## 0.1.5

* Add `ClipboardX` — clipboard image/files/text copy via a vendored
  pasteboard engine (MixinNetwork, Apache-2.0) with modernized builds:
  the Android channel is Java (no KGP), the FileProvider is merged from
  the plugin manifest (zero per-project setup), image writes are byte-faithful
  with magic-byte MIME sniffing, and two upstream bugs are fixed.

## 0.1.4

* Add `AndroidFiles.save` — permission-free file saving to public Android
  directories (Pictures/Movies/Music/Download) with an optional media scan.
  Android platform channel, no storage permissions required.

## 0.0.1

* TODO: Describe initial release.