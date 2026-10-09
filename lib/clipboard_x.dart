import 'dart:io' show Directory, File, Platform;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'vendor/pasteboard.dart';

/// Thrown when a clipboard copy fails.
class ClipboardCopyException implements Exception {
  ClipboardCopyException(this.message);

  final String message;

  @override
  String toString() => 'ClipboardCopyException: $message';
}

/// Cross-project clipboard wrapper over the vendored pasteboard engine.
///
/// Text goes through Flutter's built-in clipboard; images and files go
/// through the native channels (Android: FileProvider-served content URIs,
/// Windows: GDI+/CF_HDROP, Linux: GTK).
class ClipboardX {
  ClipboardX._();

  static const MethodChannel _clipboardChannel = MethodChannel('fox_utils/clipboard');

  /// Copies [bytes] to the clipboard as an image. The bytes are placed as-is
  /// (no re-encode) and the extension is sniffed from the magic bytes, so
  /// PNG/JPEG/GIF/WebP/BMP all paste with the correct MIME type.
  ///
  /// Supported on Android, Windows, macOS and iOS. On Linux, raw image bytes
  /// cannot be placed on the clipboard (GTK limitation), so the bytes are
  /// staged to a temp file and copied as a file reference instead — pasted
  /// apps receive the image file.
  ///
  /// Throws [ClipboardCopyException] on failure (e.g. invalid image bytes
  /// rejected by the platform).
  static Future<void> copyImage(Uint8List bytes) async {
    if (Platform.isLinux) {
      await copyFiles([await _stageLinuxImage(bytes)]);
      return;
    }
    await Pasteboard.writeImage(bytes);
  }

  static File? _linuxStaged;

  /// Stages [bytes] to a rotating temp file. Linux clipboards hold file
  /// references that receivers resolve at paste time, so the staged file must
  /// outlive the copy call; the previous staging file is replaced on each
  /// copy.
  static Future<String> _stageLinuxImage(Uint8List bytes) async {
    final file = File('${Directory.systemTemp.path}/fox_clipboard_image.png');
    await file.writeAsBytes(bytes);
    final old = _linuxStaged;
    if (old != null && old.path != file.path) {
      try {
        await old.delete();
      } on Exception catch (e, st) {
        // Stale staging file is harmless; log and move on.
        debugPrint('Failed to delete stale clipboard staging file: $e\n$st');
      }
    }
    _linuxStaged = file;
    return file.path;
  }

  /// Copies [paths] (absolute file paths) to the clipboard as files.
  ///
  /// Throws [ClipboardCopyException] when the native write fails or reports
  /// failure (pasteboard's `writeFiles` returns a bool that is converted to
  /// an exception here).
  static Future<void> copyFiles(List<String> paths) async {
    final ok = await Pasteboard.writeFiles(paths);
    if (!ok) {
      throw ClipboardCopyException('Failed to copy files: $paths');
    }
  }

  /// Copies [text] to the clipboard.
  static void copyText(String text) => Pasteboard.writeText(text);

  static Future<String?> readText() => Pasteboard.text;

  static Future<Uint8List?> readImage() => Pasteboard.image;

  static Future<List<String>> readFiles() => Pasteboard.files();

  /// Reads an image from the clipboard regardless of how it was copied:
  /// image data (a browser's "copy image") or a file reference (a file
  /// manager's copy). Returns the image bytes, or null when the clipboard
  /// holds no image.
  ///
  /// Resolution order:
  /// 1. image data on the clipboard (browser copy) — all platforms;
  /// 2. the first file reference (file manager copy) — desktop paths are
  ///    read directly, Android content URIs are resolved via the platform
  ///    channel. The file's first bytes are sniffed to confirm an image
  ///    before the full read, so huge non-image files are never loaded.
  static Future<Uint8List?> pasteImage() async {
    final image = await readImage();
    if (image != null) return image;

    final files = await readFiles();
    if (files.isEmpty) return null;

    final Uint8List? bytes;
    if (Platform.isAndroid) {
      bytes = await _readFileBytes(files.first);
    } else {
      final file = File(files.first);
      try {
        final raf = file.openSync();
        final head = raf.readSync(16);
        raf.closeSync();
        if (!_looksLikeImage(head)) return null;
        bytes = await file.readAsBytes();
      } on Exception catch (e, st) {
        debugPrint('pasteImage: could not read clipboard file ${file.path}: $e\n$st');
        return null;
      }
    }
    if (bytes == null || !_looksLikeImage(bytes)) return null;
    return bytes;
  }

  static Future<Uint8List?> _readFileBytes(String uri) async {
    try {
      return await _clipboardChannel.invokeMethod<Uint8List>('readFileBytes', uri);
    } on PlatformException catch (e, st) {
      debugPrint('pasteImage: failed to read $uri: ${e.message}\n$st');
      return null;
    }
  }

  /// Sniffs common image magic bytes (PNG/JPEG/GIF/WebP/BMP).
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
