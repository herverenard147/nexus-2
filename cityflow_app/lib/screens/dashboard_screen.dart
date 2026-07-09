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

  List<_ZoneRow> _buildZoneRows() {
    final segments = _zones ?? [];
    final Map<String, _ZoneRow> agg = {};
    for (final z in segments) {
      final nom = z['zone'] as String? ?? '—';
      final score = (z['score_composite'] as num?)?.toInt() ?? 0;
      if (agg.containsKey(nom)) {
        final existing = agg[nom]!;
        agg[nom] = _ZoneRow(
          zone: nom,
          score: ((existing.score + score) / 2).round(),
          count: existing.count + 1,
        );
      } else {
        agg[nom] = _ZoneRow(zone: nom, score: score, count: 1);
      }
    }
    final rows = agg.values.toList()..sort((a, b) => b.score.compareTo(a.score));
    return rows.take(5).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceContainerLow,
      appBar: AppBar(
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
                        _CriticalZonesCard(rows: _buildZoneRows()),
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
    final congestion = (stats['congestion_moyenne'] as num?)?.toStringAsFixed(0) ?? '—';
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
            color: AppColors.bloque,
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

class _CriticalZonesCard extends StatelessWidget {
  final List<_ZoneRow> rows;
  const _CriticalZonesCard({required this.rows});

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
                const Icon(Icons.location_on_outlined,
                    size: 18, color: AppColors.primary),
                const SizedBox(width: AppSpacing.xs),
                Text('Top 5 zones critiques',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize: 16,
                        )),
                const Spacer(),
                const Text('agrégé par zone',
                    style: TextStyle(
                        fontSize: 11, color: AppColors.onSurfaceVariant)),
              ],
            ),
          ),
          const Divider(height: 1),
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Text('Aucune zone critique détectée.',
                  style: TextStyle(color: AppColors.onSurfaceVariant)),
            )
          else
            ...rows.asMap().entries.map((e) => _ZoneRowTile(
                rank: e.key + 1, row: e.value)),
        ],
      ),
    );
  }
}

class _ZoneRow {
  final String zone;
  final int score;
  final int count;
  const _ZoneRow({required this.zone, required this.score, required this.count});
}

class _ZoneRowTile extends StatelessWidget {
  final int rank;
  final _ZoneRow row;
  const _ZoneRowTile({required this.rank, required this.row});

  @override
  Widget build(BuildContext context) {
    final niveau = row.score >= 70 ? 2 : row.score >= 40 ? 1 : 0;
    final color = AppColors.trafficColor(niveau);
    final labels = ['Fluide', 'Dense', 'Bloqué'];
    final icons = [Icons.check_circle, Icons.warning, Icons.cancel];

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: const BoxDecoration(
        border: Border(
            bottom: BorderSide(color: AppColors.outlineVariant, width: 1)),
      ),
      child: Row(
        children: [
          Text('$rank',
              style: const TextStyle(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(row.zone,
                style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: AppRadius.chipBorder,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icons[niveau], size: 13, color: color),
                const SizedBox(width: 4),
                Text(labels[niveau],
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: color)),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text('${row.score}/100',
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface)),
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
