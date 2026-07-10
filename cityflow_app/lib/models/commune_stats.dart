class CommuneStats {
  final String zone;
  final int nbSegments;
  final int scoreMoyen;
  final int scoreMax;
  final int nbCritiques;

  const CommuneStats({
    required this.zone,
    required this.nbSegments,
    required this.scoreMoyen,
    required this.scoreMax,
    required this.nbCritiques,
  });

  factory CommuneStats.fromJson(Map<String, dynamic> j) => CommuneStats(
        zone: j['zone'] as String,
        nbSegments: (j['nb_segments'] as num).toInt(),
        scoreMoyen: (j['score_moyen'] as num).toInt(),
        scoreMax: (j['score_max'] as num).toInt(),
        nbCritiques: (j['nb_critiques'] as num).toInt(),
      );

  int get niveauRisque {
    if (scoreMoyen < 40) return 0;
    if (scoreMoyen < 70) return 1;
    return 2;
  }
}
