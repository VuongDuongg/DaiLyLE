import 'package:flutter/material.dart';
import '../../../../core/storage/progress_storage_service.dart';
import '../../data/repositories/practice_repository_impl.dart';
import '../../domain/entities/topic.dart';
import '../../domain/repositories/practice_repository.dart';
import 'topic_sentence_list_screen.dart';

class TopicListScreen extends StatefulWidget {
  const TopicListScreen({super.key});

  @override
  State<TopicListScreen> createState() => _TopicListScreenState();
}

class _TopicListScreenState extends State<TopicListScreen> {
  late final IPracticeRepository _practiceRepo;
  bool _isLoading = true;
  List<Topic> _topics = [];

  @override
  void initState() {
    super.initState();
    _practiceRepo = PracticeRepositoryImpl();
    ProgressStorageService().addListener(_onStorageChanged);
    _loadTopics();
  }

  void _onStorageChanged() {
    if (mounted) {
      _loadTopics();
    }
  }

  @override
  void dispose() {
    ProgressStorageService().removeListener(_onStorageChanged);
    super.dispose();
  }

  Future<void> _loadTopics() async {
    setState(() => _isLoading = true);
    final list = await _practiceRepo.getTopics();
    setState(() {
      _topics = list;
      _isLoading = false;
    });
  }

  IconData _getTopicIcon(String iconName) {
    switch (iconName) {
      case 'waving_hand':
        return Icons.waving_hand_rounded;
      case 'local_cafe':
        return Icons.local_cafe_rounded;
      case 'explore':
        return Icons.explore_rounded;
      case 'business_center':
        return Icons.business_center_rounded;
      default:
        return Icons.chat_bubble_rounded;
    }
  }

  Color _getTopicColor(int index) {
    const colors = [
      Color(0xFF2563EB), // Blue
      Color(0xFFD97706), // Amber
      Color(0xFF059669), // Emerald
      Color(0xFF7C3AED), // Violet
    ];
    return colors[index % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktopOrWeb = screenWidth > 800;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Luyện Phát Âm Theo Chủ Đề',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadTopics,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadTopics,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktopOrWeb ? screenWidth * 0.1 : 20,
                  vertical: 20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Banner introduction
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            theme.colorScheme.primary,
                            theme.colorScheme.tertiary,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.primary.withOpacity(0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.record_voice_over_rounded,
                                    color: Colors.white, size: 28),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Nghe Mẫu & Luyện Nói Từng Câu',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Chọn chủ đề để luyện nói các mẫu câu giao tiếp phổ biến. Nghe người bản xứ phát âm ở tốc độ chuẩn hoặc chậm 0.6x trước khi thu âm.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.white.withOpacity(0.92),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    Text(
                      'Danh Sách Chủ Đề Giao Tiếp',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Responsive Grid View
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: isDesktopOrWeb ? 3 : 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: isDesktopOrWeb ? 1.3 : 0.88,
                      ),
                      itemCount: _topics.length,
                      itemBuilder: (context, index) {
                        final topic = _topics[index];
                        final topicColor = _getTopicColor(index);

                        return Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: theme.colorScheme.outlineVariant.withOpacity(0.5),
                            ),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => TopicSentenceListScreen(
                                    topic: topic,
                                  ),
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Icon Badge & Count
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: topicColor.withOpacity(0.12),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          _getTopicIcon(topic.iconName),
                                          color: topicColor,
                                          size: 26,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.surfaceVariant,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          '${topic.totalSentences} câu',
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Spacer(),

                                  // Titles
                                  Text(
                                    topic.nameVi,
                                    style:
                                        theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    topic.nameEn,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.outline,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 12),

                                  // Progress Bar
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: LinearProgressIndicator(
                                      value: topic.progressPercentage,
                                      minHeight: 6,
                                      backgroundColor: theme
                                          .colorScheme.outlineVariant
                                          .withOpacity(0.3),
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          topicColor),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Đã hoàn thành',
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                          color: theme.colorScheme.outline,
                                          fontSize: 10,
                                        ),
                                      ),
                                      Text(
                                        '${topic.completedSentences}/${topic.totalSentences}',
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: topicColor,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

