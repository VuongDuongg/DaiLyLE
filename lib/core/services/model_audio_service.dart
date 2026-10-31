import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

enum AudioSpeed {
  normal, // 1.0x
  slow,   // 0.6x
}

class ModelAudioService {
  static final ModelAudioService _instance = ModelAudioService._internal();
  factory ModelAudioService() => _instance;

  final AudioPlayer _audioPlayer = AudioPlayer();
  final FlutterTts _flutterTts = FlutterTts();

  bool _isTtsInitialized = false;
  final ValueNotifier<bool> isPlayingNotifier = ValueNotifier<bool>(false);

  ModelAudioService._internal() {
    _initTts();
    _initAudioPlayer();
  }

  Future<void> _initTts() async {
    if (_isTtsInitialized) return;
    try {
      await _flutterTts.setLanguage('en-US');
      await _flutterTts.setPitch(1.0);

      _flutterTts.setStartHandler(() {
        isPlayingNotifier.value = true;
      });

      _flutterTts.setCompletionHandler(() {
        isPlayingNotifier.value = false;
      });

      _flutterTts.setErrorHandler((msg) {
        debugPrint('[ModelAudioService] TTS Error: $msg');
        isPlayingNotifier.value = false;
      });

      _flutterTts.setCancelHandler(() {
        isPlayingNotifier.value = false;
      });

      _isTtsInitialized = true;
    } catch (e) {
      debugPrint('[ModelAudioService] Init TTS exception: $e');
    }
  }

  void _initAudioPlayer() {
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (state == PlayerState.playing) {
        isPlayingNotifier.value = true;
      } else if (state == PlayerState.completed ||
          state == PlayerState.stopped ||
          state == PlayerState.paused) {
        isPlayingNotifier.value = false;
      }
    });
  }

  /// Plays the entire sentence with configurable speed (Normal: 1.0x, Slow: 0.6x)
  Future<void> playSentence({
    required String text,
    String? audioUrl,
    AudioSpeed speed = AudioSpeed.normal,
  }) async {
    // 1. Stop any currently active audio
    await stopAllPlayback();

    // 2. If pre-recorded native audio URL exists, stream it via AudioPlayer
    if (audioUrl != null && audioUrl.isNotEmpty && audioUrl.startsWith('http')) {
      try {
        final playbackRate = speed == AudioSpeed.normal ? 1.0 : 0.65;
        await _audioPlayer.setPlaybackRate(playbackRate);
        await _audioPlayer.play(UrlSource(audioUrl));
        return;
      } catch (e) {
        debugPrint('[ModelAudioService] UrlSource failed, falling back to TTS: $e');
      }
    }

    // 3. Fallback to high-quality cross-platform TTS
    await _speakWithTts(text, speed: speed);
  }

  /// Pronounces a single word when user taps on an interactive word chip
  Future<void> speakSingleWord(String word) async {
    await stopAllPlayback();
    // Clean punctuation: "today?" -> "today"
    final cleanWord = word.replaceAll(RegExp(r'[^\w\s]'), '');
    await _speakWithTts(cleanWord, speed: AudioSpeed.normal);
  }

  /// Plays user's own recorded audio from local file, web blob, or raw bytes
  Future<void> playUserRecording(
    String? pathOrBlobUrl, {
    Uint8List? bytes,
    String mimeType = 'audio/webm',
  }) async {
    await stopAllPlayback();
    isPlayingNotifier.value = true;

    try {
      if (pathOrBlobUrl != null && pathOrBlobUrl.isNotEmpty) {
        if (kIsWeb || pathOrBlobUrl.startsWith('http') || pathOrBlobUrl.startsWith('blob:')) {
          await _audioPlayer.play(UrlSource(pathOrBlobUrl));
          return;
        } else {
          await _audioPlayer.play(DeviceFileSource(pathOrBlobUrl));
          return;
        }
      }

      if (bytes != null && bytes.isNotEmpty) {
        await _audioPlayer.play(BytesSource(bytes, mimeType: mimeType));
        return;
      }

      isPlayingNotifier.value = false;
    } catch (e) {
      debugPrint('[ModelAudioService] Play user recording error: $e');
      isPlayingNotifier.value = false;
    }
  }

  Future<void> _speakWithTts(String text, {required AudioSpeed speed}) async {
    await _initTts();

    // Calibrated speech rates for Android vs Web
    // Normal: 0.5 on Android / 0.9 on Web
    // Slow:   0.3 on Android / 0.55 on Web (for shadowing practice)
    double rate;
    if (kIsWeb) {
      rate = speed == AudioSpeed.normal ? 0.9 : 0.55;
    } else {
      rate = speed == AudioSpeed.normal ? 0.5 : 0.3;
    }

    try {
      await _flutterTts.setSpeechRate(rate);
      await _flutterTts.speak(text);
    } catch (e) {
      debugPrint('[ModelAudioService] TTS speak exception: $e');
      isPlayingNotifier.value = false;
    }
  }

  /// CRITICAL: Stops all speaker output immediately when user starts recording
  Future<void> stopAllPlayback() async {
    try {
      await _audioPlayer.stop();
      await _flutterTts.stop();
    } catch (_) {}
    isPlayingNotifier.value = false;
  }

  void dispose() {
    _audioPlayer.dispose();
    _flutterTts.stop();
  }
}

