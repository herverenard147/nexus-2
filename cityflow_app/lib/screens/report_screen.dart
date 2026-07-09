import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../models/prediction.dart';

const _kTypes = [
  ('embouteillage', Icons.traffic, 'Embouteillage'),
  ('accident', Icons.car_crash_outlined, 'Accident'),
  ('travaux', Icons.construction_outlined, 'Travaux'),
  ('inondation', Icons.water_outlined, 'Inondation'),
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
  String _type = 'embouteillage';
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
      final preds = await widget.api.getPredictions();
      setState(() {
        _segments = preds;
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
      final data = await widget.api.createReport(_selected!.segmentId, _type);
      final nbConf = data['nb_confirmations'] as int? ?? 1;
      setState(() {
        _result = _SubmitResult(merged: nbConf > 1, nbConfirmations: nbConf);
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.bloque),
            const SizedBox(height: AppSpacing.sm),
            Text(_error!, style: const TextStyle(color: AppColors.onSurfaceVariant)),
            const SizedBox(height: AppSpacing.md),
            ElevatedButton(onPressed: _loadSegments, child: const Text('Réessayer')),
          ],
        ),
      );
    }

    if (_result != null) return _ResultView(result: _result!, onReset: () => setState(() => _result = null));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.containerMargin),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Signaler un incident',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.xs),
          Text('2 étapes — segment puis type',
              style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 13)),
          const SizedBox(height: AppSpacing.lg),
          // Étape 1 — segment
          _StepHeader(number: '1', label: 'Segment concerné'),
          const SizedBox(height: AppSpacing.sm),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.cardBorder,
              border: Border.all(color: AppColors.outlineVariant),
              boxShadow: AppShadows.card,
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<Prediction>(
                value: _selected,
                hint: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: Text('Sélectionner un segment…'),
                ),
                isExpanded: true,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                borderRadius: AppRadius.cardBorder,
                items: (_segments ?? []).map((p) {
                  return DropdownMenuItem(
                    value: p,
                    child: Text('${p.segmentNom} — ${p.segmentZone}',
                        overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                onChanged: (v) => setState(() {
                  _selected = v;
                  _result = null;
                }),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          // Étape 2 — type
          _StepHeader(number: '2', label: "Type d'incident"),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: _kTypes.map((t) {
              final selected = _type == t.$1;
              return GestureDetector(
                onTap: () => setState(() => _type = t.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.primary
                        : AppColors.surface,
                    borderRadius: AppRadius.chipBorder,
                    border: Border.all(
                        color: selected
                            ? AppColors.primary
                            : AppColors.outlineVariant),
                    boxShadow: selected ? [] : AppShadows.card,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(t.$2,
                          size: 16,
                          color: selected
                              ? AppColors.onPrimary
                              : AppColors.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Text(t.$3,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: selected
                                  ? AppColors.onPrimary
                                  : AppColors.onSurface)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpacing.xl),
          ElevatedButton.icon(
            onPressed: (_selected == null || _submitting) ? null : _submit,
            icon: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(AppColors.onPrimary)))
                : const Icon(Icons.send_outlined),
            label: const Text('Envoyer le signalement'),
          ),
        ],
      ),
    );
  }
}

class _StepHeader extends StatelessWidget {
  final String number;
  final String label;
  const _StepHeader({required this.number, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
              color: AppColors.primary, shape: BoxShape.circle),
          child: Center(
            child: Text(number,
                style: const TextStyle(
                    color: AppColors.onPrimary,
                    fontSize: 12,
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

class _SubmitResult {
  final bool merged;
  final int nbConfirmations;
  final String? error;
  const _SubmitResult({this.merged = false, this.nbConfirmations = 1, this.error});
}

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
              const Icon(Icons.error_outline, size: 56, color: AppColors.bloque),
              const SizedBox(height: AppSpacing.md),
              Text(result.error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.onSurface)),
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton(onPressed: onReset, child: const Text('Réessayer')),
            ],
          ),
        ),
      );
    }

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
                color: result.merged
                    ? AppColors.inondation.withValues(alpha: 0.1)
                    : AppColors.fluide.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                result.merged ? Icons.merge_type : Icons.check_circle_outline,
                size: 40,
                color: result.merged ? AppColors.inondation : AppColors.fluide,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              result.merged ? 'Signalement fusionné' : 'Signalement envoyé',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              result.merged
                  ? 'Un signalement similaire existe déjà.\n${result.nbConfirmations} confirmations enregistrées.'
                  : 'Votre signalement a bien été transmis.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppColors.onSurfaceVariant, height: 1.5),
            ),
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
