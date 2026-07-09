import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'report_screen.dart';
import 'alerts_screen.dart';
import 'login_screen.dart';

class MainShell extends StatefulWidget {
  final ApiService api;
  const MainShell({super.key, required this.api});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  late final List<Widget> _screens = [
    HomeScreen(api: widget.api),
    ReportScreen(api: widget.api),
    AlertsScreen(api: widget.api),
  ];

  Future<void> _logout() async {
    await widget.api.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => LoginScreen(api: widget.api)),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                borderRadius: AppRadius.chipBorder,
              ),
              child: const Icon(Icons.traffic, color: AppColors.onPrimary, size: 18),
            ),
            const SizedBox(width: AppSpacing.xs),
            const Text('CityFlow AI'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_outlined),
            tooltip: 'Déconnexion',
            onPressed: _logout,
          ),
        ],
      ),
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(boxShadow: AppShadows.overlay),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (i) => setState(() => _currentIndex = i),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.map_outlined),
              selectedIcon: Icon(Icons.map),
              label: 'Prédictions',
            ),
            NavigationDestination(
              icon: Icon(Icons.add_alert_outlined),
              selectedIcon: Icon(Icons.add_alert),
              label: 'Signaler',
            ),
            NavigationDestination(
              icon: Icon(Icons.notifications_outlined),
              selectedIcon: Icon(Icons.notifications),
              label: 'Alertes',
            ),
          ],
        ),
      ),
    );
  }
}
