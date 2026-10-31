import 'dart:async';
import 'speech_transcriber_stub.dart'
    if (dart.library.html) 'speech_transcriber_web.dart'
    if (dart.library.io) 'speech_transcriber_io.dart';

export 'speech_transcriber_stub.dart';

class SpeechTranscriptionService {
  static final SpeechTranscriptionService _instance =
      SpeechTranscriptionService._internal();
  factory SpeechTranscriptionService() => _instance;

  final ISpeechTranscriber _transcriber;

  SpeechTranscriptionService._internal()
      : _transcriber = getSpeechTranscriber();

  bool get isSupported => _transcriber.isSupported;

  void start() {
    _transcriber.start();
  }

  Future<String?> stop() async {
    return await _transcriber.stop();
  }
}

