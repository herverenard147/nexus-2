import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class ConseillerScreen extends StatefulWidget {
  final ApiService api;
  const ConseillerScreen({super.key, required this.api});

  @override
  State<ConseillerScreen> createState() => _ConseillerScreenState();
}

class _ConseillerScreenState extends State<ConseillerScreen> {
  List<Map<String, dynamic>>? _corridors;
  Map<String, dynamic>? _selectedCorridor;
  Map<String, dynamic>? _conseil;
  bool _loadingCorridors = true;
  bool _loadingConseil = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCorridors();
  }

  Future<void> _loadCorridors() async {
    setState(() {
      _loadingCorridors = true;
      _error = null;
    });
    try {
      final corridors = await widget.api.getCorridors();
      setState(() {
        _corridors = corridors;
        _loadingCorridors = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _error = 'Erreur ${e.statusCode} : ${e.message}';
        _loadingCorridors = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Connexion impossible';
        _loadingCorridors = false;
      });
    }
  }

  Future<void> _loadConseil(Map<String, dynamic> corridor) async {
    setState(() {
      _selectedCorridor = corridor;
      _loadingConseil = true;
      _conseil = null;
      _error = null;
    });
    try {
      final result = await widget.api.getConseil(corridor['key'] as String);
      setState(() {
        _conseil = result;
        _loadingConseil = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _error = 'Erreur ${e.statusCode} : ${e.message}';
        _loadingConseil = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Connexion impossible';
        _loadingConseil = false;
      });
    }
  }

  Color _etatColor(String etat) {
    switch (etat) {
      case 'fluide':
        return AppColors.fluide;
      case 'légèrement ralenti':
        return AppColors.dense;
      case 'ralenti':
        return const Color(0xFFF97316);
      case 'congestionné':
      case 'très congestionné':
        return AppColors.bloque;
      default:
        return AppColors.onSurfaceVariant;
    }
  }

  IconData _etatIcon(String etat) {
    switch (etat) {
      case 'fluide':
        return Icons.check_circle_outline;
      case 'légèrement ralenti':
        return Icons.remove_circle_outline;
      case 'ralenti':
        return Icons.warning_amber_outlined;
      case 'congestionné':
      case 'très congestionné':
        return Icons.cancel_outlined;
      default:
        return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        await _loadCorridors();
        if (_selectedCorridor != null) {
          await _loadConseil(_selectedCorridor!);
        }
      },
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.containerMargin,
                AppSpacing.lg,
                AppSpacing.containerMargin,
                AppSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Analyse de trajet',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Corridors prédéfinis — analyse CityFlow en temps réel',
                    style: TextStyle(
                        fontSize: 14, color: AppColors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
          if (_loadingCorridors)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null && _corridors == null)
            SliverFillRemaining(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.cloud_off_outlined,
                          size: 48, color: AppColors.onSurfaceVariant),
                      const SizedBox(height: AppSpacing.sm),
                      Text(_error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: AppColors.onSurfaceVariant)),
                      const SizedBox(height: AppSpacing.md),
                      FilledButton.icon(
                        onPressed: _loadCorridors,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Réessayer'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else ...[
            // Liste des corridors (boutons de sélection)
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.containerMargin),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                    final c = _corridors![i];
                    final isSelected =
                        _selectedCorridor?['key'] == c['key'];
                    return Padding(
                      padding:
                          const EdgeInsets.only(bottom: AppSpacing.gutter),
                      child: _CorridorTile(
                        corridor: c,
                        selected: isSelected,
                        onTap: () => _loadConseil(c),
                      ),
                    );
                  },
                  childCount: _corridors!.length,
                ),
              ),
            ),
            // Résultat du conseil
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.containerMargin),
                child: _buildConseilPanel(),
              ),
            ),
            const SliverToBoxAdapter(
              child: SizedBox(height: AppSpacing.xl),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConseilPanel() {
    if (_loadingConseil) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Text(_error!, style: const TextStyle(color: AppColors.error)),
      );
    }
    if (_conseil == null) {
      return const SizedBox.shrink();
    }

    final etat = _conseil!['etat_global'] as String? ?? 'inconnu';
    final score = _conseil!['score_moyen'] as int? ?? 0;
    final conseil = _conseil!['conseil'] as String? ?? '';
    final impactTemps = _conseil!['impact_temps'] as String? ?? '';
    final points = (_conseil!['points_ralentissement'] as List?)
            ?.cast<String>() ??
        [];
    final meteo = _conseil!['impact_meteo'] as String?;
    final segments = (_conseil!['segments'] as List?)
            ?.cast<Map<String, dynamic>>() ??
        [];
    final alternative = _conseil!['alternative'] as String? ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.md),
        // Carte état global
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: _etatColor(etat).withAlpha(20),
            border: Border.all(color: _etatColor(etat).withAlpha(80)),
            borderRadius: AppRadius.cardBorder,
          ),
          child: Row(
            children: [
              Icon(_etatIcon(etat), color: _etatColor(etat), size: 32),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      etat.toUpperCase(),
                      style: TextStyle(
                        color: _etatColor(etat),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        letterSpacing: 0.8,
                      ),
                    ),
                    Text(
                      'Score $score/100 · $impactTemps',
                      style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        // Texte du conseil
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: AppRadius.cardBorder,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.route_outlined,
                      size: 16, color: AppColors.primary),
                  SizedBox(width: 6),
                  Text('Analyse du trajet',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: AppColors.primary)),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(conseil,
                  style: const TextStyle(
                      fontSize: 14, height: 1.5)),
            ],
          ),
        ),
        if (meteo != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.inondation.withAlpha(20),
              borderRadius: AppRadius.chipBorder,
            ),
            child: Row(
              children: [
                const Icon(Icons.water_drop_outlined,
                    size: 14, color: AppColors.inondation),
                const SizedBox(width: 6),
                Text(
                  meteo == 'fort'
                      ? 'Pluie forte active — zones inondables affectées'
                      : 'Pluie modérée en cours',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.inondation),
                ),
              ],
            ),
          ),
        ],
        if (points.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          const Text('Points de ralentissement',
              style: TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: points
                .map((p) => Chip(
                      label: Text(p,
                          style: const TextStyle(fontSize: 12)),
                      avatar: const Icon(Icons.warning_amber_outlined,
                          size: 14),
                      padding: EdgeInsets.zero,
                      materialTapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                    ))
                .toList(),
          ),
        ],
        if (alternative.isNotEmpty &&
            (etat == 'congestionné' ||
                etat == 'très congestionné' ||
                etat == 'ralenti')) ...[
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.outlineVariant),
              borderRadius: AppRadius.chipBorder,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.alt_route_outlined,
                    size: 16, color: AppColors.onSurfaceVariant),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    alternative,
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
        ],
        // Détail des segments
        if (segments.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          const Text('Détail du corridor',
              style: TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: AppSpacing.xs),
          ...segments.map((seg) {
            final segScore = seg['score'] as int? ?? 0;
            final segEtat = seg['etat'] as String? ?? '';
            final color = _etatColor(segEtat);
            return Padding(
              padding:
                  const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                        color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(seg['nom'] as String? ?? '',
                        style: const TextStyle(fontSize: 13)),
                  ),
                  Text(
                    '$segScore/100',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: color),
                  ),
                ],
              ),
            );
          }),
        ],
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Analyse CityFlow — données temps réel',
          style: const TextStyle(
              fontSize: 11, color: AppColors.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _CorridorTile extends StatelessWidget {
  final Map<String, dynamic> corridor;
  final bool selected;
  final VoidCallback onTap;

  const _CorridorTile({
    required this.corridor,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary.withAlpha(12) : AppColors.surface,
      borderRadius: AppRadius.cardBorder,
      child: InkWell(
        borderRadius: AppRadius.cardBorder,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected
                  ? AppColors.primary
                  : AppColors.outlineVariant,
              width: selected ? 1.5 : 1.0,
            ),
            borderRadius: AppRadius.cardBorder,
            boxShadow: selected ? null : AppShadows.card,
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primary
                      : AppColors.surfaceContainer,
                  borderRadius: AppRadius.chipBorder,
                ),
                child: Icon(
                  Icons.directions_car_outlined,
                  size: 18,
                  color: selected
                      ? AppColors.onPrimary
                      : AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      corridor['nom'] as String? ?? '',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: selected
                            ? AppColors.primary
                            : AppColors.onSurface,
                      ),
                    ),
                    Text(
                      corridor['description'] as String? ?? '',
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: selected
                    ? AppColors.primary
                    : AppColors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
