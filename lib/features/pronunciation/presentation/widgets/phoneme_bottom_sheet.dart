import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/supabase_tables.dart';
import '../../../lessons/domain/lesson_sentence.dart';

class PhonemeBottomSheet extends StatefulWidget {
  final String phoneme;
  final String actualSpoken;
  final String? tip;
  final Function(LessonSentence selectedLesson)? onSelectLesson;

  const PhonemeBottomSheet({
    super.key,
    required this.phoneme,
    required this.actualSpoken,
    this.tip,
    this.onSelectLesson,
  });

  static void show(
    BuildContext context, {
    required String phoneme,
    required String actualSpoken,
    String? tip,
    Function(LessonSentence selectedLesson)? onSelectLesson,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PhonemeBottomSheet(
        phoneme: phoneme,
        actualSpoken: actualSpoken,
        tip: tip,
        onSelectLesson: onSelectLesson,
      ),
    );
  }

  @override
  State<PhonemeBottomSheet> createState() => _PhonemeBottomSheetState();
}

class _PhonemeBottomSheetState extends State<PhonemeBottomSheet> {
  bool _isLoadingLessons = false;
  List<LessonSentence> _drillLessons = [];

  Future<void> _fetchDrillLessons() async {
    setState(() => _isLoadingLessons = true);
    try {
      final supabase = Supabase.instance.client;
      // Query target sentences focused on this mispronounced phoneme
      final response = await supabase
          .from(SupabaseTables.lessonsAndSentences)
          .select()
          .ilike('target_phoneme', '%${widget.phoneme}%')
          .limit(5);

      final list = (response as List<dynamic>)
          .map((data) => LessonSentence.fromJson(data as Map<String, dynamic>))
          .toList();

      setState(() {
        _drillLessons = list.isNotEmpty
            ? list
            : [
                LessonSentence(
                  id: 'sample-2',
                  category: 'consonants',
                  targetText: 'This brother breathes together with that mother.',
                  standardIpa: '/ðɪs ˈbrʌð.ər briːðz təˈɡɛð.ər wɪð ðæt ˈmʌð.ər/',
                  difficultyLevel: 'intermediate',
                  targetPhoneme: widget.phoneme,
                  createdAt: DateTime.now(),
                ),
              ];
        _isLoadingLessons = false;
      });
    } catch (e) {
      debugPrint('[PhonemeBottomSheet] Error loading drill lessons: $e');
      setState(() {
        _drillLessons = [
          LessonSentence(
            id: 'sample-2',
            category: 'consonants',
            targetText: 'This brother breathes together with that mother.',
            standardIpa: '/ðɪs ˈbrʌð.ər briːðz təˈɡɛð.ər wɪð ðæt ˈmʌð.ər/',
            difficultyLevel: 'intermediate',
            targetPhoneme: widget.phoneme,
            createdAt: DateTime.now(),
          ),
        ];
        _isLoadingLessons = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Title & Phoneme Badges
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '/${widget.phoneme}/',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hướng dẫn sửa âm /${widget.phoneme}/',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      widget.actualSpoken == '-'
                          ? 'Bạn đã bỏ quên phụ âm này'
                          : 'Bạn đã phát âm nhầm thành: /${widget.actualSpoken}/',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Vietnamese Mouth & Tongue Position Guide
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withOpacity(0.5),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.record_voice_over_rounded,
                  color: theme.colorScheme.primary,
                  size: 26,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.tip ??
                        'Hãy đặt đầu lưỡi đúng vị trí, thả lỏng quai hàm và điều chỉnh luồng hơi chậm rãi theo âm thanh mẫu.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Action Button: "Luyện tập các từ chứa âm này"
          if (_drillLessons.isEmpty) ...[
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                onPressed: _isLoadingLessons ? null : _fetchDrillLessons,
                icon: _isLoadingLessons
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.fitness_center_rounded),
                label: const Text(
                  'Luyện tập các từ chứa âm này',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ] else ...[
            Text(
              'Các câu luyện tập đề xuất:',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ..._drillLessons.map(
              (lesson) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text(
                    lesson.targetPhoneme,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                title: Text(
                  lesson.targetText,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(lesson.standardIpa),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                onTap: () {
                  Navigator.pop(context);
                  widget.onSelectLesson?.call(lesson);
                },
              ),
            ),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

