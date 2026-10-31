import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../domain/entities/assessment_result.dart';
import 'phoneme_bottom_sheet.dart';

class RichPhonemeText extends StatelessWidget {
  final List<WordAssessment> words;
  final Function(String phoneme, String actual, String? tip)? onPhonemeTapped;

  const RichPhonemeText({
    super.key,
    required this.words,
    this.onPhonemeTapped,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // English Words Row
        Wrap(
          spacing: 10,
          runSpacing: 12,
          children: words.map((word) {
            final wordScore = word.score;
            Color wordColor = Colors.green;
            if (wordScore < 60) {
              wordColor = Colors.red.shade700;
            } else if (wordScore < 80) {
              wordColor = Colors.orange.shade800;
            }

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: wordColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: wordColor.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  // English Word Text
                  Text(
                    word.word,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Color-coded IPA Phonemes via RichText TextSpans
                  RichText(
                    text: TextSpan(
                      children: [
                        const TextSpan(
                          text: '/',
                          style: TextStyle(color: Colors.grey, fontSize: 15),
                        ),
                        ...word.phonemeAnalysis.map((p) {
                          Color phonemeColor;
                          TextDecoration decoration = TextDecoration.none;
                          FontWeight fontWeight = FontWeight.w600;

                          if (p.isCorrect) {
                            phonemeColor = Colors.green.shade700;
                          } else if (p.status == 'almost') {
                            phonemeColor = Colors.orange.shade800;
                          } else {
                            // 'wrong' or 'missing'
                            phonemeColor = Colors.red.shade700;
                            decoration = TextDecoration.underline;
                            fontWeight = FontWeight.bold;
                          }

                          return TextSpan(
                            text: p.phoneme == '-' ? '(${p.actual})' : p.phoneme,
                            style: TextStyle(
                              color: phonemeColor,
                              fontSize: 16,
                              fontWeight: fontWeight,
                              decoration: decoration,
                              decorationColor: phonemeColor,
                              decorationThickness: 2,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () {
                                if (!p.isCorrect) {
                                  if (onPhonemeTapped != null) {
                                    onPhonemeTapped!(p.phoneme, p.actual, p.tip);
                                  } else {
                                    PhonemeBottomSheet.show(
                                      context,
                                      phoneme: p.phoneme,
                                      actualSpoken: p.actual,
                                      tip: p.tip,
                                    );
                                  }
                                }
                              },
                          );
                        }),
                        const TextSpan(
                          text: '/',
                          style: TextStyle(color: Colors.grey, fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 12),
        // Helper note
        Row(
          children: [
            Icon(Icons.touch_app_rounded, size: 16, color: theme.colorScheme.primary),
            const SizedBox(width: 6),
            Text(
              'Chạm vào âm màu đỏ/gạch chân để xem khẩu hình miệng chuẩn',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

