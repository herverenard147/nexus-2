import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'register_screen.dart';
import 'main_shell.dart';
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  final ApiService api;
  final bool isAutorite;

  const LoginScreen({super.key, required this.api, this.isAutorite = false});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.api.login(_userCtrl.text.trim(), _passCtrl.text);
      if (!mounted) return;
      final role = data['role'] as String? ?? '';
      if (role == 'autorite') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => DashboardScreen(api: widget.api)),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => MainShell(api: widget.api)),
        );
      }
    } on ApiException catch (e) {
      setState(() {
        _error = e.statusCode == 401
            ? 'Identifiants incorrects. Vérifiez votre nom d\'utilisateur et mot de passe.'
            : 'Erreur ${e.statusCode} : ${e.message}';
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Impossible de joindre le serveur. Vérifiez votre connexion.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.containerMargin),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.xl),
              _Logo(),
              const SizedBox(height: AppSpacing.xl),
              Text(
                widget.isAutorite ? 'Espace Autorités' : 'Connexion',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppColors.onSurface,
                    ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                widget.isAutorite
                    ? 'Accès réservé aux agents municipaux'
                    : 'Bienvenue sur CityFlow AI',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.bloque.withValues(alpha: 0.08),
                    borderRadius: AppRadius.cardBorder,
                    border: Border.all(color: AppColors.bloque.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.bloque, size: 18),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(_error!,
                            style: const TextStyle(
                                color: AppColors.bloque, fontSize: 13)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _userCtrl,
                      decoration: const InputDecoration(
                        labelText: "Nom d'utilisateur",
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      textInputAction: TextInputAction.next,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Champ requis' : null,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextFormField(
                      controller: _passCtrl,
                      decoration: InputDecoration(
                        labelText: 'Mot de passe',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_obscure
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      obscureText: _obscure,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Champ requis' : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation(AppColors.onPrimary)),
                      )
                    : const Text('Se connecter'),
              ),
              if (!widget.isAutorite) ...[
                const SizedBox(height: AppSpacing.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Pas encore de compte ?',
                        style: TextStyle(color: AppColors.onSurfaceVariant)),
                    TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => RegisterScreen(api: widget.api)),
                      ),
                      child: const Text("S'inscrire"),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Center(
                  child: TextButton.icon(
                    icon: const Icon(Icons.admin_panel_settings_outlined,
                        size: 16, color: AppColors.onSurfaceVariant),
                    label: const Text('Espace autorités',
                        style: TextStyle(
                            color: AppColors.onSurfaceVariant, fontSize: 13)),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            LoginScreen(api: widget.api, isAutorite: true),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              const _OsmAttribution(),
            ],
          ),
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SvgPicture.asset(
          'assets/images/logo_cityflow.svg',
          width: 48,
          height: 48,
        ),
        const SizedBox(width: AppSpacing.sm),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('CityFlow AI',
                style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryDeep)),
            const Text('Abidjan',
                style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: AppColors.onSurfaceVariant)),
          ],
        ),
      ],
    );
  }
}

class _OsmAttribution extends StatelessWidget {
  const _OsmAttribution();

  @override
  Widget build(BuildContext context) {
    return const Text(
      '© OpenStreetMap contributors',
      style: TextStyle(fontSize: 10, color: AppColors.outline),
      textAlign: TextAlign.center,
    );
  }
}
