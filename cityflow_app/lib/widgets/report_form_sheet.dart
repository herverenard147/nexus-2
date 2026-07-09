import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class ReportFormSheet extends StatefulWidget {
  final ApiService api;
  final int segmentId;

  const ReportFormSheet({super.key, required this.api, required this.segmentId});

  @override
  State<ReportFormSheet> createState() => _ReportFormSheetState();
}

class _ReportFormSheetState extends State<ReportFormSheet> {
  static const _types = [
    ('accident', 'Accident'),
    ('nid_de_poule', 'Nid de poule'),
    ('route_barree', 'Route barrée'),
    ('vehicule_en_panne', 'Véhicule en panne'),
  ];

  String _selectedType = 'accident';
  bool _loading = false;
  bool _sent = false;
  bool _merged = false;
  String? _error;

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.api.createReport(widget.segmentId, _selectedType);
      final nb = data['nb_confirmations'] as int? ?? 1;
      setState(() {
        _sent = true;
        _merged = nb > 1;
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
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: _sent ? _buildConfirmation() : _buildForm(),
    );
  }

  Widget _buildConfirmation() => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _merged ? Icons.merge_type : Icons.check_circle_outline,
            color: _merged ? AppColors.inondation : AppColors.fluide,
            size: 52,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            _merged ? 'Signalement fusionné' : 'Signalement envoyé',
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.w600, fontFamily: 'Inter'),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _merged
                ? 'Un incident similaire était déjà signalé.\nVotre confirmation a été prise en compte.'
                : 'Merci pour votre contribution.',
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: AppColors.onSurfaceVariant, height: 1.5),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fermer'),
            ),
          ),
        ],
      );

  Widget _buildForm() => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Signaler un incident',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Inter')),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<String>(
            initialValue: _selectedType,
            items: _types
                .map((t) => DropdownMenuItem(value: t.$1, child: Text(t.$2)))
                .toList(),
            onChanged: (v) => setState(() => _selectedType = v!),
            decoration: const InputDecoration(labelText: "Type d'incident"),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(_error!,
                style: const TextStyle(color: AppColors.bloque, fontSize: 12)),
          ],
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation(AppColors.onPrimary)))
                  : const Text('Envoyer'),
            ),
          ),
        ],
      );
}
