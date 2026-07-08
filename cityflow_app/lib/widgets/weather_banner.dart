import 'package:flutter/material.dart';
import '../models/weather_alert.dart';

/// Étape 4.16 — bandeau alerte météo (double codage : couleur bleue + icône goutte).
class WeatherBanner extends StatelessWidget {
  final List<WeatherAlert> alerts;

  const WeatherBanner({super.key, required this.alerts});

  @override
  Widget build(BuildContext context) {
    if (alerts.isEmpty) return const SizedBox.shrink();
    final zones = alerts.map((a) => a.nom.isNotEmpty ? a.nom : a.zone).join(', ');
    return Container(
      width: double.infinity,
      color: const Color(0xFF1565C0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.water_drop, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Alerte inondation : $zones',
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
