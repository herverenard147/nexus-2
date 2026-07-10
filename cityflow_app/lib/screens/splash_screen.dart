import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'dashboard_screen.dart';
import 'login_screen.dart';
import 'main_shell.dart';

class SplashScreen extends StatefulWidget {
  final ApiService api;
  const SplashScreen({super.key, required this.api});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await widget.api.restoreSession();
    if (!mounted) return;
    if (widget.api.isAuthenticated) {
      final dest = widget.api.userRole == 'autorite'
          ? DashboardScreen(api: widget.api)
          : MainShell(api: widget.api);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => dest),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => LoginScreen(api: widget.api)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              'assets/images/logo_cityflow.svg',
              width: 88,
              height: 88,
            ),
            const SizedBox(height: AppSpacing.lg),
            const Text(
              'CityFlow AI',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: AppColors.onPrimary,
                letterSpacing: -0.64,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Mobilité intelligente — Abidjan',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: AppColors.onPrimary.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(AppColors.onPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
