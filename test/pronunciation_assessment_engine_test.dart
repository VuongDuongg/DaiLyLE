import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:dailyle/core/audio/speech_recorder_service.dart';
import 'package:dailyle/core/ai/pronunciation_assessment_engine.dart';

void main() {
  group('PronunciationAssessmentEngine Tests', () {
    final engine = PronunciationAssessmentEngine();

    test('Short or empty audio yields low score and missing speech feedback', () {
      final shortAudio = RecordedAudioResult(
        bytes: Uint8List.fromList(List.filled(200, 0)),
        localPath: 'dummy.wav',
        fileName: 'dummy.wav',
        mimeType: 'audio/wav',
        durationMs: 200,
      );

      final result = engine.evaluate(
        audioResult: shortAudio,
        targetSentence: 'Good morning, how are you today?',
        standardIpa: '/ɡʊd ˈmɔːr.nɪŋ, haʊ ɑːr juː təˈdeɪ/',
      );

      expect(result.overallScore, lessThan(30));
      expect(result.overallFeedback, contains('Không phát hiện'));
    });

    test('Exact match recognition yields high score (>= 90)', () {
      final audio = RecordedAudioResult(
        bytes: Uint8List.fromList(List.filled(15000, 1)),
        localPath: 'dummy.webm',
        fileName: 'dummy.webm',
        mimeType: 'audio/webm',
        durationMs: 2500,
      );

      final result = engine.evaluate(
        audioResult: audio,
        targetSentence: 'Good morning, how are you today?',
        standardIpa: '/ɡʊd ˈmɔːr.nɪŋ, haʊ ɑːr juː təˈdeɪ/',
        recognizedText: 'good morning how are you today',
      );

      expect(result.overallScore, greaterThanOrEqualTo(90));
      expect(result.words.length, equals(6));
      expect(result.words.every((w) => w.score >= 80), isTrue);
    });

    test('Mispronounced words (tink instead of think) detect phoneme error with tip', () {
      final audio = RecordedAudioResult(
        bytes: Uint8List.fromList(List.filled(10000, 1)),
        localPath: 'dummy.webm',
        fileName: 'dummy.webm',
        mimeType: 'audio/webm',
        durationMs: 1800,
      );

      final result = engine.evaluate(
        audioResult: audio,
        targetSentence: 'think through three thin things',
        standardIpa: '/θɪŋk θruː θriː θɪn θɪŋz/',
        recognizedText: 'tink through tree tin things',
      );

      expect(result.overallScore, lessThan(80));
      expect(result.recommendedPhonemeDrill, equals('/θ/'));

      // Word 1: 'think' mispronounced as 'tink'
      final thinkWord = result.words[0];
      final thetaPhoneme = thinkWord.phonemeAnalysis.firstWhere(
        (p) => p.phoneme == 'θ',
      );
      expect(thetaPhoneme.status, equals('wrong'));
      expect(thetaPhoneme.actual, equals('t'));
      expect(thetaPhoneme.tip, contains('đầu lưỡi giữa hai hàm răng'));
    });

    test('Missing half of sentence significantly lowers overall score', () {
      final audio = RecordedAudioResult(
        bytes: Uint8List.fromList(List.filled(8000, 1)),
        localPath: 'dummy.webm',
        fileName: 'dummy.webm',
        mimeType: 'audio/webm',
        durationMs: 1200,
      );

      final result = engine.evaluate(
        audioResult: audio,
        targetSentence: 'Good morning, how are you today?',
        standardIpa: '/ɡʊd ˈmɔːr.nɪŋ, haʊ ɑːr juː təˈdeɪ/',
        recognizedText: 'good morning',
      );

      expect(result.overallScore, lessThan(50));
      // First two words scored, rest 0
      expect(result.words[0].score, greaterThan(80));
      expect(result.words[1].score, greaterThan(80));
      expect(result.words[2].score, equals(0));
      expect(result.words[3].score, equals(0));
    });
  });
}

