import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../models/weather_alert.dart';

class AlertsScreen extends StatefulWidget {
  final ApiService api;
  const AlertsScreen({super.key, required this.api});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  List<WeatherAlert>? _alerts;
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
      final alerts = await widget.api.getWeatherAlerts();
      setState(() {
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

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.containerMargin,
                  AppSpacing.lg,
                  AppSpacing.containerMargin,
                  AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Alertes météo & trafic',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: AppSpacing.xs),
                  Text('Tirez vers le bas pour actualiser',
                      style: TextStyle(
                          color: AppColors.onSurfaceVariant, fontSize: 13)),
                ],
              ),
            ),
          ),
          if (_loading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off_outlined,
                        size: 48, color: AppColors.onSurfaceVariant),
                    const SizedBox(height: AppSpacing.sm),
                    Text(_error!,
                        style: const TextStyle(
                            color: AppColors.onSurfaceVariant, fontSize: 13),
                        textAlign: TextAlign.center),
                    const SizedBox(height: AppSpacing.md),
                    ElevatedButton(
                        onPressed: _load, child: const Text('Réessayer')),
                  ],
                ),
              ),
            )
          else if (_alerts == null || _alerts!.isEmpty)
            const SliverFillRemaining(child: _EmptyState())
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.containerMargin),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _AlertCard(alert: _alerts![i]),
                  ),
                  childCount: _alerts!.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  final WeatherAlert alert;
  const _AlertCard({required this.alert});

  @override
  Widget build(BuildContext context) {
    final zone = alert.nom.isNotEmpty ? alert.nom : alert.zone;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardBorder,
        boxShadow: AppShadows.card,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.inondation,
              borderRadius: const BorderRadius.vertical(top: AppRadius.card),
            ),
            child: Row(
              children: [
                const Icon(Icons.water_drop, color: AppColors.onPrimary, size: 18),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    'Alerte inondation — $zone',
                    style: const TextStyle(
                        color: AppColors.onPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                const Icon(Icons.info_outline,
                    size: 16, color: AppColors.onSurfaceVariant),
                const SizedBox(width: AppSpacing.xs),
                Text('Zone : $zone',
                    style: const TextStyle(
                        color: AppColors.onSurfaceVariant, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.fluide.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_outline,
                  size: 40, color: AppColors.fluide),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Aucune alerte active',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'La circulation est normale dans toutes les zones.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.onSurfaceVariant, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
