// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:html' as html;
import 'package:flutter/foundation.dart';
import 'speech_transcriber_stub.dart';

export 'speech_transcriber_stub.dart';

class WebSpeechTranscriber implements ISpeechTranscriber {
  html.SpeechRecognition? _recognition;
  String _finalTranscript = '';
  bool _isListening = false;

  @override
  bool get isSupported => html.SpeechRecognition.supported;

  @override
  void start() {
    if (!isSupported) {
      debugPrint('[WebSpeechTranscriber] Browser does not support SpeechRecognition');
      return;
    }

    try {
      _finalTranscript = '';
      _isListening = true;

      // Ensure previous instance is stopped
      if (_recognition != null) {
        try {
          _recognition!.stop();
        } catch (_) {}
      }

      _recognition = html.SpeechRecognition()
        ..continuous = true // Keep listening throughout user's speech until manually stopped
        ..interimResults = true // Capture live streaming words
        ..lang = 'en-US';

      _recognition!.onResult.listen((event) {
        final results = event.results;
        if (results != null) {
          final buffer = StringBuffer();
          for (var i = 0; i < results.length; i++) {
            final res = results[i];
            final item = res.item(0);
            if (item != null && item.transcript != null) {
              buffer.write('${item.transcript} ');
            }
          }
          final text = buffer.toString().trim();
          if (text.isNotEmpty) {
            _finalTranscript = text;
            debugPrint('[WebSpeechTranscriber] Live transcript: "$_finalTranscript"');
          }
        }
      });

      _recognition!.onError.listen((e) {
        debugPrint('[WebSpeechTranscriber] Recognition error: $e');
      });

      _recognition!.onEnd.listen((e) {
        debugPrint('[WebSpeechTranscriber] Recognition stream ended');
      });

      _recognition!.start();
      debugPrint('[WebSpeechTranscriber] Started continuous speech recognition in en-US');
    } catch (e) {
      debugPrint('[WebSpeechTranscriber] Exception starting recognition: $e');
      _isListening = false;
    }
  }

  @override
  Future<String?> stop() async {
    if (_recognition != null && _isListening) {
      try {
        _recognition!.stop();
      } catch (_) {}
    }
    _isListening = false;

    // Generous delay to allow the browser speech API to finish transcribing the last word
    await Future.delayed(const Duration(milliseconds: 500));
    final transcript = _finalTranscript.trim();
    debugPrint('[WebSpeechTranscriber] Final transcribed text: "$transcript"');
    return transcript.isNotEmpty ? transcript : null;
  }
}

ISpeechTranscriber getSpeechTranscriber() => WebSpeechTranscriber();
