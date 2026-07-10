import 'package:flutter/material.dart';
import '../models/prediction.dart';
import '../models/weather_alert.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/weather_banner.dart';
import 'segment_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  final ApiService api;
  const HomeScreen({super.key, required this.api});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Prediction>? _predictions;
  List<WeatherAlert> _alerts = [];
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        widget.api.getPredictions(),
        widget.api.getWeatherAlerts(),
      ]);
      setState(() {
        _predictions = results[0] as List<Prediction>;
        _alerts = results[1] as List<WeatherAlert>;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        WeatherBanner(alerts: _alerts),
        Expanded(child: _buildBody(context)),
        const Padding(
          padding: EdgeInsets.all(4),
          child: Text(
            '© OpenStreetMap contributors',
            style: TextStyle(fontSize: 10, color: AppColors.outline),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: AppSpacing.md),
            Text('Chargement des prédictions…',
                style: TextStyle(color: AppColors.onSurfaceVariant)),
          ],
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.containerMargin),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.bloque),
              const SizedBox(height: AppSpacing.sm),
              const Text('Impossible de charger les données.',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(_error!,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.onSurfaceVariant),
                  textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.md),
              ElevatedButton(onPressed: _load, child: const Text('Réessayer')),
            ],
          ),
        ),
      );
    }
    if (_predictions == null || _predictions!.isEmpty) {
      return const Center(
        child: Text('Aucune prédiction disponible.',
            style: TextStyle(color: AppColors.onSurfaceVariant)),
      );
    }

    final alertZones = _alerts.map((a) => a.zone).toSet();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, AppSpacing.lg, AppSpacing.md, AppSpacing.md),
        itemCount: _predictions!.length + 1,
        itemBuilder: (ctx, i) {
          if (i == 0) return _buildHeader(context);
          final pred = _predictions![i - 1];
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: _SegmentCard(
              prediction: pred,
              hasWeatherAlert: alertZones.contains(pred.segmentZone),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SegmentDetailScreen(
                    api: widget.api,
                    prediction: pred,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Prédictions',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 4),
          const Text(
            'Prévisions de trafic en temps réel',
            style: TextStyle(fontSize: 14, color: AppColors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _SegmentCard extends StatelessWidget {
  final Prediction prediction;
  final bool hasWeatherAlert;
  final VoidCallback onTap;

  const _SegmentCard({
    required this.prediction,
    required this.hasWeatherAlert,
    required this.onTap,
  });

  // Couleurs des badges pill (fond teinté / texte) par niveau de risque
  static const _badgeBg = [
    Color(0xFFECFDF5), // fluide — emerald-50
    Color(0xFFFFFBEB), // dense  — amber-50
    Color(0xFFFEF2F2), // bloqué — red-50
  ];
  static const _badgeText = [
    Color(0xFF059669), // fluide — emerald-600
    Color(0xFFD97706), // dense  — amber-600
    Color(0xFFDC2626), // bloqué — red-600
  ];
  static const _labels = ['Fluide', 'Dense', 'Bloqué'];
  static const _trendIcons = [
    Icons.trending_down,
    Icons.trending_flat,
    Icons.trending_up,
  ];

  @override
  Widget build(BuildContext context) {
    final niveau = prediction.niveauRisque.clamp(0, 2);
    final isCritique = niveau == 2;
    final bgColor = _badgeBg[niveau];
    final textColor = _badgeText[niveau];

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardBorder,
        boxShadow: AppShadows.card,
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Accent gauche rouge sur les segments critiques
                if (isCritique)
                  Container(width: 4, color: AppColors.bloque),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      isCritique ? AppSpacing.sm : AppSpacing.md,
                      AppSpacing.md,
                      AppSpacing.md,
                      AppSpacing.md,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Ligne haute : nom+zone / badge
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          prediction.segmentNom,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                            color: AppColors.onSurface,
                                          ),
                                        ),
                                      ),
                                      if (hasWeatherAlert) ...[
                                        const SizedBox(width: 4),
                                        const Icon(Icons.water_drop,
                                            color: AppColors.inondation,
                                            size: 14),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    prediction.segmentZone,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.outline),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            // Badge pill rounded-full teinté
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm, vertical: 4),
                              decoration: BoxDecoration(
                                color: bgColor,
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${prediction.scorePredit}%',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: textColor,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _labels[niveau],
                                    style: TextStyle(
                                        fontSize: 12, color: textColor),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        // Ligne basse : icône trend + "dans 15 min" + chevron
                        Row(
                          children: [
                            Icon(_trendIcons[niveau],
                                color: textColor, size: 16),
                            const SizedBox(width: 4),
                            const Text(
                              'dans 15 min',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.onSurfaceVariant),
                            ),
                            const Spacer(),
                            const Icon(Icons.chevron_right,
                                color: AppColors.outline, size: 18),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
