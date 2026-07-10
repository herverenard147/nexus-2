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
  final List<Prediction> _predictions = [];
  List<WeatherAlert> _alerts = [];
  String? _error;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _offset = 0;
  static const _limit = 25;

  late final ScrollController _scroll;

  @override
  void initState() {
    super.initState();
    _scroll = ScrollController()..addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300 &&
        !_loadingMore &&
        _hasMore) {
      _loadMore();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _predictions.clear();
      _offset = 0;
      _hasMore = true;
    });
    try {
      final pageFuture = widget.api.getPredictions(limit: _limit, offset: 0);
      final alertsFuture = widget.api.getWeatherAlerts();
      final page = await pageFuture;
      final alerts = await alertsFuture;
      setState(() {
        _predictions.addAll(page.results);
        _hasMore = page.hasMore;
        _offset = page.results.length;
        _alerts = alerts;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final page = await widget.api.getPredictions(limit: _limit, offset: _offset);
      setState(() {
        _predictions.addAll(page.results);
        _hasMore = page.hasMore;
        _offset += page.results.length;
        _loadingMore = false;
      });
    } catch (_) {
      setState(() => _loadingMore = false);
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
    if (_predictions.isEmpty) {
      return const Center(
        child: Text('Aucune prédiction disponible.',
            style: TextStyle(color: AppColors.onSurfaceVariant)),
      );
    }

    final alertZones = _alerts.map((a) => a.zone).toSet();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, AppSpacing.lg, AppSpacing.md, AppSpacing.md),
        // header + segments + footer
        itemCount: _predictions.length + 2,
        itemBuilder: (ctx, i) {
          if (i == 0) return _buildHeader(context);
          if (i <= _predictions.length) {
            final pred = _predictions[i - 1];
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
          }
          // Footer
          if (_loadingMore) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          }
          if (!_hasMore) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Center(
                child: Text(
                  'Tous les segments chargés',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.onSurfaceVariant),
                ),
              ),
            );
          }
          return const SizedBox.shrink();
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
            'Segments les plus congestionnés en premier',
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
