import 'dart:io' show File;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;

import 'vendor/desktop_drop.dart' show DropItem, DropItemDirectory;

// The widget API and drop item model come from the vendored engine:
// DropTarget (drag-enter/exit/updated/done callbacks), DropItem / DropItemFile /
// DropItemDirectory, DropDoneDetails and DropEventDetails.
export 'vendor/desktop_drop.dart'
    show
        DropTarget,
        DropItem,
        DropItemFile,
        DropItemDirectory,
        DropDoneDetails,
        DropEventDetails;

/// Drag & drop of files and images from the OS into the app.
///
/// The widget side of this API is [DropTarget] (re-exported from this
/// library). Wrap any widget in a [DropTarget] to receive drag-enter,
/// drag-exit, drag-update and drop callbacks for OS-level drags — anything
/// that can produce file URIs or file lists: file managers, browsers,
/// terminals, image editors.
///
/// [DesktopDropX] provides the ergonomics the app needs on top of the raw
/// [DropItem] list delivered by [DropDoneDetails.files]: extracting plain
/// file paths and loading the first image among the dropped items.
///
/// Platform behavior:
/// - **Linux**: the native side installs a GTK drag destination on the whole
///   Flutter window and delivers `text/uri-list` (GNOME/KDE file managers,
///   browsers, etc.). Dropped items are absolute filesystem paths.
/// - **Windows**: the native side registers an OLE `IDropTarget` on the
///   window and reads `CF_HDROP`, so drops work from Explorer and any
///   browser. Dropped items are absolute filesystem paths.
/// - **Android/iOS**: not implemented — this package does not vendor the
///   desktop_drop mobile bindings. [DropTarget] compiles and renders its
///   child, but no native handler answers the channel, so no drop events
///   ever arrive.
/// - **macOS**: not vendored (no macOS target in the app); re-adding it is
///   a copy of upstream's `macos/` folder behind the same API.
///
/// Errors: nothing here throws. A drop that contains no readable image is an
/// expected outcome (returns `null`), and file reads that fail (stale drop,
/// permissions) are logged with a stack trace and skipped.
class DesktopDropX {
  DesktopDropX._();

  /// Returns one filesystem path per top-level dropped item.
  ///
  /// Each item in [items] maps to its path — files and directories alike; a
  /// dropped folder yields its own path, its contents are not expanded
  /// ([DropItemDirectory.children] is only populated on macOS, which is not
  /// vendored). Items that carry no path (web data drops) yield `''`.
  ///
  /// Pass [DropDoneDetails.files] from a drop callback to get the paths the
  /// app can hand to file I/O:
  ///
  /// ```dart
  /// DropTarget(
  ///   onDragDone: (details) {
  ///     final paths = DesktopDropX.pathsOf(details.files);
  ///     // read, copy, upload…
  ///   },
  ///   child: …,
  /// )
  /// ```
  static List<String> pathsOf(List<DropItem> items) =>
      items.map((item) => item.path).toList();

  /// Reads the first image among [items] and returns its bytes.
  ///
  /// Resolution order follows [items]: for each item the first 16 bytes are
  /// sniffed for image magic bytes (PNG/JPEG/GIF/WebP/BMP — same table as
  /// `ClipboardX.pasteImage`); the first match is loaded in full. Huge
  /// non-image files are never fully read. Returns `null` when none of the
  /// dropped items is an image, or when none could be read.
  ///
  /// Directories are skipped ([DropItemDirectory] carries no file bytes).
  /// Files that fail to open or read (deleted between drop and read,
  /// permission denied) are logged with a stack trace and skipped — a later
  /// item is still tried, and the method returns `null` only if nothing
  /// readable remains.
  ///
  /// The returned bytes are as-dropped (no re-encode); use the bytes with
  /// `Image.memory` or upload them as-is.
  ///
  /// ```dart
  /// DropTarget(
  ///   onDragDone: (details) async {
  ///     final Uint8List? bytes = await DesktopDropX.readImage(details.files);
  ///     if (bytes == null) return; // drop contained no image
  ///     // display or upload
  ///   },
  ///   child: …,
  /// )
  /// ```
  static Future<Uint8List?> readImage(List<DropItem> items) async {
    for (final item in items) {
      if (item is DropItemDirectory) continue;
      final path = item.path;
      if (path.isEmpty) continue;
      final head = await _readHead(path);
      if (head == null || !_looksLikeImage(head)) continue;
      try {
        final bytes = await item.readAsBytes();
        if (bytes == null || !_looksLikeImage(bytes)) continue;
        return bytes;
      } on Exception catch (e, st) {
        debugPrint(
            'DesktopDropX.readImage: failed reading ${item.path}: $e\n$st');
      }
    }
    return null;
  }

  static Future<Uint8List?> _readHead(String path) async {
    try {
      final raf = File(path).openSync();
      final head = raf.readSync(16);
      raf.closeSync();
      return head;
    } on Exception catch (e, st) {
      debugPrint('DesktopDropX.readImage: could not read $path: $e\n$st');
      return null;
    }
  }

  /// Sniffs common image magic bytes (PNG/JPEG/GIF/WebP/BMP).
  ///
  /// Shares the table used by `ClipboardX._looksLikeImage`; kept as a local
  /// copy so the two APIs stay independent.
  static bool _looksLikeImage(Uint8List b) {
    if (b.length < 4) return false;
    if (b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF) return true; // jpeg
    if (b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47) return true; // png
    if (b[0] == 0x47 && b[1] == 0x49 && b[2] == 0x46 && b[3] == 0x38) return true; // gif
    if (b.length >= 12 &&
        b[0] == 'R' && b[1] == 'I' && b[2] == 'F' && b[3] == 'F' &&
        b[4] == 'W' && b[5] == 'E' && b[6] == 'B' && b[7] == 'P') {
      return true; // webp
    }
    if (b[0] == 'B' && b[1] == 'M') return true; // bmp
    return false;
  }
}