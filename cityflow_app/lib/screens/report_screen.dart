import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../models/prediction.dart';

const _kTypes = [
  ('accident', Icons.car_crash_outlined, 'Accident'),
  ('nid_de_poule', Icons.warning_amber_outlined, 'Nid de poule'),
  ('route_barree', Icons.block_outlined, 'Route barrée'),
  ('vehicule_en_panne', Icons.directions_car_outlined, 'Véhicule en panne'),
];

class ReportScreen extends StatefulWidget {
  final ApiService api;
  const ReportScreen({super.key, required this.api});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  List<Prediction>? _segments;
  bool _loading = true;
  String? _error;
  Prediction? _selected;
  String _type = 'accident';
  bool _submitting = false;
  _SubmitResult? _result;

  @override
  void initState() {
    super.initState();
    _loadSegments();
  }

  Future<void> _loadSegments() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await widget.api.getPredictions(limit: 100, offset: 0);
      setState(() {
        _segments = page.results;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _submit() async {
    if (_selected == null) return;
    setState(() {
      _submitting = true;
      _result = null;
    });
    try {
      final data =
          await widget.api.createReport(_selected!.segmentId, _type);
      final nbConf = data['nb_confirmations'] as int? ?? 1;
      setState(() {
        _result =
            _SubmitResult(merged: nbConf > 1, nbConfirmations: nbConf);
        _submitting = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _result = _SubmitResult(error: e.message);
        _submitting = false;
      });
    } catch (e) {
      setState(() {
        _result = _SubmitResult(error: 'Erreur réseau. Réessayez.');
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.containerMargin),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  size: 48, color: AppColors.bloque),
              const SizedBox(height: AppSpacing.sm),
              Text(_error!,
                  style: const TextStyle(
                      color: AppColors.onSurfaceVariant)),
              const SizedBox(height: AppSpacing.md),
              ElevatedButton(
                  onPressed: _loadSegments,
                  child: const Text('Réessayer')),
            ],
          ),
        ),
      );
    }

    if (_result != null) {
      return _ResultView(
          result: _result!,
          onReset: () => setState(() => _result = null));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.containerMargin,
        AppSpacing.lg,
        AppSpacing.containerMargin,
        AppSpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // En-tête
          Text('Signaler un incident',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 4),
          const Text(
            '2 étapes — segment puis type d\'incident',
            style: TextStyle(
                fontSize: 14, color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.xl),

          // Étape 1 : sélection du segment
          const _StepHeader(number: '1', label: 'Axe concerné'),
          const SizedBox(height: AppSpacing.sm),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.cardBorder,
              border: Border.all(
                color: _selected != null
                    ? AppColors.primary
                    : AppColors.outlineVariant,
                width: _selected != null ? 1.5 : 1.0,
              ),
              boxShadow: AppShadows.card,
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<Prediction>(
                value: _selected,
                hint: const Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.md),
                  child: Text(
                    'Sélectionner un segment…',
                    style:
                        TextStyle(color: AppColors.onSurfaceVariant),
                  ),
                ),
                isExpanded: true,
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md),
                borderRadius: AppRadius.cardBorder,
                items: (_segments ?? []).map((p) {
                  return DropdownMenuItem(
                    value: p,
                    child: Text(
                      '${p.segmentNom} — ${p.segmentZone}',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14),
                    ),
                  );
                }).toList(),
                onChanged: (v) => setState(() {
                  _selected = v;
                  _result = null;
                }),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // Étape 2 : type d'incident en grid 2×2
          const _StepHeader(number: '2', label: "Type d'incident"),
          const SizedBox(height: AppSpacing.sm),
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: AppSpacing.sm,
            mainAxisSpacing: AppSpacing.sm,
            childAspectRatio: 1.6,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: _kTypes.map((t) {
              final selected = _type == t.$1;
              return _TypeCard(
                icon: t.$2,
                label: t.$3,
                selected: selected,
                onTap: () => setState(() => _type = t.$1),
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpacing.xl),

          // Bouton d'envoi
          ElevatedButton.icon(
            onPressed:
                (_selected == null || _submitting) ? null : _submit,
            icon: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(
                            AppColors.onPrimary)),
                  )
                : const Icon(Icons.send_outlined),
            label: const Text('Envoyer le signalement'),
          ),
          if (_selected == null) ...[
            const SizedBox(height: AppSpacing.xs),
            const Center(
              child: Text(
                'Sélectionnez un segment pour continuer',
                style: TextStyle(
                    fontSize: 12,
                    color: AppColors.onSurfaceVariant),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── TypeCard ───────────────────────────────────────────────────────────────────

class _TypeCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TypeCard({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        color: selected ? AppColors.primary : AppColors.surface,
        borderRadius: AppRadius.cardBorder,
        border: Border.all(
          color:
              selected ? AppColors.primary : AppColors.outlineVariant,
          width: selected ? 1.5 : 1.0,
        ),
        boxShadow: selected ? [] : AppShadows.card,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.cardBorder,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 28,
                color: selected
                    ? AppColors.onPrimary
                    : AppColors.primary,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? AppColors.onPrimary
                      : AppColors.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── StepHeader ─────────────────────────────────────────────────────────────────

class _StepHeader extends StatelessWidget {
  final String number;
  final String label;
  const _StepHeader({required this.number, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: const BoxDecoration(
              color: AppColors.primary, shape: BoxShape.circle),
          child: Center(
            child: Text(number,
                style: const TextStyle(
                    color: AppColors.onPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: AppColors.onSurface)),
      ],
    );
  }
}

// ── SubmitResult ───────────────────────────────────────────────────────────────

class _SubmitResult {
  final bool merged;
  final int nbConfirmations;
  final String? error;
  const _SubmitResult(
      {this.merged = false, this.nbConfirmations = 1, this.error});
}

// ── ResultView ─────────────────────────────────────────────────────────────────

class _ResultView extends StatelessWidget {
  final _SubmitResult result;
  final VoidCallback onReset;
  const _ResultView({required this.result, required this.onReset});

  @override
  Widget build(BuildContext context) {
    if (result.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.containerMargin),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.bloque.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.error_outline,
                    size: 36, color: AppColors.bloque),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Une erreur est survenue',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.xs),
              Text(result.error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: AppColors.onSurfaceVariant, height: 1.5)),
              const SizedBox(height: AppSpacing.xl),
              ElevatedButton(
                  onPressed: onReset,
                  child: const Text('Réessayer')),
            ],
          ),
        ),
      );
    }

    final isMerged = result.merged;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.containerMargin),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icône de confirmation
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color:
                    (isMerged ? AppColors.inondation : AppColors.fluide)
                        .withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isMerged
                    ? Icons.merge_type
                    : Icons.check_circle_outline,
                size: 42,
                color: isMerged
                    ? AppColors.inondation
                    : AppColors.fluide,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              isMerged ? 'Signalement regroupé' : 'Merci !',
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              isMerged
                  ? 'Un incident similaire est déjà signalé sur cet axe.'
                  : 'Votre alerte a été transmise aux équipes concernées.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 14,
                  height: 1.6),
            ),
            // Fusion visible : compteur de confirmations
            if (isMerged) ...[
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs),
                decoration: BoxDecoration(
                  color:
                      AppColors.inondation.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.people_outline,
                        size: 16, color: AppColors.inondation),
                    const SizedBox(width: 6),
                    Text(
                      '${result.nbConfirmations} citoyen${result.nbConfirmations > 1 ? 's ont' : ' a'} confirmé cet incident',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.inondation,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            ElevatedButton(
              onPressed: onReset,
              child: const Text('Nouveau signalement'),
            ),
          ],
        ),
      ),
    );
  }
}
