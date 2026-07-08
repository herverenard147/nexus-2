import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'services/api_service.dart';

final _api = ApiService();

void main() => runApp(const CityFlowApp());

class CityFlowApp extends StatelessWidget {
  const CityFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CityFlow AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1565C0)),
        useMaterial3: true,
      ),
      home: HomeScreen(api: _api),
    );
  }
}
