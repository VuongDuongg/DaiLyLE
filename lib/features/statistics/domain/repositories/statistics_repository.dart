import '../entities/discipline_stats.dart';
import '../entities/topic_mastery_stat.dart';

abstract class IStatisticsRepository {
  Future<DisciplineStats> getDisciplineStats();
  Future<List<double>> getWeeklyStudyMinutes();
  Future<List<double>> getScoreTrends();
  Future<List<TopicMasteryStat>> getTopicMastery();
  Future<List<WeakPhonemeStat>> getWeakPhonemes();
  Future<void> updateDailyGoal(int newGoalMinutes);
  Future<void> updateReminderTime(String time);
}

