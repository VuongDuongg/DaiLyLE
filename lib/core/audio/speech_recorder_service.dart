import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

import 'file_reader_stub.dart'
    if (dart.library.io) 'file_reader_io.dart'
    if (dart.library.js_interop) 'file_reader_web.dart'
    if (dart.library.html) 'file_reader_web.dart';

/// Result encapsulation for captured audio on Android and Web
class RecordedAudioResult {
  final Uint8List bytes;
  final String? localPath;
  final String fileName;
  final String mimeType;
  final int durationMs;

  const RecordedAudioResult({
    required this.bytes,
    this.localPath,
    required this.fileName,
    required this.mimeType,
    required this.durationMs,
  });
}

/// Abstract contract for Speech Recorder
abstract class ISpeechRecorderService {
  Future<bool> hasPermission();
  Future<void> startRecording();
  Future<RecordedAudioResult?> stopRecording();
  Future<void> cancelRecording();
  Future<bool> isRecording();
  Stream<RecordState> get stateStream;
  Stream<Amplitude> get amplitudeStream;
  Future<void> dispose();
}

/// Cross-platform implementation of ISpeechRecorderService
/// Configured for 16kHz audio: PCM WAV on Android, Opus/WebM on Web
class SpeechRecorderService implements ISpeechRecorderService {
  final AudioRecorder _audioRecorder;
  final FileBytesReader _fileBytesReader;
  DateTime? _recordStartTime;
  String? _currentFilePath;

  SpeechRecorderService({
    AudioRecorder? audioRecorder,
    FileBytesReader? fileBytesReader,
  })  : _audioRecorder = audioRecorder ?? AudioRecorder(),
        _fileBytesReader = fileBytesReader ?? getFileBytesReader();

  @override
  Stream<RecordState> get stateStream => _audioRecorder.onStateChanged();

  @override
  Stream<Amplitude> get amplitudeStream =>
      _audioRecorder.onAmplitudeChanged(const Duration(milliseconds: 100));

  @override
  Future<bool> hasPermission() async {
    try {
      final permitted = await _audioRecorder.hasPermission();
      debugPrint('[SpeechRecorderService] Permission status: $permitted');
      return permitted;
    } catch (e) {
      debugPrint('[SpeechRecorderService] Permission check error: $e');
      return false;
    }
  }

  @override
  Future<void> startRecording() async {
    final permitted = await hasPermission();
    if (!permitted) {
      throw Exception('Chưa cấp quyền microphone trên trình duyệt. Vui lòng bấm vào biểu tượng ổ khóa/micro trên thanh địa chỉ Edge và chọn "Cho phép" (Allow).');
    }

    if (await _audioRecorder.isRecording()) {
      await _audioRecorder.stop();
    }

    _recordStartTime = DateTime.now();

    // Browser MediaRecorder natively supports Opus (audio/webm).
    // Native mobile platforms support WAV PCM 16kHz directly.
    final config = kIsWeb
        ? const RecordConfig(
            encoder: AudioEncoder.opus,
            sampleRate: 16000,
            numChannels: 1,
          )
        : const RecordConfig(
            encoder: AudioEncoder.wav,
            sampleRate: 16000,
            numChannels: 1,
            bitRate: 256000,
          );

    if (kIsWeb) {
      // On Web: pass empty path to use browser MediaStream/Blob memory storage
      _currentFilePath = null;
      await _audioRecorder.start(config, path: '');
    } else {
      // On Android / iOS: generate temporary WAV file path
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _currentFilePath = '${tempDir.path}/speech_$timestamp.wav';
      await _audioRecorder.start(config, path: _currentFilePath!);
    }
  }

  @override
  Future<RecordedAudioResult?> stopRecording() async {
    if (!await _audioRecorder.isRecording()) {
      return null;
    }

    final durationMs = _recordStartTime != null
        ? DateTime.now().difference(_recordStartTime!).inMilliseconds
        : 0;

    // stop() returns local file path on mobile or Blob URL (blob:http://...) on Web
    final pathOrBlobUrl = await _audioRecorder.stop();
    if (pathOrBlobUrl == null) {
      return null;
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = kIsWeb ? 'rec_$timestamp.webm' : 'rec_$timestamp.wav';
    final mimeType = kIsWeb ? 'audio/webm' : 'audio/wav';

    // Platform-agnostic read using conditional reader
    final audioBytes = await _fileBytesReader.readBytes(pathOrBlobUrl);

    return RecordedAudioResult(
      bytes: audioBytes,
      localPath: pathOrBlobUrl, // Preserves Blob URL on Web (blob:http://...) and file path on Android
      fileName: fileName,
      mimeType: mimeType,
      durationMs: durationMs,
    );
  }

  @override
  Future<void> cancelRecording() async {
    if (await _audioRecorder.isRecording()) {
      await _audioRecorder.stop();
    }
    _currentFilePath = null;
    _recordStartTime = null;
  }

  @override
  Future<bool> isRecording() async {
    return await _audioRecorder.isRecording();
  }

  @override
  Future<void> dispose() async {
    await _audioRecorder.dispose();
  }
}
