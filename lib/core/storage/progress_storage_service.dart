import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dailyle/features/statistics/domain/entities/discipline_stats.dart';
import 'package:dailyle/features/practice/domain/entities/topic.dart';
import 'package:dailyle/features/practice/domain/entities/topic_sentence.dart';
import 'package:dailyle/features/pronunciation/domain/entities/assessment_result.dart';
import 'package:dailyle/features/statistics/domain/entities/topic_mastery_stat.dart';
import 'package:dailyle/core/ai/pronunciation_assessment_engine.dart';

class ProgressStorageService extends ChangeNotifier {
  static final ProgressStorageService _instance = ProgressStorageService._internal();
  factory ProgressStorageService() => _instance;
  ProgressStorageService._internal();

  static const String _kSentenceScoresKey = 'dailyle_sentence_scores';
  static const String _kDisciplineStatsKey = 'dailyle_discipline_stats';
  static const String _kWeeklyMinutesKey = 'dailyle_weekly_minutes';
  static const String _kScoreTrendsKey = 'dailyle_score_trends';
  static const String _kWeakPhonemesKey = 'dailyle_weak_phonemes';

  SharedPreferences? _prefs;
  bool _isInitialized = false;

  // In-memory caches for instantaneous synchronous reads
  final Map<String, int> _sentenceScores = {};
  int _currentStreak = 1;
  int _longestStreak = 7;
  int _dailyGoalMinutes = 15;
  int _todayMinutes = 0;
  String _lastPracticeDate = '';
  bool _isTodayCompleted = false;
  String _reminderTime = '20:00:00';
  List<bool> _weeklyActiveDays = [false, false, false, false, false, false, false];
  List<double> _weeklyStudyMinutes = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
  List<double> _scoreTrends = [75.0, 80.0, 85.0];
  final Map<String, int> _weakPhonemesErrors = {'θ': 3, 's': 2, 'ʃ': 1};

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      _prefs = await SharedPreferences.getInstance();
      _loadFromPrefs();
      _checkStreakRollover();
      _isInitialized = true;
      debugPrint('[ProgressStorageService] Initialized with persistent storage.');
    } catch (e) {
      debugPrint('[ProgressStorageService] Init fallback (in-memory): $e');
      _isInitialized = true;
    }
  }

  void _loadFromPrefs() {
    if (_prefs == null) return;

    // 1. Sentence scores
    final scoresJson = _prefs!.getString(_kSentenceScoresKey);
    if (scoresJson != null) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(scoresJson);
        decoded.forEach((key, value) {
          if (value is num) _sentenceScores[key] = value.toInt();
        });
      } catch (e) {
        debugPrint('[ProgressStorage] Load scores error: $e');
      }
    }

    // 2. Discipline stats
    final statsJson = _prefs!.getString(_kDisciplineStatsKey);
    if (statsJson != null) {
      try {
        final Map<String, dynamic> d = jsonDecode(statsJson);
        _currentStreak = d['current_streak'] ?? 1;
        _longestStreak = d['longest_streak'] ?? 7;
        _dailyGoalMinutes = d['daily_goal_minutes'] ?? 15;
        _todayMinutes = d['today_minutes'] ?? 0;
        _lastPracticeDate = d['last_practice_date'] ?? '';
        _isTodayCompleted = d['is_today_completed'] ?? false;
        _reminderTime = d['reminder_time'] ?? '20:00:00';
        if (d['weekly_active_days'] is List) {
          _weeklyActiveDays = (d['weekly_active_days'] as List)
              .map((e) => e == true)
              .toList();
        }
      } catch (e) {
        debugPrint('[ProgressStorage] Load discipline stats error: $e');
      }
    }

    // 3. Weekly minutes
    final weeklyList = _prefs!.getStringList(_kWeeklyMinutesKey);
    if (weeklyList != null && weeklyList.length == 7) {
      _weeklyStudyMinutes = weeklyList
          .map((s) => double.tryParse(s) ?? 0.0)
          .toList();
    }

    // 4. Score trends
    final trendsList = _prefs!.getStringList(_kScoreTrendsKey);
    if (trendsList != null && trendsList.isNotEmpty) {
      _scoreTrends = trendsList
          .map((s) => double.tryParse(s) ?? 75.0)
          .toList();
    }

    // 5. Weak phonemes
    final weakJson = _prefs!.getString(_kWeakPhonemesKey);
    if (weakJson != null) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(weakJson);
        decoded.forEach((key, value) {
          if (value is num) _weakPhonemesErrors[key] = value.toInt();
        });
      } catch (e) {
        debugPrint('[ProgressStorage] Load weak phonemes error: $e');
      }
    }
  }

  void _checkStreakRollover() {
    final today = _formatDate(DateTime.now());
    if (_lastPracticeDate.isEmpty) {
      _lastPracticeDate = today;
      return;
    }

    if (_lastPracticeDate == today) {
      // Practiced today already, streak is active
      return;
    }

    final yesterday = _formatDate(DateTime.now().subtract(const Duration(days: 1)));
    if (_lastPracticeDate != yesterday) {
      // Missed more than 1 day -> reset current streak to 1
      _currentStreak = 1;
      _todayMinutes = 0;
      _isTodayCompleted = false;
    } else {
      // New day started -> reset today's minutes
      _todayMinutes = 0;
      _isTodayCompleted = false;
    }
  }

  Future<void> _persistAll() async {
    if (_prefs == null) return;
    try {
      await _prefs!.setString(_kSentenceScoresKey, jsonEncode(_sentenceScores));
      await _prefs!.setString(
        _kDisciplineStatsKey,
        jsonEncode({
          'current_streak': _currentStreak,
          'longest_streak': _longestStreak,
          'daily_goal_minutes': _dailyGoalMinutes,
          'today_minutes': _todayMinutes,
          'last_practice_date': _lastPracticeDate,
          'is_today_completed': _isTodayCompleted,
          'reminder_time': _reminderTime,
          'weekly_active_days': _weeklyActiveDays,
        }),
      );
      await _prefs!.setStringList(
        _kWeeklyMinutesKey,
        _weeklyStudyMinutes.map((m) => m.toStringAsFixed(1)).toList(),
      );
      await _prefs!.setStringList(
        _kScoreTrendsKey,
        _scoreTrends.map((s) => s.toStringAsFixed(1)).toList(),
      );
      await _prefs!.setString(_kWeakPhonemesKey, jsonEncode(_weakPhonemesErrors));
    } catch (e) {
      debugPrint('[ProgressStorage] Error persisting: $e');
    }
  }

  // ==========================================
  // CORE RECORDING METHOD CALLED ON SENTENCE COMPLETION
  // ==========================================
  Future<void> recordSentenceAttempt({
    required String sentenceId,
    required String topicId,
    required int score,
    int durationSeconds = 90, // ~1.5 minutes per speech attempt
    List<PhonemeAnalysisItem>? phonemeAnalysis,
  }) async {
    await init();

    // 1. Update Best Score for this sentence
    final currentBest = _sentenceScores[sentenceId] ?? 0;
    if (score > currentBest) {
      _sentenceScores[sentenceId] = score;
    }

    // 2. Update Daily Study Time
    final addedMinutes = max(1, (durationSeconds / 60).round());
    _todayMinutes += addedMinutes;
    if (_todayMinutes >= _dailyGoalMinutes) {
      _isTodayCompleted = true;
    }

    // 3. Update Streak & Active Calendar Day
    final now = DateTime.now();
    final today = _formatDate(now);
    // weekday in Dart: 1 = Mon, 7 = Sun -> index 0..6
    final weekdayIndex = now.weekday - 1;
    if (weekdayIndex >= 0 && weekdayIndex < 7) {
      _weeklyActiveDays[weekdayIndex] = true;
      _weeklyStudyMinutes[weekdayIndex] += addedMinutes.toDouble();
    }

    if (_lastPracticeDate != today) {
      final yesterday = _formatDate(now.subtract(const Duration(days: 1)));
      if (_lastPracticeDate == yesterday) {
        _currentStreak += 1;
      } else if (_lastPracticeDate.isEmpty) {
        _currentStreak = 1;
      }
      _lastPracticeDate = today;
      if (_currentStreak > _longestStreak) {
        _longestStreak = _currentStreak;
      }
    }

    // 4. Update Score Trends
    if (score > 0) {
      _scoreTrends.add(score.toDouble());
      if (_scoreTrends.length > 14) {
        _scoreTrends.removeAt(0);
      }
    }

    // 5. Aggregate Weak Phonemes
    if (phonemeAnalysis != null) {
      for (final p in phonemeAnalysis) {
        if (p.status == 'wrong' || p.status == 'missing') {
          _weakPhonemesErrors[p.phoneme] = (_weakPhonemesErrors[p.phoneme] ?? 0) + 1;
        }
      }
    }

    // 6. Save to disk/localStorage and notify all screens
    await _persistAll();
    notifyListeners();
    debugPrint(
      '[ProgressStorageService] Recorded sentence $sentenceId with score $score. '
      'TodayMinutes: $_todayMinutes, Streak: $_currentStreak, Total completed sentences: ${_sentenceScores.length}',
    );
  }

  // ==========================================
  // TOPIC & SENTENCE DATA ACCESS
  // ==========================================
  List<Topic> getTopics(List<Topic> baseTopics, List<TopicSentence> allBaseSentences) {
    return baseTopics.map((topic) {
      final topicSentences = allBaseSentences.where((s) => s.topicId == topic.id).toList();
      final total = topicSentences.length;

      // Count sentences in this topic that have achieved >= 70 score
      int completed = 0;
      for (final s in topicSentences) {
        final best = _sentenceScores[s.id] ?? s.userBestScore ?? 0;
        if (best >= 70) {
          completed++;
        }
      }

      return Topic(
        id: topic.id,
        nameEn: topic.nameEn,
        nameVi: topic.nameVi,
        iconName: topic.iconName,
        description: topic.description,
        totalSentences: total,
        completedSentences: completed,
      );
    }).toList();
  }

  List<TopicSentence> getTopicSentences(String topicId, List<TopicSentence> baseSentences) {
    return baseSentences.where((s) => s.topicId == topicId).map((s) {
      final best = _sentenceScores[s.id] ?? s.userBestScore;
      return TopicSentence(
        id: s.id,
        topicId: s.topicId,
        sentenceEn: s.sentenceEn,
        standardIpa: s.standardIpa,
        meaningVi: s.meaningVi,
        difficulty: s.difficulty,
        orderIndex: s.orderIndex,
        sampleAudioUrl: s.sampleAudioUrl,
        userBestScore: best,
      );
    }).toList();
  }

  // ==========================================
  // DISCIPLINE & STATISTICS ACCESS
  // ==========================================
  DisciplineStats getDisciplineStats() {
    return DisciplineStats(
      currentStreak: _currentStreak,
      longestStreak: _longestStreak,
      dailyGoalMinutes: _dailyGoalMinutes,
      todayMinutes: _todayMinutes,
      isTodayCompleted: _isTodayCompleted,
      reminderTime: _reminderTime,
      weeklyActiveDays: List.unmodifiable(_weeklyActiveDays),
    );
  }

  List<double> getWeeklyStudyMinutes() {
    return List.unmodifiable(_weeklyStudyMinutes);
  }

  List<double> getScoreTrends() {
    return List.unmodifiable(_scoreTrends);
  }

  List<TopicMasteryStat> getTopicMastery(List<Topic> baseTopics, List<TopicSentence> baseSentences) {
    return baseTopics.map((topic) {
      final sentences = baseSentences.where((s) => s.topicId == topic.id).toList();
      int completed = 0;
      int totalScore = 0;

      for (final s in sentences) {
        final score = _sentenceScores[s.id] ?? s.userBestScore ?? 0;
        if (score >= 70) completed++;
        totalScore += score;
      }

      final avg = sentences.isNotEmpty ? (totalScore / sentences.length).round() : 0;

      return TopicMasteryStat(
        topicId: topic.id,
        topicName: topic.nameVi,
        iconName: topic.iconName,
        averageScore: avg > 0 ? avg : 75,
        completedCount: completed,
        totalCount: sentences.length,
      );
    }).toList();
  }

  List<WeakPhonemeStat> getWeakPhonemes() {
    final sorted = _weakPhonemesErrors.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final top3 = sorted.take(3).toList();
    return top3.map((e) {
      final phoneme = e.key;
      final tip = PronunciationAssessmentEngine.vietnameseTips[phoneme] ??
          'Hãy nghe mẫu câu và luyện vị trí đặt lưỡi/môi.';
      final word = _exampleWordForPhoneme(phoneme);

      return WeakPhonemeStat(
        phoneme: phoneme,
        errorCount: e.value,
        exampleWord: word,
        tipVi: tip,
      );
    }).toList();
  }

  Future<void> updateDailyGoal(int minutes) async {
    _dailyGoalMinutes = minutes;
    if (_todayMinutes >= _dailyGoalMinutes) {
      _isTodayCompleted = true;
    }
    await _persistAll();
    notifyListeners();
  }

  Future<void> updateReminderTime(String time) async {
    _reminderTime = time;
    await _persistAll();
    notifyListeners();
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  String _exampleWordForPhoneme(String phoneme) {
    switch (phoneme) {
      case 'θ':
        return 'think (/θɪŋk/)';
      case 'ð':
        return 'this (/ðɪs/)';
      case 'ʃ':
        return 'station (/ˈsteɪ.ʃən/)';
      case 'ʒ':
        return 'vision (/ˈvɪʒ.ən/)';
      case 'tʃ':
        return 'much (/mʌtʃ/)';
      case 'dʒ':
        return 'job (/dʒɑːb/)';
      case 'æ':
        return 'have (/hæv/)';
      case 'iː':
        return 'meet (/miːt/)';
      case 's':
        return 'nice (/naɪs/)';
      case 't':
        return 'get (/ɡɛt/)';
      default:
        return 'word';
    }
  }
}

