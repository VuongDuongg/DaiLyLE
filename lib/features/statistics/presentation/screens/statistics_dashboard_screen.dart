import 'package:flutter/material.dart';
import '../../../../core/storage/progress_storage_service.dart';
import '../../data/repositories/statistics_repository_impl.dart';
import '../../domain/entities/discipline_stats.dart';
import '../../domain/entities/topic_mastery_stat.dart';
import '../../domain/repositories/statistics_repository.dart';
import '../widgets/reminder_settings_card.dart';
import '../widgets/score_trend_linechart.dart';
import '../widgets/streak_calendar_card.dart';
import '../widgets/topic_mastery_card.dart';
import '../widgets/weak_phonemes_section.dart';
import '../widgets/weekly_time_barchart.dart';

class StatisticsDashboardScreen extends StatefulWidget {
  final Function(String targetPhoneme)? onNavigateToPhonemePractice;

  const StatisticsDashboardScreen({
    super.key,
    this.onNavigateToPhonemePractice,
  });

  @override
  State<StatisticsDashboardScreen> createState() =>
      _StatisticsDashboardScreenState();
}

class _StatisticsDashboardScreenState extends State<StatisticsDashboardScreen> {
  late final IStatisticsRepository _statsRepo;
  bool _isLoading = true;

  DisciplineStats? _disciplineStats;
  List<double> _weeklyMinutes = [];
  List<double> _scoreTrends = [];
  List<TopicMasteryStat> _topicMastery = [];
  List<WeakPhonemeStat> _weakPhonemes = [];

  @override
  void initState() {
    super.initState();
    _statsRepo = StatisticsRepositoryImpl();
    ProgressStorageService().addListener(_onStorageChanged);
    _loadAllStats();
  }

  void _onStorageChanged() {
    if (mounted) {
      _loadAllStats();
    }
  }

  @override
  void dispose() {
    ProgressStorageService().removeListener(_onStorageChanged);
    super.dispose();
  }

  Future<void> _loadAllStats() async {
    setState(() => _isLoading = true);

    final stats = await _statsRepo.getDisciplineStats();
    final weekly = await _statsRepo.getWeeklyStudyMinutes();
    final trends = await _statsRepo.getScoreTrends();
    final topics = await _statsRepo.getTopicMastery();
    final weak = await _statsRepo.getWeakPhonemes();

    if (mounted) {
      setState(() {
        _disciplineStats = stats;
        _weeklyMinutes = weekly;
        _scoreTrends = trends;
        _topicMastery = topics;
        _weakPhonemes = weak;
        _isLoading = false;
      });
    }
  }

  void _onEditDailyGoal(int newGoal) async {
    await _statsRepo.updateDailyGoal(newGoal);
    if (_disciplineStats != null) {
      setState(() {
        _disciplineStats = _disciplineStats!.copyWith(dailyGoalMinutes: newGoal);
      });
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Đã cập nhật mục tiêu học: $newGoal phút/ngày.')),
    );
  }

  void _onReminderTimeChanged(String newTime) async {
    await _statsRepo.updateReminderTime(newTime);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktopOrWeb = screenWidth > 800;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Kỷ Luật & Thống Kê Học Tập',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadAllStats,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAllStats,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktopOrWeb ? screenWidth * 0.15 : 20,
                  vertical: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Component 2A: Streak & Weekly Calendar & Goal
                    if (_disciplineStats != null)
                      StreakCalendarCard(
                        stats: _disciplineStats!,
                        onEditGoal: _onEditDailyGoal,
                      ),
                    const SizedBox(height: 20),

                    // Component 2B: Weekly Study Time BarChart
                    WeeklyTimeBarChart(
                      weeklyMinutes: _weeklyMinutes,
                      goalMinutes:
                          (_disciplineStats?.dailyGoalMinutes ?? 15).toDouble(),
                    ),
                    const SizedBox(height: 20),

                    // Component 2B: Score Trend LineChart
                    ScoreTrendLineChart(scores: _scoreTrends),
                    const SizedBox(height: 20),

                    // Component 2C: Topic Breakdown
                    TopicMasteryCard(topics: _topicMastery),
                    const SizedBox(height: 20),

                    // Component 2C: Weak Phoneme Insights
                    WeakPhonemesSection(
                      weakPhonemes: _weakPhonemes,
                      onSelectPhoneme: (phoneme) {
                        if (widget.onNavigateToPhonemePractice != null) {
                          widget.onNavigateToPhonemePractice!(phoneme);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Đang lọc bài học cho âm /$phoneme/...'),
                            ),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 20),

                    // Component 2D: Daily Reminder Settings
                    ReminderSettingsCard(
                      initialTime: _disciplineStats?.reminderTime ?? '20:00:00',
                      onTimeChanged: _onReminderTimeChanged,
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }
}

