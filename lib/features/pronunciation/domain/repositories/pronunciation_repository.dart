import '../../../../core/audio/speech_recorder_service.dart';
import '../entities/assessment_result.dart';

abstract class IPronunciationRepository {
  /// Assesses user speech recording against standard IPA,
  /// saves the audio to Supabase Storage, logs the attempt in Supabase DB,
  /// and returns the structured evaluation JSON.
  Future<AssessmentResult> assessAndSaveAttempt({
    required String sentenceId,
    required String targetText,
    required String standardIpa,
    required RecordedAudioResult audioResult,
    String? sessionId,
  });

  /// Fetches historical attempts for a given sentence or user
  Future<List<AssessmentResult>> getSentenceAttempts({
    required String sentenceId,
  });
}

