import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/audio/speech_recorder_service.dart';
import '../../../../core/services/model_audio_service.dart';
import '../../../../core/speech/speech_transcription_service.dart';
import '../../../../core/ai/pronunciation_assessment_engine.dart';
import '../../../pronunciation/domain/entities/assessment_result.dart';
import '../../../pronunciation/presentation/widgets/waveform_mic_button.dart';
import '../../data/repositories/practice_repository_impl.dart';
import '../../domain/entities/topic_sentence.dart';
import '../../domain/repositories/practice_repository.dart';

class SentencePracticeScreen extends StatefulWidget {
  final TopicSentence sentence;
  final List<TopicSentence> allSentences;
  final int currentIndex;

  const SentencePracticeScreen({
    super.key,
    required this.sentence,
    required this.allSentences,
    required this.currentIndex,
  });

  @override
  State<SentencePracticeScreen> createState() => _SentencePracticeScreenState();
}

class _SentencePracticeScreenState extends State<SentencePracticeScreen> {
  late final ISpeechRecorderService _recorderService;
  late final ModelAudioService _modelAudioService;
  late final IPracticeRepository _practiceRepo;
  late final SpeechTranscriptionService _transcriptionService;
  late final PronunciationAssessmentEngine _assessmentEngine;

  late TopicSentence _currentSentence;
  late int _currentIndex;

  bool _isRecording = false;
  bool _isProcessing = false;
  RecordedAudioResult? _capturedAudio;
  AssessmentResult? _assessmentResult;
  String? _recognizedSpokenText;
  String? _errorMessage;

  // Active audio feedback states
  bool _isPlayingModel = false;
  bool _isPlayingUser = false;

  @override
  void initState() {
    super.initState();
    _currentSentence = widget.sentence;
    _currentIndex = widget.currentIndex;

    _recorderService = SpeechRecorderService();
    _modelAudioService = ModelAudioService();
    _practiceRepo = PracticeRepositoryImpl();
    _transcriptionService = SpeechTranscriptionService();
    _assessmentEngine = PronunciationAssessmentEngine();

    _modelAudioService.isPlayingNotifier.addListener(_onAudioPlaybackStateChanged);
  }

  void _onAudioPlaybackStateChanged() {
    if (mounted) {
      setState(() {
        if (!_modelAudioService.isPlayingNotifier.value) {
          _isPlayingModel = false;
          _isPlayingUser = false;
        }
      });
    }
  }

  @override
  void dispose() {
    _modelAudioService.isPlayingNotifier.removeListener(_onAudioPlaybackStateChanged);
    _modelAudioService.stopAllPlayback();
    _recorderService.dispose();
    super.dispose();
  }

  // ==========================================
  // MODEL AUDIO CONTROL (BEFORE & AFTER SPEAKING)
  // ==========================================
  Future<void> _playModelAudio(AudioSpeed speed) async {
    setState(() => _isPlayingModel = true);
    await _modelAudioService.playSentence(
      text: _currentSentence.sentenceEn,
      audioUrl: _currentSentence.sampleAudioUrl,
      speed: speed,
    );
  }

  Future<void> _playUserRecording() async {
    final audio = _capturedAudio;
    if (audio == null) return;
    setState(() => _isPlayingUser = true);

    try {
      await _modelAudioService.playUserRecording(
        audio.localPath,
        bytes: audio.bytes,
        mimeType: audio.mimeType,
      );
    } catch (e) {
      debugPrint('[SentencePracticeScreen] _playUserRecording error: $e');
      if (mounted) {
        setState(() => _isPlayingUser = false);
      }
    }
  }

  // ==========================================
  // SPEECH CAPTURE & AI GRADING PIPELINE
  // ==========================================
  Future<void> _startRecording() async {
    // 1. AUTO-STOP: Stop any active TTS or model audio playback immediately
    await _modelAudioService.stopAllPlayback();

    setState(() {
      _errorMessage = null;
      _isPlayingModel = false;
      _isPlayingUser = false;
    });

    try {
      final permitted = await _recorderService.hasPermission();
      if (!permitted) {
        setState(() {
          _errorMessage =
              'Chưa cấp quyền Microphone. Vui lòng cho phép trình duyệt truy cập micro trên thanh địa chỉ.';
          _isRecording = false;
        });
        return;
      }

      await _recorderService.startRecording();
      _transcriptionService.start();
      setState(() {
        _isRecording = true;
        _recognizedSpokenText = null;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Không thể bắt đầu ghi âm: $e';
        _isRecording = false;
      });
    }
  }

  Future<void> _stopRecordingAndAssess() async {
    setState(() {
      _isRecording = false;
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final audioResultFuture = _recorderService.stopRecording();
      final transcriptFuture = _transcriptionService.stop();

      final audioResult = await audioResultFuture;
      final recognizedText = await transcriptFuture;

      if (audioResult == null) {
        setState(() {
          _isProcessing = false;
          _errorMessage = 'Bản ghi âm quá ngắn hoặc không có âm thanh.';
        });
        return;
      }

      _capturedAudio = audioResult;
      _recognizedSpokenText = recognizedText;

      // Real AI evaluation using Needleman-Wunsch Alignment & Acoustic duration
      final assessment = _assessmentEngine.evaluate(
        audioResult: audioResult,
        targetSentence: _currentSentence.sentenceEn,
        standardIpa: _currentSentence.standardIpa,
        recognizedText: recognizedText,
      );

      // Save best score to database & local persistent storage
      await _practiceRepo.saveSentenceAttempt(
        sentenceId: _currentSentence.id,
        score: assessment.overallScore,
        topicId: _currentSentence.topicId,
        phonemeAnalysis: assessment.words
            .expand((w) => w.phonemeAnalysis)
            .toList(),
      );

      setState(() {
        _assessmentResult = assessment;
        _isProcessing = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Lỗi phân tích phát âm: $e';
        _isProcessing = false;
      });
    }
  }

  void _onWordChipTapped(WordAssessment wordItem) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Word & Score header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        wordItem.word,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '/${wordItem.expectedIpa}/',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getWordScoreColor(wordItem.score).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${wordItem.score}%',
                      style: TextStyle(
                        color: _getWordScoreColor(wordItem.score),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Button: "🔊 Nghe từ này"
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.tonalIcon(
                  onPressed: () {
                    _modelAudioService.speakSingleWord(wordItem.word);
                  },
                  icon: const Icon(Icons.volume_up_rounded),
                  label: Text('Nghe phát âm từ "${wordItem.word}"'),
                ),
              ),
              const SizedBox(height: 16),

              // Phoneme breakdown details
              Text(
                'Phân tích ngữ âm chi tiết:',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              ...wordItem.phonemeAnalysis.map((p) {
                final isWrong = p.status == 'wrong' || p.status == 'missing';
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isWrong
                        ? Colors.red.shade50
                        : theme.colorScheme.surfaceVariant.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isWrong ? Colors.red.shade200 : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isWrong ? Colors.red.shade100 : Colors.green.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '/${p.phoneme}/',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isWrong ? Colors.red.shade800 : Colors.green.shade800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          isWrong
                              ? (p.tip ?? 'Cần chú ý khẩu hình miệng cho âm này.')
                              : 'Phát âm chuẩn xác.',
                          style: TextStyle(
                            fontSize: 13,
                            color: isWrong ? Colors.red.shade900 : theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  void _nextSentence() {
    if (_currentIndex < widget.allSentences.length - 1) {
      final nextIdx = _currentIndex + 1;
      setState(() {
        _currentIndex = nextIdx;
        _currentSentence = widget.allSentences[nextIdx];
        _capturedAudio = null;
        _assessmentResult = null;
        _isRecording = false;
        _isProcessing = false;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🎉 Chúc mừng! Bạn đã hoàn thành tất cả các câu trong chủ đề này.')),
      );
    }
  }

  void _retrySentence() {
    setState(() {
      _capturedAudio = null;
      _assessmentResult = null;
      _isRecording = false;
      _isProcessing = false;
    });
  }

  Color _getWordScoreColor(int score) {
    if (score >= 80) return Colors.green.shade600;
    if (score >= 50) return Colors.orange.shade700;
    return Colors.red.shade600;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktopOrWeb = screenWidth > 800;
    final hasResult = _assessmentResult != null;

    return Scaffold(
      appBar: AppBar(
        title: Text('Câu #${_currentSentence.orderIndex}'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            tooltip: 'Hướng dẫn',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Nghe mẫu chuẩn 1.0x hoặc chậm 0.6x trước khi thu âm để đạt điểm tối đa!'),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: isDesktopOrWeb ? screenWidth * 0.18 : 20,
          vertical: 16,
        ),
        child: Column(
          children: [
            // ==========================================
            // 1. SENTENCE PROMPT CARD (Always visible)
            // ==========================================
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
                side: BorderSide(
                  color: theme.colorScheme.outlineVariant.withOpacity(0.5),
                ),
              ),
              color: theme.colorScheme.surfaceVariant.withOpacity(0.35),
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  children: [
                    // Target English Sentence
                    Text(
                      _currentSentence.sentenceEn,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Model Audio Control Bar (Normal 1.0x & Slow 0.6x)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FilledButton.tonalIcon(
                          onPressed: _isRecording
                              ? null
                              : () => _playModelAudio(AudioSpeed.normal),
                          icon: _isPlayingModel
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.volume_up_rounded, size: 20),
                          label: const Text('Nghe mẫu (1.0x)'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: _isRecording
                              ? null
                              : () => _playModelAudio(AudioSpeed.slow),
                          icon: const Text('🐢', style: TextStyle(fontSize: 16)),
                          label: const Text('Nghe chậm (0.6x)'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ==========================================
            // 2. LOCKED REVEAL AREA (Before Speaking)
            // ==========================================
            if (!hasResult) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withOpacity(0.8),
                    style: BorderStyle.solid,
                  ),
                  color: theme.colorScheme.surface,
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.lock_clock_rounded,
                      size: 36,
                      color: theme.colorScheme.primary.withOpacity(0.8),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Khóa Nội Dung Cho Đến Khi Bạn Nói',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Hãy bấm thu âm và đọc câu trên để mở khóa:\n1. Nghĩa tiếng Việt đầy đủ\n2. Phiên âm chuẩn IPA\n3. Chấm điểm AI & Phân tích từng từ',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // ==========================================
            // 3. POST-SPEECH REVEAL CARD (After Speaking)
            // ==========================================
            if (hasResult) ...[
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withOpacity(0.5),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 3A: REVEALED MEANING & STANDARD IPA
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.amber.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.translate_rounded, color: Colors.orange, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Nghĩa tiếng Việt:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade900,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _currentSentence.meaningVi,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.orange.shade900,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Phiên âm chuẩn (IPA):',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade900,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            _currentSentence.standardIpa,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 3B: AUDIO COMPARISON BAR (Listen to model vs Listen to your own voice)
                    Text(
                      'Đối chiếu giọng đọc:',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _playModelAudio(AudioSpeed.normal),
                            icon: const Icon(Icons.volume_up_rounded, size: 18),
                            label: const Text('Giọng mẫu'),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.tonalIcon(
                            onPressed: _playUserRecording,
                            icon: _isPlayingUser
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.headphones_rounded, size: 18),
                            label: const Text('Giọng của bạn'),
                            style: FilledButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // 3C: INTERACTIVE COLOR-CODED WORD CHIPS
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Chi tiết từng từ (Chạm để nghe âm):',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    Wrap(
                      spacing: 8,
                      runSpacing: 10,
                      children: _assessmentResult!.words.map((w) {
                        final chipColor = _getWordScoreColor(w.score);
                        return InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _onWordChipTapped(w),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: chipColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: chipColor.withOpacity(0.5), width: 1.5),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  w.word,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: chipColor,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(Icons.volume_up_rounded, size: 14, color: chipColor),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // 3D: OVERALL SCORE & FEEDBACK
                    Row(
                      children: [
                        Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            color: _getWordScoreColor(_assessmentResult!.overallScore)
                                .withOpacity(0.12),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _getWordScoreColor(_assessmentResult!.overallScore),
                              width: 2.5,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              '${_assessmentResult!.overallScore}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: _getWordScoreColor(_assessmentResult!.overallScore),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _assessmentResult!.overallFeedback,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Container(
                                margin: const EdgeInsets.only(top: 6),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: (_recognizedSpokenText != null &&
                                          _recognizedSpokenText!.isNotEmpty)
                                      ? theme.colorScheme.primaryContainer
                                          .withOpacity(0.4)
                                      : Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  (_recognizedSpokenText != null &&
                                          _recognizedSpokenText!.isNotEmpty)
                                      ? 'AI nghe được: "$_recognizedSpokenText"'
                                      : 'AI không nhận diện được từ tiếng Anh nào',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                    color: (_recognizedSpokenText != null &&
                                            _recognizedSpokenText!.isNotEmpty)
                                        ? theme.colorScheme.primary
                                        : Colors.red.shade800,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // NAVIGATION ACTIONS: Retry & Next Sentence
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _retrySentence,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Thử lại'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _nextSentence,
                            icon: const Icon(Icons.arrow_forward_rounded),
                            label: const Text('Câu tiếp theo'),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 28),

            // ==========================================
            // 4. MICROPHONE RECORDING CONTROLLER
            // ==========================================
            Center(
              child: Column(
                children: [
                  WaveformMicButton(
                    isRecording: _isRecording,
                    isProcessing: _isProcessing,
                    onStart: _startRecording,
                    onStop: _stopRecordingAndAssess,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _isProcessing
                        ? 'AI đang phân tích ngữ âm...'
                        : _isRecording
                            ? 'Đang nghe... Nhấn lại để hoàn thành'
                            : hasResult
                                ? 'Nhấn mic để luyện nói lại câu này'
                                : 'Nhấn mic để bắt đầu luyện nói',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: _isRecording
                          ? theme.colorScheme.error
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: theme.colorScheme.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: theme.colorScheme.onErrorContainer),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

