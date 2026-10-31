import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/audio/speech_recorder_service.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/constants/supabase_tables.dart';
import '../../domain/entities/assessment_result.dart';

abstract class IPronunciationRemoteDataSource {
  Future<AssessmentResult> evaluateAndPersist({
    required String sentenceId,
    required String targetText,
    required String standardIpa,
    required RecordedAudioResult audioResult,
    String? sessionId,
  });
}

class PronunciationRemoteDataSource implements IPronunciationRemoteDataSource {
  final SupabaseClient? _customClient;

  PronunciationRemoteDataSource({SupabaseClient? supabase})
      : _customClient = supabase;

  SupabaseClient get _supabase {
    if (_customClient != null) return _customClient!;
    try {
      return Supabase.instance.client;
    } catch (e) {
      throw Exception('Supabase client chưa được khởi tạo: $e');
    }
  }

  @override
  Future<AssessmentResult> evaluateAndPersist({
    required String sentenceId,
    required String targetText,
    required String standardIpa,
    required RecordedAudioResult audioResult,
    String? sessionId,
  }) async {
    final client = _supabase;
    final user = client.auth.currentUser;
    if (user == null) {
      throw Exception('Cần đăng nhập Supabase trước khi nộp bài luyện âm.');
    }

    final userId = user.id;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final storagePath = '$userId/${timestamp}_${audioResult.fileName}';

    // 1. Upload audio bytes directly to Supabase Storage bucket 'audio-recordings'
    // (Works seamlessly across Android and Web)
    await client.storage.from(SupabaseTables.audioRecordingsBucket).uploadBinary(
          storagePath,
          audioResult.bytes,
          fileOptions: FileOptions(
            contentType: audioResult.mimeType,
            upsert: true,
          ),
        );

    // 2. Generate signed audio URL for private playback and AI processor
    final signedAudioUrl = await client.storage
        .from(SupabaseTables.audioRecordingsBucket)
        .createSignedUrl(storagePath, 60 * 60 * 24); // 24 hours validity

    // 3. Call AI Pronunciation Assessment Engine (Supabase Edge Function)
    final base64Audio = base64Encode(audioResult.bytes);
    final response = await client.functions.invoke(
      ApiEndpoints.assessPronunciationEdgeFunction,
      body: {
        'audio_url': signedAudioUrl,
        'audio_base64': base64Audio,
        'target_text': targetText,
        'standard_ipa': standardIpa,
      },
    );

    if (response.status != 200 || response.data == null) {
      throw Exception('Đánh giá phát âm thất bại với mã lỗi: ${response.status}');
    }

    final Map<String, dynamic> responseData = response.data is String
        ? jsonDecode(response.data as String) as Map<String, dynamic>
        : response.data as Map<String, dynamic>;

    final assessment = AssessmentResult.fromJson(
      responseData,
      audioUrl: signedAudioUrl,
    );

    // 4. Transform word & phoneme analysis into structured JSON for database storage
    final phonemeDiffJson = assessment.words.map((w) => w.toJson()).toList();

    // 5. Persist the attempt into Supabase table 'pronunciation_attempts'
    final insertResult = await client
        .from(SupabaseTables.pronunciationAttempts)
        .insert({
          'user_id': userId,
          'sentence_id': sentenceId,
          'session_id': sessionId,
          'audio_url': signedAudioUrl,
          'overall_score': assessment.overallScore,
          'recognized_text': targetText,
          'expected_ipa': standardIpa,
          'actual_ipa': assessment.words.map((w) => w.actualIpa).join(' '),
          'phoneme_diff_json': phonemeDiffJson,
          'feedback_text': assessment.overallFeedback,
        })
        .select('id')
        .single();

    final attemptId = insertResult['id'] as String?;

    return AssessmentResult.fromJson(
      responseData,
      audioUrl: signedAudioUrl,
      attemptId: attemptId,
    );
  }
}
