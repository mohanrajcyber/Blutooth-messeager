import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

class MediaService {
  MediaService() : _recorder = AudioRecorder();

  final ImagePicker _picker = ImagePicker();
  final AudioRecorder _recorder;
  final _uuid = const Uuid();
  String? _recordingPath;

  Future<String?> pickImage(ImageSource source) async =>
      _pickAndSave(source: source, maxWidth: 1280);

  Future<String?> pickVideo() async {
    final file = await _picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(seconds: 30),
    );
    if (file == null) return null;
    return _saveFile(await file.readAsBytes(), '.mp4');
  }

  Future<String?> pickDocument() async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.single.path == null) return null;
    final src = File(result.files.single.path!);
    final bytes = await src.readAsBytes();
    if (bytes.length > 5 * 1024 * 1024) return null;
    final ext = p.extension(src.path);
    return _saveFile(bytes, ext.isEmpty ? '.bin' : ext);
  }

  Future<String?> _pickAndSave({
    required ImageSource source,
    required double maxWidth,
  }) async {
    final file = await _picker.pickImage(
      source: source,
      maxWidth: maxWidth,
      imageQuality: 75,
    );
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    if (bytes.length > 2 * 1024 * 1024) return null;
    return _saveFile(bytes, '.jpg');
  }

  Future<String?> _saveFile(List<int> bytes, String ext) async {
    final dir = await _mediaDir();
    final name = '${_uuid.v4()}$ext';
    final saved = File(p.join(dir.path, name));
    await saved.writeAsBytes(bytes);
    return saved.path;
  }

  Future<Directory> _mediaDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final media = Directory(p.join(dir.path, 'chat_media'));
    if (!await media.exists()) await media.create(recursive: true);
    return media;
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

  Future<String?> saveIncomingBase64(String base64Data, String ext) async {
    try {
      final bytes = base64Decode(base64Data);
      return _saveFile(bytes, ext);
    } catch (_) {
      return null;
    }
  }

  Future<void> startVoiceRecord() async {
    if (await _recorder.hasPermission()) {
      final dir = await _mediaDir();
      _recordingPath = p.join(dir.path, '${_uuid.v4()}.m4a');
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: _recordingPath!,
      );
    }
  }

  Future<String?> stopVoiceRecord() async {
    final path = await _recorder.stop();
    return path ?? _recordingPath;
  }

  Future<void> playVoice(String path) async {
    final player = AudioPlayer();
    await player.play(DeviceFileSource(path));
  }
}
