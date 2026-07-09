import 'package:flutter/material.dart';
import '../models/prediction.dart';
import '../models/weather_alert.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/risk_badge.dart';
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
        Expanded(child: _buildBody()),
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

  Widget _buildBody() {
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
              style: TextStyle(color: AppColors.onSurfaceVariant)));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        itemCount: _predictions!.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final pred = _predictions![i];
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.xs),
            title: Text(pred.segmentNom,
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppColors.onSurface)),
            subtitle: Text(pred.segmentZone,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.onSurfaceVariant)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                RiskBadge(niveau: pred.niveauRisque),
                const SizedBox(width: AppSpacing.xs),
                const Icon(Icons.chevron_right,
                    color: AppColors.outline, size: 18),
              ],
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SegmentDetailScreen(
                  api: widget.api,
                  prediction: pred,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
