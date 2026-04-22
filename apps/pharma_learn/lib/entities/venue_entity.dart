/// Venue entity for auto-generated CRUD screens.
class Venue {
  final String id;
  final String organizationId;
  final String name;
  final String? venueCode;
  final String? address;
  final int? capacity;
  final String? building;
  final String? floor;
  final String? room;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;
  
  Venue({
    required this.id,
    required this.organizationId,
    required this.name,
    this.venueCode,
    this.address,
    this.capacity,
    this.building,
    this.floor,
    this.room,
    required this.isActive,
    required this.createdAt,
    this.updatedAt,
  });
  
  factory Venue.fromJson(Map<String, dynamic> json) {
    return Venue(
      id: json['id'],
      organizationId: json['organization_id'],
      name: json['name'],
      venueCode: json['venue_code'],
      address: json['address'],
      capacity: json['capacity'],
      building: json['building'],
      floor: json['floor'],
      room: json['room'],
      isActive: json['is_active'] ?? true,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at']) 
          : null,
    );
  }
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'organization_id': organizationId,
    'name': name,
    'venue_code': venueCode,
    'address': address,
    'capacity': capacity,
    'building': building,
    'floor': floor,
    'room': room,
    'is_active': isActive,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
  };
}
