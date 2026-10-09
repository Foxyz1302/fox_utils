import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// A public Android storage location that needs no write permission.
enum AndroidPublicLocation {
  pictures,
  movies,
  music,
  downloads,
}

/// Thrown when saving a file via [AndroidFiles.save] fails.
class FileSaveException implements Exception {
  FileSaveException(this.message, {this.details});

  final String message;
  final String? details;

  @override
  String toString() =>
      'FileSaveException: $message${details != null ? ' — $details' : ''}';
}

/// Saves files to public Android directories without any storage permission.
///
/// Files are written with plain file I/O, so on Android 10+ they are NOT
/// indexed by the media store. Pass [scan] = true to run the media scanner
/// and make the file show up in gallery apps.
class AndroidFiles {
  AndroidFiles._();

  static const MethodChannel _channel = MethodChannel('fox_utils/android_files');

  /// Writes [bytes] to `<location>/<subPath>/<fileName>` on shared storage and
  /// returns the absolute path. Requires no storage permission on Android 10+.
  ///
  /// When [scan] is true the file is indexed into the media store (gallery
  /// visibility); when false it stays on disk without being indexed.
  ///
  /// Throws [FileSaveException] on failure (invalid arguments, I/O error, or
  /// a platform rejection — e.g. pre-Android-10 devices without legacy
  /// storage access). The native error message is carried in the exception.
  static Future<String> save(
    Uint8List bytes, {
    required String fileName,
    AndroidPublicLocation location = AndroidPublicLocation.pictures,
    String subPath = '',
    bool scan = true,
  }) async {
    try {
      final path = await _channel.invokeMethod<String>('saveFile', {
        'bytes': bytes,
        'fileName': fileName,
        'location': location.name,
        'subPath': subPath,
        'scan': scan,
      });
      if (path == null) {
        throw FileSaveException('saveFile returned no path.');
      }
      return path;
    } on PlatformException catch (e, st) {
      debugPrint('AndroidFiles.save failed (${e.code}): ${e.message}\n$st');
      throw FileSaveException(e.message ?? 'Failed to save file.', details: e.code);
    }
  }
}
