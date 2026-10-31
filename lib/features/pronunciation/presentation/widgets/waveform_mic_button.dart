import 'dart:math' as math;
import 'package:flutter/material.dart';

class WaveformMicButton extends StatefulWidget {
  final bool isRecording;
  final bool isProcessing;
  final VoidCallback onStart;
  final VoidCallback onStop;

  const WaveformMicButton({
    super.key,
    required this.isRecording,
    required this.isProcessing,
    required this.onStart,
    required this.onStop,
  });

  @override
  State<WaveformMicButton> createState() => _WaveformMicButtonState();
}

class _WaveformMicButtonState extends State<WaveformMicButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
  }

  @override
  void didUpdateWidget(covariant WaveformMicButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRecording && !_animationController.isAnimating) {
      _animationController.repeat();
    } else if (!widget.isRecording && _animationController.isAnimating) {
      _animationController.stop();
      _animationController.reset();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isProcessing) {
      return Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        if (widget.isRecording) {
          widget.onStop();
        } else {
          widget.onStart();
        }
      },
      child: SizedBox(
        width: 120,
        height: 120,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Outer animated ripple rings when recording
            if (widget.isRecording)
              AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return CustomPaint(
                    size: const Size(120, 120),
                    painter: _WaveformRipplePainter(
                      progress: _animationController.value,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  );
                },
              ),

            // Central Mic Button
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: widget.isRecording ? 76 : 70,
              height: widget.isRecording ? 76 : 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.isRecording
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.primary,
                boxShadow: [
                  BoxShadow(
                    color: (widget.isRecording
                            ? Theme.of(context).colorScheme.error
                            : Theme.of(context).colorScheme.primary)
                        .withOpacity(0.35),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(
                widget.isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                color: Colors.white,
                size: 36,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WaveformRipplePainter extends CustomPainter {
  final double progress;
  final Color color;

  _WaveformRipplePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    for (int i = 0; i < 2; i++) {
      final ringProgress = (progress + (i * 0.5)) % 1.0;
      final radius = 38 + (ringProgress * (maxRadius - 38));
      final opacity = (1.0 - ringProgress).clamp(0.0, 1.0);

      final paint = Paint()
        ..color = color.withOpacity(opacity * 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformRipplePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

