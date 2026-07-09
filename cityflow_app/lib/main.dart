import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'services/api_service.dart';
import 'theme/app_theme.dart';

final _api = ApiService();

void main() => runApp(const CityFlowApp());

class CityFlowApp extends StatelessWidget {
  const CityFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CityFlow AI',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: SplashScreen(api: _api),
    );
  }
}
