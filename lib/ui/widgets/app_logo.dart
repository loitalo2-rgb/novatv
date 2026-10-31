import 'package:flutter/material.dart';

import '../../core/theme.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: compact ? 30 : 36,
          height: compact ? 30 : 36,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.accent, AppColors.violet],
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.play_arrow_rounded, color: Colors.black, size: compact ? 22 : 26),
        ),
        const SizedBox(width: 10),
        RichText(
          text: TextSpan(
            style: TextStyle(
              fontSize: compact ? 19 : 21,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              color: AppColors.text,
            ),
            children: const [
              TextSpan(text: 'NOVA'),
              TextSpan(text: 'TV', style: TextStyle(color: AppColors.accent)),
            ],
          ),
        ),
      ],
    );
  }
}
