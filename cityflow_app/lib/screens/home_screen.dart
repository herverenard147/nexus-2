import 'package:flutter/material.dart';
import '../models/commune_stats.dart';
import '../models/weather_alert.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/weather_banner.dart';
import 'commune_detail_screen.dart';

enum _Sort { criticite, alpha }

class HomeScreen extends StatefulWidget {
  final ApiService api;
  const HomeScreen({super.key, required this.api});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<CommuneStats>? _communes;
  List<WeatherAlert> _alerts = [];
  String? _error;
  bool _loading = true;
  _Sort _sort = _Sort.criticite;
  final TextEditingController _searchCtrl = TextEditingController();
  String _search = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() => _search = _searchCtrl.text));
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final communesFuture = widget.api.getCommuneStats();
      final alertsFuture = widget.api.getWeatherAlerts();
      final communes = await communesFuture;
      final alerts = await alertsFuture;
      setState(() {
        _communes = communes;
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

  List<CommuneStats> get _filtered {
    var list = List<CommuneStats>.from(_communes ?? []);
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list.where((c) => c.zone.toLowerCase().contains(q)).toList();
    }
    if (_sort == _Sort.alpha) {
      list.sort((a, b) => a.zone.compareTo(b.zone));
    }
    return list;
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
            Text('Chargement des communes…',
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

    final communes = _filtered;
    final alertZones = _alerts.map((a) => a.zone).toSet();

    return RefreshIndicator(
      onRefresh: _load,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildToolbar(context)),
          if (communes.isEmpty)
            const SliverFillRemaining(
              child: Center(
                child: Text('Aucune commune trouvée.',
                    style: TextStyle(color: AppColors.onSurfaceVariant)),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: _CommuneCard(
                      stats: communes[i],
                      hasAlert: alertZones.contains(communes[i].zone),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CommuneDetailScreen(
                            api: widget.api,
                            commune: communes[i],
                          ),
                        ),
                      ),
                    ),
                  ),
                  childCount: communes.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildToolbar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.lg, AppSpacing.md, AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Communes',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 4),
          const Text(
            'Zones de mobilité triées par criticité',
            style: TextStyle(fontSize: 14, color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Rechercher une commune…',
              hintStyle: const TextStyle(color: AppColors.onSurfaceVariant),
              prefixIcon: const Icon(Icons.search,
                  color: AppColors.onSurfaceVariant, size: 20),
              suffixIcon: _search.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () => _searchCtrl.clear(),
                    )
                  : null,
              filled: true,
              fillColor: AppColors.surface,
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
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              const Text('Trier : ',
                  style: TextStyle(
                      fontSize: 13, color: AppColors.onSurfaceVariant)),
              _SortChip(
                label: 'Criticité',
                selected: _sort == _Sort.criticite,
                onTap: () => setState(() => _sort = _Sort.criticite),
              ),
              const SizedBox(width: AppSpacing.xs),
              _SortChip(
                label: 'A → Z',
                selected: _sort == _Sort.alpha,
                onTap: () => setState(() => _sort = _Sort.alpha),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }
}

// ── Sort chip ──────────────────────────────────────────────────────────────────

class _SortChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _SortChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
              color: selected ? AppColors.primary : AppColors.outlineVariant),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.onPrimary : AppColors.onSurface,
          ),
        ),
      ),
    );
  }
}

// ── Commune card ───────────────────────────────────────────────────────────────

class _CommuneCard extends StatelessWidget {
  final CommuneStats stats;
  final bool hasAlert;
  final VoidCallback onTap;

  const _CommuneCard(
      {required this.stats, required this.hasAlert, required this.onTap});

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
  static const _labels = ['Fluide', 'Dense', 'Critique'];

  @override
  Widget build(BuildContext context) {
    final niveau = stats.niveauRisque;
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
                        // Ligne haute : nom + alerte / badge
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Text(
                                    stats.zone,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                      color: AppColors.onSurface,
                                    ),
                                  ),
                                  if (hasAlert) ...[
                                    const SizedBox(width: 4),
                                    const Icon(Icons.water_drop,
                                        color: AppColors.inondation, size: 14),
                                  ],
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
                                    '${stats.scoreMoyen}%',
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
                        const SizedBox(height: AppSpacing.xs),
                        // Ligne basse : nb axes / nb critiques / chevron
                        Row(
                          children: [
                            Text(
                              '${stats.nbSegments} axe${stats.nbSegments > 1 ? 's' : ''}',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.onSurfaceVariant),
                            ),
                            if (stats.nbCritiques > 0) ...[
                              const SizedBox(width: AppSpacing.sm),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.bloque.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(100),
                                ),
                                child: Text(
                                  '${stats.nbCritiques} critique${stats.nbCritiques > 1 ? 's' : ''}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.bloque,
                                  ),
                                ),
                              ),
                            ],
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
