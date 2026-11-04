import 'package:flutter/material.dart';

import '../theme.dart';

/// Titik lokasi user dengan efek "pulse".
class PulseDot extends StatelessWidget {
  const PulseDot({super.key, required this.animation, this.color = AppColors.primary});
  final Animation<double> animation;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = animation.value;
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 20 + 50 * t,
              height: 20 + 50 * t,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: (1 - t) * 0.45),
              ),
            ),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [BoxShadow(color: color, blurRadius: 10)],
              ),
            ),
          ],
        );
      },
    );
  }
}

