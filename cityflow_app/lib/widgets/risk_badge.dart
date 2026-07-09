import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Double codage couleur + icône/texte pour l'accessibilité daltoniens (WCAG).
class RiskBadge extends StatelessWidget {
  final int niveau; // 0=fluide, 1=dense, 2=bloqué

  const RiskBadge({super.key, required this.niveau});

  static const _colors = [AppColors.fluide, AppColors.dense, AppColors.bloque];
  static const _icons = [Icons.check_circle, Icons.warning, Icons.cancel];
  static const _labels = ['Fluide', 'Dense', 'Bloqué'];

  @override
  Widget build(BuildContext context) {
    final color = _colors[niveau.clamp(0, 2)];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppRadius.chipBorder,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icons[niveau.clamp(0, 2)], color: color, size: 14),
          const SizedBox(width: 4),
          Text(
            _labels[niveau.clamp(0, 2)],
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
              fontFamily: 'Inter',
            ),
          ),
        ],
      ),
    );
  }
}
