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
                      // Phrase de synthèse
                      _GlassCard(
                        child: Text(
                          _synthesis(pred, niveau),
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _badgeText[niveau],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
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

  // ── Synthèse en langage naturel ──────────────────────────────────────────
  String _synthesis(Prediction pred, int niveau) {
    final meteo = pred.facteurs['effet_meteo'] as String? ?? 'aucun';
    final nbSig = (pred.facteurs['nb_signalements'] as num?)?.toInt() ?? 0;

    if (meteo == 'fort' && nbSig > 0) {
      return 'Fortes pluies sur une zone inondable et $nbSig signalement${nbSig > 1 ? 's' : ''} en cours — circulation très dégradée.';
    }
    if (meteo == 'fort') {
      return 'Fortes pluies sur une zone inondable — risque de blocage élevé.';
    }
    if (meteo == 'modéré' && nbSig > 0) {
      return 'Pluies modérées et $nbSig signalement${nbSig > 1 ? 's' : ''} actif${nbSig > 1 ? 's' : ''} — trafic perturbé.';
    }
    if (meteo == 'modéré') {
      return 'Pluies modérées en cours — impact sur la fluidité du trafic.';
    }
    if (nbSig > 0 && niveau == 2) {
      return 'Circulation bloquée : $nbSig signalement${nbSig > 1 ? 's' : ''} citoyen${nbSig > 1 ? 's' : ''} actif${nbSig > 1 ? 's' : ''} sur cet axe.';
    }
    if (nbSig > 0) {
      return '$nbSig signalement${nbSig > 1 ? 's' : ''} citoyen${nbSig > 1 ? 's' : ''} actif${nbSig > 1 ? 's' : ''} — trafic perturbé.';
    }
    if (niveau == 0) return 'Trafic fluide : aucun incident ni intempérie sur cet axe.';
    if (niveau == 1) return 'Trafic dense : affluence habituelle à cette heure.';
    return 'Circulation très chargée — évitez cet axe si possible.';
  }

  // ── Cartes de facteurs ────────────────────────────────────────────────────
  Widget _buildFactorCards(Prediction pred, int niveau) {
    final valueColor = _badgeText[niveau];
    final cards = <_FactorEntry>[];

    // Historique
    final hist = (pred.facteurs['historique_moyen'] as num?)?.toInt();
    cards.add(_FactorEntry(
      icon: Icons.schedule_outlined,
      label: 'Trafic historique (même heure)',
      value: hist != null ? '$hist / 100' : 'insuffisant',
    ));

    // Météo
    final meteo = pred.facteurs['effet_meteo'] as String? ?? 'aucun';
    final deltaMeteo = (pred.facteurs['delta_meteo_pts'] as num?)?.toInt() ?? 0;
    final meteoMsg = switch (meteo) {
      'fort' => 'Fortes pluies en cours${deltaMeteo > 0 ? ' : +$deltaMeteo pts' : ''}',
      'modéré' => 'Pluies modérées${deltaMeteo > 0 ? ' : +$deltaMeteo pts' : ''}',
      _ => 'Pas de pluie signalée sur cet axe',
    };
    cards.add(_FactorEntry(
      icon: meteo == 'aucun'
          ? Icons.wb_sunny_outlined
          : Icons.water_drop_outlined,
      label: 'Conditions météo',
      value: meteoMsg,
    ));

    // Signalements
    final nbSig = (pred.facteurs['nb_signalements'] as num?)?.toInt() ?? 0;
    final deltaSig = (pred.facteurs['delta_signalement_pts'] as num?)?.toInt() ?? 0;
    final sigMsg = nbSig == 0
        ? 'Aucun incident signalé récemment'
        : '$nbSig signalement${nbSig > 1 ? 's' : ''} actif${nbSig > 1 ? 's' : ''}${deltaSig > 0 ? ' : +$deltaSig pts' : ''}';
    cards.add(_FactorEntry(
      icon: nbSig == 0 ? Icons.check_circle_outline : Icons.add_alert_outlined,
      label: 'Signalements citoyens',
      value: sigMsg,
    ));

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

  const _GlassFactorCard({required this.entry, required this.valueColor});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppRadius.cardBorder,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.8),
            borderRadius: AppRadius.cardBorder,
            border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(entry.icon, size: 16, color: AppColors.primary),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.label,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.onSurfaceVariant,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      entry.value.toString(),
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: valueColor,
                      ),
                    ),
                  ],
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
