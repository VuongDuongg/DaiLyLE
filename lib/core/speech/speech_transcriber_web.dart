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
  int _restartAttempts = 0;

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
      _restartAttempts = 0;

      // Abort any previous zombie recognition instance
      if (_recognition != null) {
        try {
          _recognition!.abort();
        } catch (_) {}
      }

      _initAndStart();
    } catch (e) {
      debugPrint('[WebSpeechTranscriber] Exception starting recognition: $e');
      _isListening = false;
    }
  }

  void _initAndStart() {
    try {
      _recognition = html.SpeechRecognition()
        ..continuous = true // Keep listening throughout user's speech until manually stopped
        ..interimResults = true // Capture live streaming words
        ..lang = 'en-US';

      _recognition!.onResult.listen((event) {
        try {
          final results = event.results;
          if (results != null && results.isNotEmpty) {
            final buffer = StringBuffer();
            for (var i = 0; i < results.length; i++) {
              final res = results[i];
              String? transcript;
              try {
                final alt = res.item(0);
                transcript = alt.transcript;
              } catch (_) {
                try {
                  final dynamic dyn = res;
                  transcript = dyn[0]?.transcript?.toString();
                } catch (_) {}
              }
              if (transcript != null && transcript.trim().isNotEmpty) {
                buffer.write('${transcript.trim()} ');
              }
            }
            final text = buffer.toString().trim();
            if (text.isNotEmpty) {
              _finalTranscript = text;
              debugPrint('[WebSpeechTranscriber] Live transcript: "$_finalTranscript"');
            }
          }
        } catch (e) {
          debugPrint('[WebSpeechTranscriber] Error parsing speech result: $e');
        }
      });

      _recognition!.onError.listen((e) {
        try {
          final dynamic err = e;
          debugPrint(
              '[WebSpeechTranscriber] Recognition error code: ${err.error}, message: ${err.message}');
        } catch (_) {
          debugPrint('[WebSpeechTranscriber] Recognition error: $e');
        }
      });

      _recognition!.onEnd.listen((e) {
        debugPrint('[WebSpeechTranscriber] Recognition stream ended');
        // If the user is still recording and hasn't clicked stop yet,
        // auto-restart recognition (e.g. Chrome/Edge silence timeout)
        if (_isListening && _restartAttempts < 5) {
          _restartAttempts++;
          debugPrint('[WebSpeechTranscriber] Recording still active, auto-restarting speech listener (attempt #$_restartAttempts)...');
          Timer(const Duration(milliseconds: 150), () {
            if (_isListening) {
              try {
                _initAndStart();
              } catch (err) {
                debugPrint('[WebSpeechTranscriber] Auto-restart error: $err');
              }
            }
          });
        }
      });

      _recognition!.start();
      debugPrint('[WebSpeechTranscriber] Started continuous speech recognition in en-US');
    } catch (e) {
      debugPrint('[WebSpeechTranscriber] Init error: $e');
    }
  }

  @override
  Future<String?> stop() async {
    _isListening = false; // Prevents onEnd from auto-restarting
    if (_recognition != null) {
      try {
        _recognition!.stop();
      } catch (_) {}
    }

    // Generous delay to allow the browser speech API to finish transcribing the last word
    await Future.delayed(const Duration(milliseconds: 400));
    final transcript = _finalTranscript.trim();
    debugPrint('[WebSpeechTranscriber] Final transcribed text: "$transcript"');
    return transcript.isNotEmpty ? transcript : null;
  }
}

ISpeechTranscriber getSpeechTranscriber() => WebSpeechTranscriber();
