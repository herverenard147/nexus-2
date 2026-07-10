import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/prediction.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/report_form_sheet.dart';

class SegmentDetailScreen extends StatelessWidget {
  final ApiService api;
  final Prediction prediction;

  const SegmentDetailScreen({
    super.key,
    required this.api,
    required this.prediction,
  });

  static const _badgeText = [
    Color(0xFF059669),
    Color(0xFFD97706),
    Color(0xFFDC2626),
  ];

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
    final niveau = pred.niveauRisque.clamp(0, 2);
    final trafficColor = AppColors.trafficColor(niveau);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 192,
            pinned: true,
            backgroundColor: trafficColor,
            foregroundColor: Colors.white,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            title: Text(
              pred.segmentNom,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: _HeroBackground(
                prediction: pred,
                niveau: niveau,
                trafficColor: trafficColor,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Section POURQUOI ? ──────────────────────────────────
                Container(
                  width: double.infinity,
                  color: const Color(0xFFEEF2FF),
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.lg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Label uppercase + icône
                      const Row(
                        children: [
                          Icon(Icons.analytics_outlined,
                              size: 16, color: AppColors.primary),
                          SizedBox(width: 6),
                          Text(
                            'POURQUOI ?',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.4,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      // Glass-cards des facteurs
                      _buildFactorCards(pred, niveau),
                      // Warning données insuffisantes
                      if (pred.facteurs['donnees_insuffisantes'] == true) ...[
                        const SizedBox(height: AppSpacing.xs),
                        _GlassCard(
                          child: Row(
                            children: const [
                              Icon(Icons.info_outlined,
                                  color: AppColors.dense, size: 16),
                              SizedBox(width: AppSpacing.xs),
                              Expanded(
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
                      const SizedBox(height: AppSpacing.sm),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'Modèle v${pred.versionModele}',
                          style: const TextStyle(
                              fontSize: 10, color: AppColors.outline),
                        ),
                      ),
                    ],
                  ),
                ),
                // ── Bouton signalement ──────────────────────────────────
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.containerMargin),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _openReportSheet(context),
                      icon: const Icon(Icons.add_alert_outlined),
                      label: const Text('Signaler un incident'),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(bottom: AppSpacing.lg),
                  child: Center(
                    child: Text(
                      '© OpenStreetMap contributors',
                      style:
                          TextStyle(fontSize: 10, color: AppColors.outline),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFactorCards(Prediction pred, int niveau) {
    final valueColor = _badgeText[niveau];
    final cards = <_FactorEntry>[];

    final hist = pred.facteurs['historique_moyen'];
    if (hist != null) {
      cards.add(_FactorEntry(
          icon: Icons.schedule_outlined,
          label: 'Trafic historique',
          value: hist));
    }

    final meteo = pred.facteurs['effet_meteo'];
    if (meteo != null) {
      cards.add(_FactorEntry(
          icon: Icons.water_drop_outlined,
          label: 'Conditions météo',
          value: meteo));
    }

    final sig = pred.facteurs['effet_signalement'];
    if (sig != null) {
      cards.add(_FactorEntry(
          icon: Icons.add_alert_outlined,
          label: 'Signalements actifs',
          value: sig));
    }

    if (cards.isEmpty) {
      cards.add(_FactorEntry(
          icon: Icons.bar_chart_outlined,
          label: 'Score calculé',
          value: '${pred.scorePredit}/100'));
    }

    return Column(
      children: [
        for (int i = 0; i < cards.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.xs),
          _GlassFactorCard(entry: cards[i], valueColor: valueColor),
        ],
      ],
    );
  }
}

// ── Data holder ────────────────────────────────────────────────────────────────

class _FactorEntry {
  final IconData icon;
  final String label;
  final dynamic value;
  const _FactorEntry(
      {required this.icon, required this.label, required this.value});
}

// ── Glass-card de base ─────────────────────────────────────────────────────────

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppRadius.cardBorder,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.8),
            borderRadius: AppRadius.cardBorder,
            border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
          ),
          child: child,
        ),
      ),
    );
  }
}

// ── Glass-card facteur ─────────────────────────────────────────────────────────

class _GlassFactorCard extends StatelessWidget {
  final _FactorEntry entry;
  final Color valueColor;

  const _GlassFactorCard(
      {required this.entry, required this.valueColor});

  String _format(dynamic v) {
    if (v == null) return '—';
    if (v is double) {
      if (v == 0) return 'neutre';
      final pct = (v * 100).round();
      return pct > 0 ? '+$pct%' : '$pct%';
    }
    if (v is int) {
      return v > 0 ? '+$v pts' : '$v pts';
    }
    return v.toString();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppRadius.cardBorder,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.8),
            borderRadius: AppRadius.cardBorder,
            border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
          ),
          child: Row(
            children: [
              Icon(entry.icon, size: 18, color: AppColors.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  entry.label,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: AppColors.onSurface,
                  ),
                ),
              ),
              Text(
                _format(entry.value),
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: valueColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Hero background ────────────────────────────────────────────────────────────

class _HeroBackground extends StatelessWidget {
  final Prediction prediction;
  final int niveau;
  final Color trafficColor;

  const _HeroBackground({
    required this.prediction,
    required this.niveau,
    required this.trafficColor,
  });

  static const _stateLabels = ['Fluide', 'Dense', 'Critique'];
  static const _badgeBg = [
    Color(0xFFECFDF5),
    Color(0xFFFFFBEB),
    Color(0xFFFEF2F2),
  ];
  static const _badgeText = [
    Color(0xFF059669),
    Color(0xFFD97706),
    Color(0xFFDC2626),
  ];

  @override
  Widget build(BuildContext context) {
    final stateLabel = _stateLabels[niveau];
    final badgeBg = _badgeBg[niveau];
    final badgeText = _badgeText[niveau];
    final topPad = MediaQuery.of(context).padding.top;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Fond dégradé couleur trafic
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primaryDeep,
                trafficColor.withValues(alpha: 0.85),
              ],
            ),
          ),
        ),
        // Overlay sombre en bas (from-black/60)
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0.35, 1.0],
              colors: [Colors.transparent, Color(0x99000000)],
            ),
          ),
        ),
        // Badge score flottant (haut-droite)
        Positioned(
          top: topPad + 14,
          right: AppSpacing.md,
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm, vertical: 5),
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text(
              '${prediction.scorePredit}%',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: badgeText,
              ),
            ),
          ),
        ),
        // Texte bas : nom + zone + état
        Positioned(
          left: AppSpacing.md,
          right: 80,
          bottom: AppSpacing.md,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                prediction.segmentNom,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                'Zone ${prediction.segmentZone}',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.75),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'État actuel : $stateLabel',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
