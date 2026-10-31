import 'package:flutter/material.dart';
import '../../../../core/services/model_audio_service.dart';
import '../../../../core/storage/progress_storage_service.dart';
import '../../data/repositories/practice_repository_impl.dart';
import '../../domain/entities/topic.dart';
import '../../domain/entities/topic_sentence.dart';
import '../../domain/repositories/practice_repository.dart';
import 'sentence_practice_screen.dart';

class TopicSentenceListScreen extends StatefulWidget {
  final Topic topic;

  const TopicSentenceListScreen({
    super.key,
    required this.topic,
  });

  @override
  State<TopicSentenceListScreen> createState() =>
      _TopicSentenceListScreenState();
}

class _TopicSentenceListScreenState extends State<TopicSentenceListScreen> {
  late final IPracticeRepository _practiceRepo;
  late final ModelAudioService _audioService;

  bool _isLoading = true;
  List<TopicSentence> _sentences = [];
  String? _currentlyPlayingId;

  @override
  void initState() {
    super.initState();
    _practiceRepo = PracticeRepositoryImpl();
    _audioService = ModelAudioService();
    ProgressStorageService().addListener(_onStorageChanged);
    _loadSentences();
  }

  void _onStorageChanged() {
    if (mounted) {
      _loadSentences();
    }
  }

  @override
  void dispose() {
    ProgressStorageService().removeListener(_onStorageChanged);
    super.dispose();
  }

  Future<void> _loadSentences() async {
    setState(() => _isLoading = true);
    final list = await _practiceRepo.getTopicSentences(widget.topic.id);
    setState(() {
      _sentences = list;
      _isLoading = false;
    });
  }

  void _playModelAudio(TopicSentence sentence) async {
    setState(() => _currentlyPlayingId = sentence.id);
    await _audioService.playSentence(
      text: sentence.sentenceEn,
      audioUrl: sentence.sampleAudioUrl,
      speed: AudioSpeed.normal,
    );
    if (mounted) {
      setState(() => _currentlyPlayingId = null);
    }
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return Colors.green.shade600;
      case 'medium':
        return Colors.orange.shade700;
      case 'hard':
        return Colors.red.shade600;
      default:
        return Colors.blue;
    }
  }

  String _getDifficultyText(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return 'Dễ';
      case 'medium':
        return 'Vừa';
      case 'hard':
        return 'Nâng cao';
      default:
        return 'Cơ bản';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktopOrWeb = screenWidth > 800;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.topic.nameVi),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktopOrWeb ? screenWidth * 0.15 : 20,
                vertical: 16,
              ),
              children: [
                // Topic summary header
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
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.chat_bubble_outline_rounded,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.topic.nameEn,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Gồm ${_sentences.length} câu giao tiếp thường gặp. Bấm loa để nghe mẫu trước khi luyện tập.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.outline,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // List of Sentences
                ..._sentences.asMap().entries.map((entry) {
                  final index = entry.key;
                  final sentence = entry.value;
                  final isPlaying = _currentlyPlayingId == sentence.id;
                  final hasScore = sentence.userBestScore != null;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 14),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: BorderSide(
                        color: theme.colorScheme.outlineVariant.withOpacity(0.5),
                      ),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SentencePracticeScreen(
                              sentence: sentence,
                              allSentences: _sentences,
                              currentIndex: index,
                            ),
                          ),
                        );
                        _loadSentences(); // Refresh score badges
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Badges Row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primary
                                            .withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'Câu #${sentence.orderIndex}',
                                        style: TextStyle(
                                          color: theme.colorScheme.primary,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: _getDifficultyColor(
                                                sentence.difficulty)
                                            .withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        _getDifficultyText(sentence.difficulty),
                                        style: TextStyle(
                                          color: _getDifficultyColor(
                                              sentence.difficulty),
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                // Best Score Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: hasScore
                                        ? Colors.green.shade50
                                        : theme.colorScheme.surfaceVariant,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: hasScore
                                          ? Colors.green.shade400
                                          : Colors.transparent,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        hasScore
                                            ? Icons.check_circle_rounded
                                            : Icons.mic_none_rounded,
                                        size: 14,
                                        color: hasScore
                                            ? Colors.green.shade700
                                            : theme.colorScheme.outline,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        hasScore
                                            ? '${sentence.userBestScore}%'
                                            : 'Chưa luyện',
                                        style: TextStyle(
                                          color: hasScore
                                              ? Colors.green.shade800
                                              : theme.colorScheme.outline,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Sentence Text & Quick Audio Button Row
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        sentence.sentenceEn,
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        sentence.meaningVi,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                          color: theme.colorScheme.outline,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),

                                // Quick Model Audio Preview Button
                                IconButton.filledTonal(
                                  tooltip: 'Nghe mẫu câu chuẩn',
                                  icon: isPlaying
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.volume_up_rounded),
                                  onPressed: () => _playModelAudio(sentence),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
    );
  }
}

