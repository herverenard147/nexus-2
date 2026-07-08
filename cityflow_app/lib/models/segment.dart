class RoadSegment {
  final int id;
  final String nom;
  final double latitude;
  final double longitude;
  final String zone;
  final bool zoneInondable;

  const RoadSegment({
    required this.id,
    required this.nom,
    required this.latitude,
    required this.longitude,
    required this.zone,
    required this.zoneInondable,
  });

  factory RoadSegment.fromJson(Map<String, dynamic> j) => RoadSegment(
        id: j['id'] as int,
        nom: j['nom'] as String,
        latitude: (j['latitude'] as num).toDouble(),
        longitude: (j['longitude'] as num).toDouble(),
        zone: j['zone'] as String,
        zoneInondable: j['zone_inondable'] as bool? ?? false,
      );
}
