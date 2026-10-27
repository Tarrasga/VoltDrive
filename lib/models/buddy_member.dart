import 'dart:math' as math;

class BuddyMember {
  final String id;
  final String name;
  final String vehicle;
  final double latitude;
  final double longitude;
  final double speedKmH;
  final int batteryPercent;
  final String status; // 'A Rodar', 'Em Pausa', 'A Carregar', 'SOS'
  final bool isSosActive;
  final String sosMessage;
  final DateTime updatedAt;

  BuddyMember({
    required this.id,
    required this.name,
    required this.vehicle,
    required this.latitude,
    required this.longitude,
    required this.speedKmH,
    required this.batteryPercent,
    required this.status,
    required this.isSosActive,
    required this.sosMessage,
    required this.updatedAt,
  });

  factory BuddyMember.fromJson(Map<String, dynamic> json) {
    return BuddyMember(
      id: json['id'] as String? ?? 'buddy-${DateTime.now().millisecondsSinceEpoch}',
      name: json['name'] as String? ?? 'Colega TVDE',
      vehicle: json['vehicle'] as String? ?? 'Renault Zoe Z.E.',
      latitude: (json['lat'] as num?)?.toDouble() ?? 38.65,
      longitude: (json['lng'] as num?)?.toDouble() ?? -9.15,
      speedKmH: (json['speed'] as num?)?.toDouble() ?? 0.0,
      batteryPercent: json['battery'] as int? ?? 50,
      status: json['status'] as String? ?? 'A Rodar',
      isSosActive: json['isSos'] as bool? ?? false,
      sosMessage: json['sosMessage'] as String? ?? '',
      updatedAt: json['time'] != null
          ? DateTime.tryParse(json['time'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'vehicle': vehicle,
      'lat': latitude,
      'lng': longitude,
      'speed': speedKmH,
      'battery': batteryPercent,
      'status': status,
      'isSos': isSosActive,
      'sosMessage': sosMessage,
      'time': updatedAt.toIso8601String(),
    };
  }

  String get googleMapsUrl => 'https://maps.google.com/?q=$latitude,$longitude';

  double distanceToKm(double myLat, double myLng) {
    const double p = 0.017453292519943295; // Math.PI / 180
    final double a = 0.5 -
        math.cos((myLat - latitude) * p) / 2 +
        math.cos(latitude * p) *
            math.cos(myLat * p) *
            (1 - math.cos((myLng - longitude) * p)) /
            2;
    return 12742 * math.asin(math.sqrt(a)); // 2 * R; R = 6371 km
  }
}
