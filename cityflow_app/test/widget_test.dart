import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cityflow_app/models/commune_stats.dart';
import 'package:cityflow_app/models/prediction.dart';
import 'package:cityflow_app/models/weather_alert.dart';
import 'package:cityflow_app/services/api_service.dart';
import 'package:cityflow_app/screens/home_screen.dart';
import 'package:cityflow_app/widgets/weather_banner.dart';
import 'package:cityflow_app/widgets/risk_badge.dart';
import 'package:cityflow_app/widgets/report_form_sheet.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------
class FakeApi extends ApiService {
  final List<CommuneStats> communes;
  final List<Prediction> preds;
  final List<WeatherAlert> alerts;
  final bool failCreate;

  FakeApi({
    this.communes = const [],
    this.preds = const [],
    this.alerts = const [],
    this.failCreate = false,
  }) : super(baseUrl: 'http://fake');

  @override
  Future<List<CommuneStats>> getCommuneStats() async => communes;

  @override
  Future<PredictionPage> getPredictions(
          {int limit = 25, int offset = 0, String? zone}) async =>
      PredictionPage(results: preds, hasMore: false, count: preds.length);

  @override
  Future<List<WeatherAlert>> getWeatherAlerts() async => alerts;

  @override
  Future<Map<String, dynamic>> createReport(int segmentId, String type) async {
    if (failCreate) throw const ApiException(429, 'Trop de signalements');
    return {'id': 1, 'segment': segmentId, 'type': type, 'statut': 'actif',
            'nb_confirmations': 1};
  }
}

class ErrorApi extends ApiService {
  ErrorApi() : super(baseUrl: 'http://fake');

  @override
  Future<List<CommuneStats>> getCommuneStats() async =>
      throw const ApiException(500, 'Erreur serveur');

  @override
  Future<PredictionPage> getPredictions(
          {int limit = 25, int offset = 0, String? zone}) async =>
      throw const ApiException(500, 'Erreur serveur');

  @override
  Future<List<WeatherAlert>> getWeatherAlerts() async => [];
}

CommuneStats _commune({int score = 30}) => CommuneStats(
      zone: 'Cocody',
      nbSegments: 5,
      scoreMoyen: score,
      scoreMax: score + 10,
      nbCritiques: 0,
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------
void main() {
  group('HomeScreen', () {
    testWidgets('affiche CircularProgressIndicator pendant le chargement',
        (tester) async {
      await tester.pumpWidget(
          MaterialApp(home: HomeScreen(api: FakeApi(communes: [_commune()]))));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('affiche les communes après chargement', (tester) async {
      await tester.pumpWidget(
          MaterialApp(home: HomeScreen(api: FakeApi(communes: [_commune()]))));
      await tester.pumpAndSettle();
      expect(find.text('Cocody'), findsOneWidget);
    });

    testWidgets('affiche état erreur si API échoue', (tester) async {
      await tester.pumpWidget(MaterialApp(home: HomeScreen(api: ErrorApi())));
      await tester.pumpAndSettle();
      expect(find.text('Impossible de charger les données.'), findsOneWidget);
    });
  });

  group('RiskBadge — double codage', () {
    for (final entry in [(0, 'Fluide'), (1, 'Modéré'), (2, 'Critique')]) {
      testWidgets('niveau ${entry.$1} : icône + texte ${entry.$2}', (tester) async {
        await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: RiskBadge(niveau: entry.$1))),
        );
        expect(find.byType(Icon), findsOneWidget);
        expect(find.text(entry.$2), findsOneWidget);
      });
    }
  });

  group('WeatherBanner', () {
    testWidgets("ne s'affiche pas sans alerte", (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: WeatherBanner(alerts: []))),
      );
      expect(find.byIcon(Icons.water_drop), findsNothing);
    });

    testWidgets("s'affiche avec icône goutte si alertes non vides", (tester) async {
      const alert = WeatherAlert(id: 1, nom: 'Autoroute du Nord', zone: 'Abobo');
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: WeatherBanner(alerts: [alert]))),
      );
      expect(find.byIcon(Icons.water_drop), findsOneWidget);
      expect(find.textContaining('Autoroute du Nord'), findsOneWidget);
    });
  });

  group('ReportFormSheet', () {
    testWidgets('envoie le rapport et affiche confirmation', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: ReportFormSheet(api: FakeApi(), segmentId: 42)),
      ));
      await tester.tap(find.text('Envoyer'));
      await tester.pumpAndSettle();
      expect(find.text('Signalement envoyé !'), findsOneWidget);
    });

    testWidgets('affiche un message erreur si createReport échoue', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ReportFormSheet(api: FakeApi(failCreate: true), segmentId: 42),
        ),
      ));
      await tester.tap(find.text('Envoyer'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Trop de signalements'), findsOneWidget);
    });
  });
}
