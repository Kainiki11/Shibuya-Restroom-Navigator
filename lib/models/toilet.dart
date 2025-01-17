class Toilet {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String type;
  final bool wheelchairAccessible;
  final bool ostomateFriendly;

  Toilet({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.type,
    required this.wheelchairAccessible,
    required this.ostomateFriendly,
  });

  factory Toilet.fromJson(Map<String, dynamic> json) {
    return Toilet(
      id: json['id'],
      name: json['name'],
      latitude: json['latitude'],
      longitude: json['longitude'],
      type: json['type'],
      wheelchairAccessible: json['wheelchairAccessible'],
      ostomateFriendly: json['ostomateFriendly'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'type': type,
      'wheelchairAccessible': wheelchairAccessible,
      'ostomateFriendly': ostomateFriendly,
    };
  }
}
