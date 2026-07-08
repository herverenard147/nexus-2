import 'package:flutter/material.dart';
import '../models/prediction.dart';
import '../services/api_service.dart';
import '../widgets/risk_badge.dart';
import '../widgets/report_form_sheet.dart';

class SegmentDetailScreen extends StatelessWidget {
  final ApiService api;
  final Prediction prediction;

  const SegmentDetailScreen({
    super.key,
    required this.api,
    required this.prediction,
  });

  void _openReportSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => ReportFormSheet(
        api: api,
        segmentId: prediction.segmentId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pred = prediction;
    return Scaffold(
      appBar: AppBar(title: Text(pred.segmentNom)),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(pred.segmentZone,
                style: const TextStyle(color: Colors.grey, fontSize: 14)),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('Congestion prédite : ',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text('${pred.scorePredit}/100'),
              ],
            ),
            const SizedBox(height: 8),
            RiskBadge(niveau: pred.niveauRisque),
            const SizedBox(height: 24),
            const Text('Facteurs',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            _FacteurTile(
              label: 'Effet météo',
              value: pred.facteurs['effet_meteo']?.toString() ?? '—',
              icon: Icons.water_drop,
            ),
            _FacteurTile(
              label: 'Signalements actifs',
              value: pred.facteurs['effet_signalement']?.toString() ?? '—',
              icon: Icons.report_problem,
            ),
            if (pred.facteurs['donnees_insuffisantes'] == true)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  '⚠ Données historiques insuffisantes — prédiction approximative.',
                  style: TextStyle(color: Colors.orange, fontSize: 12),
                ),
              ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _openReportSheet(context),
                icon: const Icon(Icons.add_alert),
                label: const Text('Signaler un incident'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FacteurTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _FacteurTile(
      {required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 8),
          Text('$label : '),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
