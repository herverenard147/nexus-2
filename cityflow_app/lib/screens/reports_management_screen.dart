import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class ReportsManagementScreen extends StatefulWidget {
  final ApiService api;
  const ReportsManagementScreen({super.key, required this.api});

  @override
  State<ReportsManagementScreen> createState() =>
      _ReportsManagementScreenState();
}

class _ReportsManagementScreenState extends State<ReportsManagementScreen> {
  List<Map<String, dynamic>>? _reports;
  bool _loading = true;
  String? _error;
  String _filter = 'actif';

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
      final reports = await widget.api.getReports(statut: _filter);
      setState(() {
        _reports = reports;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _resolve(int reportId) async {
    await widget.api.updateReport(reportId, 'resolu');
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceContainerLow,
      appBar: AppBar(
        title: const Text('Gestion des signalements'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        titleTextStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.onPrimary,
        ),
        iconTheme: const IconThemeData(color: AppColors.onPrimary),
      ),
      body: Column(
        children: [
          _FilterBar(
            current: _filter,
            onChanged: (f) {
              setState(() => _filter = f);
              _load();
            },
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.bloque),
            const SizedBox(height: AppSpacing.sm),
            Text(_error!,
                style: const TextStyle(color: AppColors.onSurfaceVariant),
                textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.md),
            ElevatedButton(onPressed: _load, child: const Text('Réessayer')),
          ],
        ),
      );
    }
    if (_reports == null || _reports!.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_outline,
                size: 56, color: AppColors.fluide),
            const SizedBox(height: AppSpacing.md),
            Text(
              _filter == 'actif'
                  ? 'Aucun signalement actif'
                  : _filter == 'resolu'
                      ? 'Aucun signalement résolu'
                      : 'Aucun signalement',
              style:
                  Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 16),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: _reports!.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
        itemBuilder: (context, i) => _ReportTile(
          report: _reports![i],
          onResolve: _resolve,
        ),
      ),
    );
  }
}

// ── Filter bar ─────────────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  final String current;
  final ValueChanged<String> onChanged;
  const _FilterBar({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      child: Row(
        children: [
          _Chip(label: 'Actifs', value: 'actif', current: current, onTap: onChanged),
          const SizedBox(width: AppSpacing.xs),
          _Chip(label: 'Résolus', value: 'resolu', current: current, onTap: onChanged),
          const SizedBox(width: AppSpacing.xs),
          _Chip(label: 'Tous', value: '', current: current, onTap: onChanged),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final String value;
  final String current;
  final ValueChanged<String> onTap;
  const _Chip(
      {required this.label,
      required this.value,
      required this.current,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final selected = current == value;
    return GestureDetector(
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surfaceContainer,
          borderRadius: AppRadius.chipBorder,
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected
                    ? AppColors.onPrimary
                    : AppColors.onSurfaceVariant)),
      ),
    );
  }
}

// ── Report tile ────────────────────────────────────────────────────────────────

class _ReportTile extends StatefulWidget {
  final Map<String, dynamic> report;
  final Future<void> Function(int id) onResolve;

  const _ReportTile({required this.report, required this.onResolve});

  @override
  State<_ReportTile> createState() => _ReportTileState();
}

class _ReportTileState extends State<_ReportTile> {
  bool _resolving = false;

  Future<void> _handleResolve() async {
    final id = widget.report['id'] as int?;
    if (id == null) return;
    setState(() => _resolving = true);
    try {
      await widget.onResolve(id);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur ${e.statusCode} : ${e.message}'),
          backgroundColor: AppColors.bloque,
        ),
      );
      setState(() => _resolving = false);
    } catch (_) {
      if (!mounted) return;
      setState(() => _resolving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final type = widget.report['type'] as String? ?? '—';
    final gravite = widget.report['gravite'] as String? ?? '—';
    final nb = (widget.report['nb_confirmations'] as num?)?.toInt() ?? 1;
    final statut = widget.report['statut'] as String? ?? '—';
    final segment = widget.report['segment_nom'] as String? ??
        'Segment ${widget.report['segment']}';
    final isActif = statut == 'actif';

    final Color statusColor;
    final IconData statusIcon;
    switch (statut) {
      case 'actif':
        statusColor = AppColors.bloque;
        statusIcon = Icons.warning_outlined;
        break;
      case 'resolu':
        statusColor = AppColors.fluide;
        statusIcon = Icons.check_circle_outline;
        break;
      default:
        statusColor = AppColors.outline;
        statusIcon = Icons.circle_outlined;
    }

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
          Row(
            children: [
              Icon(statusIcon, color: statusColor, size: 22),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(type,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(segment,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.onSurfaceVariant),
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('gravité : $gravite',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.onSurfaceVariant)),
                  const SizedBox(height: 2),
                  Text('$nb confirmation${nb > 1 ? 's' : ''}',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary)),
                ],
              ),
            ],
          ),
          if (isActif) ...[
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                height: 34,
                child: ElevatedButton.icon(
                  onPressed: _resolving ? null : _handleResolve,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.fluide,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm, vertical: 0),
                    textStyle: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600),
                    shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.chipBorder),
                  ),
                  icon: _resolving
                      ? const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation(Colors.white)))
                      : const Icon(Icons.check_outlined, size: 14),
                  label: const Text('Traiter'),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
