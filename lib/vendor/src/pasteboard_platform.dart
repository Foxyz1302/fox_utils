// Modified from MixinNetwork's pasteboard v0.5.0 (Apache-2.0, Copyright Mixin Network; see LICENSE).
import 'dart:typed_data';

abstract class PasteboardPlatform {
  Future<Uint8List?> get image;

  Future<String?> get html;

  Future<void> writeImage(Uint8List? image);

  Future<List<String>> files();

  Future<bool> writeFiles(List<String> files);

  Future<String?> get text;

  void writeText(String value);
}
