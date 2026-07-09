import 'package:flutter/material.dart';
import '../models/weather_alert.dart';
import '../theme/app_theme.dart';

/// Bandeau alerte météo — double codage : couleur bleue + icône goutte (WCAG).
class WeatherBanner extends StatelessWidget {
  final List<WeatherAlert> alerts;

  const WeatherBanner({super.key, required this.alerts});

  @override
  Widget build(BuildContext context) {
    if (alerts.isEmpty) return const SizedBox.shrink();
    final zones = alerts.map((a) => a.nom.isNotEmpty ? a.nom : a.zone).join(', ');
    return Container(
      width: double.infinity,
      color: AppColors.inondation,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      child: Row(
        children: [
          const Icon(Icons.water_drop, color: AppColors.onPrimary, size: 16),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              'Alerte inondation : $zones',
              style: const TextStyle(
                color: AppColors.onPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                fontFamily: 'Inter',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
