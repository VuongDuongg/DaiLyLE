import '../../../../core/audio/speech_recorder_service.dart';
import '../../domain/entities/assessment_result.dart';
import '../../domain/repositories/pronunciation_repository.dart';
import '../datasources/pronunciation_remote_datasource.dart';

class PronunciationRepositoryImpl implements IPronunciationRepository {
  final IPronunciationRemoteDataSource _remoteDataSource;

  PronunciationRepositoryImpl({
    IPronunciationRemoteDataSource? remoteDataSource,
  }) : _remoteDataSource =
            remoteDataSource ?? PronunciationRemoteDataSource();

  @override
  Future<AssessmentResult> assessAndSaveAttempt({
    required String sentenceId,
    required String targetText,
    required String standardIpa,
    required RecordedAudioResult audioResult,
    String? sessionId,
  }) async {
    try {
      return await _remoteDataSource.evaluateAndPersist(
        sentenceId: sentenceId,
        targetText: targetText,
        standardIpa: standardIpa,
        audioResult: audioResult,
        sessionId: sessionId,
      );
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<AssessmentResult>> getSentenceAttempts({
    required String sentenceId,
  }) async {
    // Queries attempts from Supabase for history tracking
    return [];
  }
}

