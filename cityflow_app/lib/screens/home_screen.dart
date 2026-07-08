import 'package:flutter/material.dart';
import '../models/prediction.dart';
import '../models/weather_alert.dart';
import '../services/api_service.dart';
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('CityFlow AI'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: Column(
        children: [
          WeatherBanner(alerts: _alerts),
          Expanded(child: _buildBody()),
          // Attribution OSM requise par la licence ODbL
          const Padding(
            padding: EdgeInsets.all(4),
            child: Text(
              '© OpenStreetMap contributors',
              style: TextStyle(fontSize: 10, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Chargement des prédictions…'),
          ],
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            const Text('Impossible de charger les données.',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(_error!, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _load, child: const Text('Réessayer')),
          ],
        ),
      );
    }
    if (_predictions == null || _predictions!.isEmpty) {
      return const Center(child: Text('Aucune prédiction disponible.'));
    }
    return ListView.separated(
      itemCount: _predictions!.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final pred = _predictions![i];
        return ListTile(
          title: Text(pred.segmentNom, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(pred.segmentZone),
          trailing: RiskBadge(niveau: pred.niveauRisque),
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
    );
  }
}
