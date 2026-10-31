import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/storage/progress_storage_service.dart';
import '../../../practice/data/repositories/practice_repository_impl.dart';
import '../../domain/entities/discipline_stats.dart';
import '../../domain/entities/topic_mastery_stat.dart';
import '../../domain/repositories/statistics_repository.dart';

class StatisticsRepositoryImpl implements IStatisticsRepository {
  final SupabaseClient? _client;

  StatisticsRepositoryImpl({SupabaseClient? client}) : _client = client;

  SupabaseClient? get _supabase {
    if (_client != null) return _client;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<DisciplineStats> getDisciplineStats() async {
    final client = _supabase;
    if (client != null) {
      final user = client.auth.currentUser;
      if (user != null) {
        try {
          final res = await client.rpc(
            'get_user_discipline_stats',
            params: {'p_user_id': user.id},
          );
          if (res != null) {
            return DisciplineStats.fromJson(res as Map<String, dynamic>);
          }
        } catch (e) {
          debugPrint('[StatisticsRepo] getDisciplineStats RPC failed: $e');
        }
      }
    }

    final storage = ProgressStorageService();
    await storage.init();
    return storage.getDisciplineStats();
  }

  @override
  Future<List<double>> getWeeklyStudyMinutes() async {
    final client = _supabase;
    if (client != null) {
      final user = client.auth.currentUser;
      if (user != null) {
        try {
          final res = await client.rpc(
            'get_weekly_study_minutes',
            params: {'p_user_id': user.id},
          );
          if (res is List) {
            return res.map((e) => (e as num).toDouble()).toList();
          }
        } catch (e) {
          debugPrint('[StatisticsRepo] getWeeklyStudyMinutes RPC failed: $e');
        }
      }
    }

    final storage = ProgressStorageService();
    await storage.init();
    return storage.getWeeklyStudyMinutes();
  }

  @override
  Future<List<double>> getScoreTrends() async {
    final client = _supabase;
    if (client != null) {
      final user = client.auth.currentUser;
      if (user != null) {
        try {
          final res = await client.rpc(
            'get_user_score_trends',
            params: {'p_user_id': user.id},
          );
          if (res is List && res.isNotEmpty) {
            return res.map((e) => (e as num).toDouble()).toList();
          }
        } catch (e) {
          debugPrint('[StatisticsRepo] getScoreTrends RPC failed: $e');
        }
      }
    }

    final storage = ProgressStorageService();
    await storage.init();
    return storage.getScoreTrends();
  }

  @override
  Future<List<TopicMasteryStat>> getTopicMastery() async {
    final storage = ProgressStorageService();
    await storage.init();
    return storage.getTopicMastery(
      PracticeRepositoryImpl.fallbackTopics,
      PracticeRepositoryImpl.fallbackSentences,
    );
  }

  @override
  Future<List<WeakPhonemeStat>> getWeakPhonemes() async {
    final storage = ProgressStorageService();
    await storage.init();
    return storage.getWeakPhonemes();
  }

  @override
  Future<void> updateDailyGoal(int newGoalMinutes) async {
    final storage = ProgressStorageService();
    await storage.init();
    await storage.updateDailyGoal(newGoalMinutes);

    final client = _supabase;
    if (client != null) {
      final user = client.auth.currentUser;
      if (user != null) {
        try {
          await client.rpc(
            'update_user_discipline_settings',
            params: {
              'p_user_id': user.id,
              'p_new_goal': newGoalMinutes,
            },
          );
        } catch (e) {
          debugPrint('[StatisticsRepo] updateDailyGoal failed: $e');
        }
      }
    }
  }

  @override
  Future<void> updateReminderTime(String time) async {
    final storage = ProgressStorageService();
    await storage.init();
    await storage.updateReminderTime(time);

    final client = _supabase;
    if (client != null) {
      final user = client.auth.currentUser;
      if (user != null) {
        try {
          await client.rpc(
            'update_user_discipline_settings',
            params: {
              'p_user_id': user.id,
              'p_reminder_time': time,
            },
          );
        } catch (e) {
          debugPrint('[StatisticsRepo] updateReminderTime failed: $e');
        }
      }
    }
  }
}
