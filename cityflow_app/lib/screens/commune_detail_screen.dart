import 'package:flutter/material.dart';
import '../models/commune_stats.dart';
import '../models/prediction.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'segment_detail_screen.dart';

class CommuneDetailScreen extends StatefulWidget {
  final ApiService api;
  final CommuneStats commune;

  const CommuneDetailScreen({
    super.key,
    required this.api,
    required this.commune,
  });

  @override
  State<CommuneDetailScreen> createState() => _CommuneDetailScreenState();
}

class _CommuneDetailScreenState extends State<CommuneDetailScreen> {
  final List<Prediction> _all = [];
  String? _error;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _offset = 0;
  static const _limit = 25;

  final TextEditingController _searchCtrl = TextEditingController();
  String _search = '';
  late final ScrollController _scroll;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() => _search = _searchCtrl.text));
    _scroll = ScrollController()..addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
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
      _all.clear();
      _offset = 0;
      _hasMore = true;
    });
    try {
      final page = await widget.api.getPredictions(
          limit: _limit, offset: 0, zone: widget.commune.zone);
      setState(() {
        _all.addAll(page.results);
        _hasMore = page.hasMore;
        _offset = page.results.length;
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
      final page = await widget.api.getPredictions(
          limit: _limit, offset: _offset, zone: widget.commune.zone);
      setState(() {
        _all.addAll(page.results);
        _hasMore = page.hasMore;
        _offset += page.results.length;
        _loadingMore = false;
      });
    } catch (_) {
      setState(() => _loadingMore = false);
    }
  }

  List<Prediction> get _filtered {
    if (_search.isEmpty) return _all;
    final q = _search.toLowerCase();
    return _all.where((p) => p.segmentNom.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.commune.zone,
            style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600)),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.onSurface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Rechercher un axe…',
                hintStyle:
                    const TextStyle(color: AppColors.onSurfaceVariant),
                prefixIcon: const Icon(Icons.search,
                    color: AppColors.onSurfaceVariant, size: 20),
                suffixIcon: _search.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => _searchCtrl.clear(),
                      )
                    : null,
                filled: true,
                fillColor: AppColors.background,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: AppRadius.cardBorder,
                  borderSide: BorderSide(color: AppColors.outlineVariant),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: AppRadius.cardBorder,
                  borderSide: BorderSide(color: AppColors.outlineVariant),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: AppRadius.cardBorder,
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
            ),
          ),
        ),
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.containerMargin),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.bloque),
            const SizedBox(height: AppSpacing.sm),
            Text(_error!,
                style:
                    const TextStyle(color: AppColors.onSurfaceVariant),
                textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.md),
            ElevatedButton(onPressed: _load, child: const Text('Réessayer')),
          ]),
        ),
      );
    }

    final segments = _filtered;

    if (segments.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.route_outlined, size: 48, color: AppColors.outline),
          const SizedBox(height: AppSpacing.sm),
          Text(
            _search.isNotEmpty
                ? 'Aucun axe correspondant.'
                : 'Aucun segment dans cette commune.',
            style:
                const TextStyle(color: AppColors.onSurfaceVariant),
          ),
        ]),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: segments.length + 1,
        itemBuilder: (ctx, i) {
          if (i < segments.length) {
            final pred = segments[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _SegmentCard(
                prediction: pred,
                onTap: () => Navigator.push(
                  ctx,
                  MaterialPageRoute(
                    builder: (_) =>
                        SegmentDetailScreen(api: widget.api, prediction: pred),
                  ),
                ),
              ),
            );
          }
          if (_loadingMore) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          }
          if (!_hasMore) {
            return Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Center(
                child: Text(
                  '${_all.length} axe${_all.length > 1 ? 's' : ''} chargé${_all.length > 1 ? 's' : ''}',
                  style: const TextStyle(
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
}

// ── Segment card (local to this screen) ───────────────────────────────────────

class _SegmentCard extends StatelessWidget {
  final Prediction prediction;
  final VoidCallback onTap;

  const _SegmentCard({required this.prediction, required this.onTap});

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
                if (isCritique) Container(width: 4, color: AppColors.bloque),
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
                                  Text(
                                    prediction.segmentNom,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color: AppColors.onSurface,
                                    ),
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
                                  Text(_labels[niveau],
                                      style: TextStyle(
                                          fontSize: 12, color: textColor)),
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
