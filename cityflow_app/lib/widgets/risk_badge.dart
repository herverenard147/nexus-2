import 'package:flutter/material.dart';

/// Double codage couleur + icône/texte pour l'accessibilité daltoniens (WCAG).
class RiskBadge extends StatelessWidget {
  final int niveau; // 0=fluide, 1=modéré, 2=critique

  const RiskBadge({super.key, required this.niveau});

  static const _colors = [Color(0xFF2E7D32), Color(0xFFF57F17), Color(0xFFC62828)];
  static const _icons = [Icons.check_circle, Icons.warning, Icons.cancel];
  static const _labels = ['Fluide', 'Modéré', 'Critique'];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(_icons[niveau], color: _colors[niveau], size: 18),
        const SizedBox(width: 4),
        Text(
          _labels[niveau],
          style: TextStyle(
            color: _colors[niveau],
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}
