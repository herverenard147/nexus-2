class Prediction {
  final int id;
  final int segmentId;
  final String segmentNom;
  final String segmentZone;
  final int scorePredit;
  final Map<String, dynamic> facteurs;
  final String versionModele;

  const Prediction({
    required this.id,
    required this.segmentId,
    required this.segmentNom,
    required this.segmentZone,
    required this.scorePredit,
    required this.facteurs,
    required this.versionModele,
  });

  factory Prediction.fromJson(Map<String, dynamic> j) => Prediction(
        id: j['id'] as int,
        segmentId: j['segment'] as int,
        segmentNom: j['segment_nom'] as String? ?? '',
        segmentZone: j['segment_zone'] as String? ?? '',
        scorePredit: j['score_predit'] as int,
        facteurs: Map<String, dynamic>.from(j['facteurs'] as Map? ?? {}),
        versionModele: j['version_modele'] as String? ?? 'v1',
      );

  /// Niveau de risque : 0 = fluide, 1 = modéré, 2 = critique
  int get niveauRisque {
    if (scorePredit < 40) return 0;
    if (scorePredit < 70) return 1;
    return 2;
  }
}
