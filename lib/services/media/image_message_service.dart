import 'dart:convert';
import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class ImageMessageService {
  final _picker = ImagePicker();
  final _uuid = const Uuid();

  Future<String?> pickAndSave({required ImageSource source}) async {
    final file = await _picker.pickImage(
      source: source,
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 75,
    );
    if (file == null) return null;

    final bytes = await file.readAsBytes();
    if (bytes.length > 2 * 1024 * 1024) return null;

    final dir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory(p.join(dir.path, 'chat_images'));
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }

    final name = '${_uuid.v4()}.jpg';
    final saved = File(p.join(imagesDir.path, name));
    await saved.writeAsBytes(bytes);
    return saved.path;
  }

  Future<String?> saveIncomingBase64(String base64Data) async {
    try {
      final bytes = base64Decode(base64Data);
      final dir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory(p.join(dir.path, 'chat_images'));
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }
      final name = '${_uuid.v4()}.jpg';
      final saved = File(p.join(imagesDir.path, name));
      await saved.writeAsBytes(bytes);
      return saved.path;
    } catch (_) {
      return null;
    }
  }

  Future<String?> readAsBase64(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) return null;
      return base64Encode(await file.readAsBytes());
    } catch (_) {
      return null;
    }
  }
}
