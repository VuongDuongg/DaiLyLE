import 'dart:async';

abstract class ISpeechTranscriber {
  bool get isSupported;
  void start();
  Future<String?> stop();
}

ISpeechTranscriber getSpeechTranscriber() =>
    throw UnsupportedError('Speech transcriber is platform specific.');

