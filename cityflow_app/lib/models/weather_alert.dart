class WeatherAlert {
  final int id;
  final String nom;
  final String zone;

  const WeatherAlert({required this.id, required this.nom, required this.zone});

  factory WeatherAlert.fromJson(Map<String, dynamic> j) => WeatherAlert(
        id: j['id'] as int,
        nom: j['nom'] as String,
        zone: j['zone'] as String,
      );
}
