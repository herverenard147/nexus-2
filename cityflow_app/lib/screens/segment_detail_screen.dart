import 'package:flutter/material.dart';
import '../models/prediction.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
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
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheetBorder),
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
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(pred.segmentNom)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.containerMargin),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Zone
            Text(pred.segmentZone,
                style: const TextStyle(
                    color: AppColors.onSurfaceVariant, fontSize: 13)),
            const SizedBox(height: AppSpacing.lg),
            // Score card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppRadius.cardBorder,
                boxShadow: AppShadows.card,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Score de congestion',
                      style: TextStyle(
                          fontSize: 13,
                          color: AppColors.onSurfaceVariant,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text('${pred.scorePredit}',
                          style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 48,
                              fontWeight: FontWeight.w700,
                              color: AppColors.trafficColor(pred.niveauRisque))),
                      const Text(' /100',
                          style: TextStyle(
                              fontSize: 16,
                              color: AppColors.onSurfaceVariant)),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  RiskBadge(niveau: pred.niveauRisque),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            // Facteurs
            const Text('Facteurs',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: AppColors.onSurface)),
            const SizedBox(height: AppSpacing.sm),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppRadius.cardBorder,
                boxShadow: AppShadows.card,
              ),
              child: Column(
                children: [
                  _FacteurTile(
                    label: 'Effet météo',
                    value: pred.facteurs['effet_meteo']?.toString() ?? '—',
                    icon: Icons.water_drop_outlined,
                  ),
                  const Divider(height: 1),
                  _FacteurTile(
                    label: 'Signalements actifs',
                    value:
                        pred.facteurs['effet_signalement']?.toString() ?? '—',
                    icon: Icons.add_alert_outlined,
                  ),
                  if (pred.facteurs['donnees_insuffisantes'] == true) ...[
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outlined,
                              color: AppColors.dense, size: 16),
                          const SizedBox(width: AppSpacing.xs),
                          const Expanded(
                            child: Text(
                              'Données historiques insuffisantes — prédiction approximative.',
                              style: TextStyle(
                                  color: AppColors.dense, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _openReportSheet(context),
                icon: const Icon(Icons.add_alert_outlined),
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
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 14, color: AppColors.onSurfaceVariant)),
          ),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: AppColors.onSurface)),
        ],
      ),
    );
  }
}
