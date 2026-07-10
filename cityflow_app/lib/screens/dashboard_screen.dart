import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';
import 'reports_management_screen.dart';

class DashboardScreen extends StatefulWidget {
  final ApiService api;
  const DashboardScreen({super.key, required this.api});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Map<String, dynamic>>? _zones;
  Map<String, dynamic>? _stats;
  bool _loading = true;
  String? _error;

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
      final zones = await widget.api.getDashboardCriticalZones();
      final stats = await widget.api.getDashboardStats();
      setState(() {
        _zones = zones;
        _stats = stats;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _logout() async {
    await widget.api.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => LoginScreen(api: widget.api, isAutorite: true)),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceContainerLow,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        title: Row(
          children: [
            const Icon(Icons.traffic, size: 20),
            const SizedBox(width: AppSpacing.xs),
            const Text('CityFlow AI',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.onPrimary)),
            const SizedBox(width: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.onPrimary.withValues(alpha: 0.15),
                borderRadius: AppRadius.chipBorder,
              ),
              child: const Text('Autorités',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onPrimary)),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.list_alt_outlined, color: AppColors.onPrimary),
            tooltip: 'Gestion des signalements',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => ReportsManagementScreen(api: widget.api)),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout_outlined, color: AppColors.onPrimary),
            tooltip: 'Déconnexion',
            onPressed: _logout,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 48, color: AppColors.bloque),
                      const SizedBox(height: AppSpacing.sm),
                      Text(_error!,
                          style: const TextStyle(
                              color: AppColors.onSurfaceVariant),
                          textAlign: TextAlign.center),
                      const SizedBox(height: AppSpacing.md),
                      ElevatedButton(
                          onPressed: _load, child: const Text('Réessayer')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _StatsRow(stats: _stats ?? {}),
                        const SizedBox(height: AppSpacing.lg),
                        _CriticalSegmentsCard(segments: _zones ?? []),
                        const SizedBox(height: AppSpacing.lg),
                        _ExportCard(api: widget.api),
                        const SizedBox(height: AppSpacing.lg),
                        const Text('© OpenStreetMap contributors',
                            style: TextStyle(
                                fontSize: 10, color: AppColors.outline),
                            textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final Map<String, dynamic> stats;
  const _StatsRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    final congestionRaw = (stats['congestion_moyenne'] as num?)?.round() ?? -1;
    final congestion = congestionRaw < 0 ? '—' : '$congestionRaw';
    final congestionNiveau = congestionRaw < 0
        ? 0
        : congestionRaw >= 70
            ? 2
            : congestionRaw >= 40
                ? 1
                : 0;
    return Row(
      children: [
        Expanded(
          child: _KpiCard(
            label: 'Signalements',
            value: '${stats['nb_signalements_actifs'] ?? '—'}',
            icon: Icons.add_alert_outlined,
            color: AppColors.dense,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _KpiCard(
            label: 'Alertes météo',
            value: '${stats['segments_en_alerte_meteo'] ?? '—'}',
            icon: Icons.water_drop_outlined,
            color: AppColors.inondation,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _KpiCard(
            label: 'Congestion moy.',
            value: congestion == '—' ? '—' : '$congestion/100',
            icon: Icons.speed_outlined,
            color: AppColors.trafficColor(congestionNiveau),
          ),
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardBorder,
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: AppSpacing.xs),
          Text(value,
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: color)),
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.onSurfaceVariant,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _CriticalSegmentsCard extends StatelessWidget {
  final List<Map<String, dynamic>> segments;
  const _CriticalSegmentsCard({required this.segments});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardBorder,
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.sm),
            child: Row(
              children: [
                const Icon(Icons.route_outlined,
                    size: 18, color: AppColors.primary),
                const SizedBox(width: AppSpacing.xs),
                Text('Top 5 axes critiques',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontSize: 16)),
                const Spacer(),
                const Text('score composite',
                    style: TextStyle(
                        fontSize: 11, color: AppColors.onSurfaceVariant)),
              ],
            ),
          ),
          const Divider(height: 1),
          if (segments.isEmpty)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Text('Aucun axe critique détecté.',
                  style: TextStyle(color: AppColors.onSurfaceVariant)),
            )
          else
            ...segments.asMap().entries.map(
                  (e) => _SegmentRowTile(rank: e.key + 1, seg: e.value),
                ),
        ],
      ),
    );
  }
}

class _SegmentRowTile extends StatelessWidget {
  final int rank;
  final Map<String, dynamic> seg;
  const _SegmentRowTile({required this.rank, required this.seg});

  static const _labels = ['Fluide', 'Dense', 'Bloqué'];
  static const _icons = [Icons.check_circle, Icons.warning, Icons.cancel];

  @override
  Widget build(BuildContext context) {
    final score = (seg['score_composite'] as num?)?.toInt() ?? 0;
    final nom = seg['segment_nom'] as String? ?? '—';
    final zone = seg['zone'] as String? ?? '';
    final hasMeteo = seg['alerte_meteo'] == true;
    final nbSig = (seg['nb_signalements_actifs'] as num?)?.toInt() ?? 0;

    final niveau = score >= 70 ? 2 : score >= 40 ? 1 : 0;
    final color = AppColors.trafficColor(niveau);

    return Container(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
      decoration: const BoxDecoration(
        border: Border(
            bottom: BorderSide(color: AppColors.outlineVariant, width: 1)),
      ),
      child: Row(
        children: [
          // Rang
          SizedBox(
            width: 20,
            child: Text('$rank',
                style: const TextStyle(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: AppSpacing.xs),
          // Nom + zone + badges incidents/météo
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nom,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (zone.isNotEmpty)
                      Text(zone,
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.onSurfaceVariant)),
                    if (hasMeteo) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.water_drop,
                          size: 11, color: AppColors.inondation),
                    ],
                    if (nbSig > 0) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.warning_rounded,
                          size: 11, color: AppColors.dense),
                      Text(' $nbSig',
                          style: const TextStyle(
                              fontSize: 10, color: AppColors.dense)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          // Badge niveau
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: AppRadius.chipBorder,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_icons[niveau], size: 12, color: color),
                const SizedBox(width: 3),
                Text(_labels[niveau],
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: color)),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          // Score
          Text('$score',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: color)),
        ],
      ),
    );
  }
}

class _ExportCard extends StatefulWidget {
  final ApiService api;
  const _ExportCard({required this.api});

  @override
  State<_ExportCard> createState() => _ExportCardState();
}

class _ExportCardState extends State<_ExportCard> {
  bool _exporting = false;

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      final csv = await widget.api.downloadCsvExport();
      if (!mounted) return;
      final lines = csv.split('\n').where((l) => l.trim().isNotEmpty).length;
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.download_done_outlined, color: AppColors.primary),
              const SizedBox(width: AppSpacing.xs),
              Text('Export CSV ($lines lignes)'),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 280,
            child: SingleChildScrollView(
              child: SelectableText(
                csv,
                style: const TextStyle(fontSize: 10),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Fermer'),
            ),
          ],
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur ${e.statusCode} : ${e.message}'),
          backgroundColor: AppColors.bloque,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erreur export CSV'),
          backgroundColor: AppColors.bloque,
        ),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardBorder,
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: [
          const Icon(Icons.download_outlined, color: AppColors.primary, size: 20),
          const SizedBox(width: AppSpacing.sm),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Export CSV',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                Text('Prédictions et statistiques',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.onSurfaceVariant)),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: _exporting ? null : _export,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(100, 40),
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.xs),
            ),
            child: _exporting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation(AppColors.onPrimary)))
                : const Text('Exporter', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
