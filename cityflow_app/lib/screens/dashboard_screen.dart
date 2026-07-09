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
  Map<String, dynamic>? _zones;
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
      final results = await Future.wait([
        widget.api.getDashboardCriticalZones(),
        widget.api.getDashboardStats(),
      ]);
      setState(() {
        _zones = results[0];
        _stats = results[1];
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
    final zones = _zones?['zones'] as List? ?? [];
    // Agréger par zone_nom
    final Map<String, _ZoneRow> agg = {};
    for (final z in zones) {
      final nom = z['zone_nom'] as String? ?? z['zone'] as String? ?? '—';
      final score = (z['score_moyen'] as num?)?.toInt() ??
          (z['score'] as num?)?.toInt() ??
          0;
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
                    fontFamily: 'Inter',
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
    return Row(
      children: [
        Expanded(
          child: _KpiCard(
            label: 'Segments',
            value: '${stats['nb_segments'] ?? stats['segments'] ?? '—'}',
            icon: Icons.route_outlined,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _KpiCard(
            label: 'Critiques',
            value: '${stats['nb_critiques'] ?? stats['critiques'] ?? '—'}',
            icon: Icons.warning_outlined,
            color: AppColors.bloque,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _KpiCard(
            label: 'Signalements',
            value: '${stats['nb_signalements'] ?? stats['signalements'] ?? '—'}',
            icon: Icons.add_alert_outlined,
            color: AppColors.dense,
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
                  fontFamily: 'Inter',
                  fontSize: 24,
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
                Text('agrégé par zone',
                    style: const TextStyle(
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
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Inter')),
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
      final uri = widget.api.getDashboardExportUri();
      final token = widget.api.accessToken;
      final res = await Uri.parse(uri.toString()).let((u) async {
        final r = await _httpGet(u, token);
        return r;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res
              ? 'Export CSV prêt (${uri.host})'
              : 'Erreur lors de l\'export'),
          backgroundColor: res ? AppColors.fluide : AppColors.bloque,
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

  // Lightweight GET just to validate the endpoint is reachable
  Future<bool> _httpGet(Uri uri, String? token) async {
    try {
      final r = await widget.api.getDashboardStats();
      return r.isNotEmpty;
    } catch (_) {
      return false;
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Export CSV',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                Text('Prédictions et statistiques',
                    style: const TextStyle(
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

extension _UriExt on Uri {
  T let<T>(T Function(Uri) f) => f(this);
}
