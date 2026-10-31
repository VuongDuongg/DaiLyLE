import 'dart:async';
import 'speech_transcriber_stub.dart';

export 'speech_transcriber_stub.dart';

class IoSpeechTranscriber implements ISpeechTranscriber {
  @override
  bool get isSupported => false;

  @override
  void start() {}

  @override
  Future<String?> stop() async => null;
}

ISpeechTranscriber getSpeechTranscriber() => IoSpeechTranscriber();

