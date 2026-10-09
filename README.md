# fox_utils

Reusable Flutter utilities shared across projects: permission-free Android
file saving, a cross-platform clipboard wrapper, and desktop drag & drop.

## Features

### `AndroidFiles.save` — save files to public Android storage

Writes any bytes to a public Android directory (`Pictures`, `Movies`,
`Music`, `Download`) **without any storage permission**, with an optional
media scan so the file shows up in gallery apps.

```dart
final path = await AndroidFiles.save(
  bytes,                                   // any file type
  fileName: 'image.jpg',
  location: AndroidPublicLocation.pictures, // pictures | movies | music | downloads
  subPath: 'Imagen',                       // folder structure under the location
  scan: true,                              // false = saved but not indexed (no gallery)
);
```

Notes:

- Requires **no permissions** on Android 10+ (API 29+): creating new files
  inside media collections is permission-free. Legacy devices (< API 29) may
  fail — the exception carries the native message.
- `scan: false` writes the file without indexing it. On modern Android the
  file can still be picked up by a later system rescan; for a hard
  "never in gallery" guarantee, save outside a media collection or add a
  `.nomedia` file to the folder.
- Throws `FileSaveException` on failure (logged with stack trace).

### `ClipboardX` — clipboard copy

```dart
await ClipboardX.copyImage(bytes);              // image bytes as-is, MIME sniffed
await ClipboardX.copyFiles(['/path/a.png']);    // desktop: files
ClipboardX.copyText('hello');                   // text (Flutter built-in)
final text = await ClipboardX.readText();
final image = await ClipboardX.readImage();
final files = await ClipboardX.readFiles();
```

Platform matrix:

| Operation | Android | Windows | Linux | macOS | iOS |
|---|---|---|---|---|---|
| copy image | ✓ (FileProvider) | ✓ (GDI+) | ✓ (file reference) | ✓ | ✓ |
| copy files | – | ✓ (CF_HDROP) | ✓ (GNOME) | ✓ | – |
| copy/read text | ✓ | ✓ | ✓ | ✓ | ✓ |
| read image | ✓ | ✓ | ✓ | ✓ | ✓ |
| read files | ✓ (URIs) | ✓ | ✓ | ✓ | – |

Notes:

- Image bytes are placed **as-is** (no re-encode); the extension is sniffed
  from magic bytes (PNG/JPEG/GIF/WebP/BMP), so animated GIFs survive.
- **Linux cannot hold raw image bytes** on the clipboard (GTK limitation), so
  `copyImage` stages the bytes to a rotating temp file and copies it as a
  file reference — pasted apps receive the image file. The staging file is
  replaced on each copy.
- **Android requires no manifest setup**: the FileProvider is declared in
  this plugin's manifest and merged automatically (`${applicationId}.provider`).
  Images are staged in the app cache dir.
- Throws `ClipboardCopyException` on failure.

### `ClipboardX.pasteImage` — paste an image, whatever the source

```dart
final Uint8List? image = await ClipboardX.pasteImage();
if (image != null) {
  // send to server, display, whatever
}
```

Resolution order: image data on the clipboard first (browser "copy image"),
then the first file reference (file manager "copy"). The file's first bytes
are sniffed (PNG/JPEG/GIF/WebP/BMP) before the full read, so huge non-image
files are never loaded. Returns `null` when the clipboard holds no image.

Source matrix:

| Copied from | Windows | Linux | Android |
|---|---|---|---|
| Browser, "copy image" | CF_DIB → image bytes | `image/png` → image bytes | content URI (image mime) → image bytes |
| File manager, "copy" | CF_HDROP → first file's bytes | `text/uri-list` → first file's bytes | content URI → resolved bytes |

Android notes:

- Reading the clipboard works **only while the app is in the foreground**
  (Android 10+); background reads return `null`.
- Android 12+ shows a system toast ("app pasted from your clipboard") on
  read — cosmetic.
- File references come back as `content://` URIs; `pasteImage` resolves them
  through the platform channel (`readFileBytes`), so no manifest setup or
  permission is needed.

### `DesktopDropX` + `DropTarget` — drag & drop files and images

OS-level drag & drop into the app (desktop only). Wrap any widget in
`DropTarget` to get drag enter/exit/update/drop callbacks; `DesktopDropX`
turns the dropped items into plain paths or image bytes:

```dart
DropTarget(
  onDragEntered: (d) => setState(() => dragging = true),
  onDragExited: (d) => setState(() => dragging = false),
  onDragDone: (details) async {
    final paths = DesktopDropX.pathsOf(details.files);   // absolute paths
    final Uint8List? image = await DesktopDropX.readImage(details.files);
    // image == null when the drop contains no readable image
  },
  child: myWidget,
)
```

Platform notes:

- **Linux**: GTK drag destination on the whole window (`text/uri-list` from
  GNOME/KDE file managers, browsers, …). Items are absolute paths, delivered
  in the order dropped.
- **Windows**: OLE `IDropTarget` on the window (`CF_HDROP` from Explorer,
  browsers, …). Same path semantics; `DropDoneDetails.localPosition` is
  already DPI-corrected.
- **Android/iOS/web**: no native handler — the widget renders its child and
  no drop events ever arrive. **macOS** is not vendored (no macOS target);
  re-adding it is a copy of upstream's `macos/` folder behind the same API.
- `DropItem` extends `XFile`: `item.path`, `item.name`, `item.readAsBytes()`,
  `item.openRead()`, … are available directly.
- Drop targets receive events for the **whole window**; an invisible
  `DropTarget` keeps receiving them, so set `enable: false` when pushing a
  page over it. Coordinate-based `DropTarget` bounds filtering is handled by
  the widget.
- `readImage` never throws: unreadable files are logged with a stack trace
  and skipped; `null` means "no image in this drop".

### media_kit hot-restart guard (Linux, debug)

Apps using media_kit crash on a hot restart (`R`) while any `Player` is
alive: mpv calls a wakeup callback that belonged to the discarded isolate.
fox_utils' Linux plugin clears those callbacks just before the engine
restarts, so hot restart works. Nothing to call; release builds compile it
out; it does nothing without media_kit. It reads media_kit's private
NativeReferenceHolder file (checked against media_kit 1.2.6): re-check after
media_kit upgrades.

## Vendored engines

The clipboard channels (`pasteboard` method channel) are **vendored from
MixinNetwork's `pasteboard` package (v0.5.0, Apache-2.0)** because upstream's
build applies the legacy Kotlin Gradle Plugin (KGP), which future Flutter
versions will reject. The vendored copy lives in `lib/vendor/` (Dart) and the
native platform folders, with these changes:

- **Android**: the Kotlin plugin was ported to Java and merged into
  `FoxUtilsPlugin` (one plugin class, no KGP, no Kotlin in the module).
- **Byte-faithful image writes**: upstream decodes and re-encodes images as
  PNG (destroying GIF animation and metadata); ours writes the original bytes
  with magic-byte MIME sniffing.
- **Merged FileProvider**: declared in the plugin manifest — zero per-project
  setup (upstream requires a manual manifest entry per app).
- **Two upstream bugs fixed**: clipboard image reads ran synchronously on the
  calling thread (now on the executor), and `writeFiles` dropped the first
  clip item (now assembles correctly).
- **Linux/Windows**: C++ sources byte-identical, include paths and CMake
  targets renamed to the `fox_utils` package name.

To diff against upstream: `git diff` the folders against
`packages/pasteboard/` at tag `v0.5.0` of
`https://github.com/MixinNetwork/flutter-plugins`. If upstream ever
modernizes their build, un-vendoring is a swap behind the same `ClipboardX`
API.

The drag & drop channels (`desktop_drop` method channel) are **vendored from
MixinNetwork's `desktop_drop` package (v0.7.1, Apache-2.0)** for the same
reason: its `android/` folder applies KGP. Only the Dart sources and the
Linux/Windows native folders are vendored — the Android/Kotlin, macOS and
web bindings are omitted (Android DnD is out of scope, and there is no macOS
target in the app). Linux/Windows native sources are byte-identical to
upstream except the include path rename (`include/fox_utils/`). Both engines
are registered from one native entry per platform:
`fox_utils_plugin_register_with_registrar` (Linux) /
`FoxUtilsPluginRegisterWithRegistrar` (Windows) — the plugin class in
`pubspec.yaml` is no longer `PasteboardPlugin`. To diff against upstream, use
tag `desktop_drop-v0.7.1` of the same monorepo; un-vendoring is a swap
behind the same `DesktopDropX` API.

## License

MIT for this package's own code; the vendored engines are Apache-2.0
© MixinNetwork (see `lib/vendor/` and the native platform folders).
