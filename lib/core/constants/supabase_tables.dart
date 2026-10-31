/// Database table & bucket constants matching Supabase DDL
class SupabaseTables {
  SupabaseTables._();

  static const String profiles = 'profiles';
  static const String topics = 'topics';
  static const String topicSentences = 'topic_sentences';
  static const String lessonsAndSentences = 'lessons_and_sentences';
  static const String practiceSessions = 'practice_sessions';
  static const String pronunciationAttempts = 'pronunciation_attempts';

  // Storage Buckets
  static const String audioRecordingsBucket = 'audio-recordings';
}
