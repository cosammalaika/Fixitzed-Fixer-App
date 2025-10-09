class Fixer {
  final int id;
  final User user;
  final String? bio;
  final String availability; // available|busy|offline
  final double? ratingAvg;
  final List<Service> services;

  Fixer({
    required this.id,
    required this.user,
    required this.bio,
    required this.availability,
    required this.ratingAvg,
    required this.services,
  });

  factory Fixer.fromJson(Map<String, dynamic> j) => Fixer(
    id: _parseId(j['id']) ?? 0,
    user: User.fromJson(_asMap(j['user'])),
    bio: j['bio'] as String?,
    availability: (j['availability'] ?? 'available').toString(),
    ratingAvg: j['rating_avg'] == null
        ? null
        : (j['rating_avg'] as num).toDouble(),
    services: ((j['services'] ?? []) as List)
        .map((entry) {
          if (entry is Map) {
            return Service.fromJson(_asMap(entry));
          }
          final id = _parseId(entry);
          if (id == null) return null;
          return Service(id: id, name: 'Service #$id');
        })
        .whereType<Service>()
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'user': user.toJson(),
    'bio': bio,
    'availability': availability,
    'rating_avg': ratingAvg,
    'services': services.map((s) => s.toJson()).toList(),
  };
}

class User {
  final int id;
  final String? firstName;
  final String? lastName;
  final String email;
  final String? profilePhotoUrl;

  User({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.profilePhotoUrl,
  });

  factory User.fromJson(Map<String, dynamic> j) => User(
    id: j['id'] as int,
    firstName: j['first_name'] as String?,
    lastName: j['last_name'] as String?,
    email: j['email'] as String,
    profilePhotoUrl: j['profile_photo_url'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'first_name': firstName,
    'last_name': lastName,
    'email': email,
    'profile_photo_url': profilePhotoUrl,
  };
}

class Service {
  final int id;
  final String name;
  final double? price;

  Service({required this.id, required this.name, this.price});

  factory Service.fromJson(Map<String, dynamic> j) => Service(
    id: _parseId(j['id']) ?? 0,
    name: (j['name'] ?? j['title'] ?? 'Service').toString(),
    price: j['price'] == null
        ? null
        : (j['price'] is num)
        ? (j['price'] as num).toDouble()
        : double.tryParse(j['price'].toString()),
  );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'price': price};
}

int? _parseId(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  if (value is Map) {
    final map = _asMap(value);
    return _parseId(map['id'] ?? map['service_id'] ?? map['serviceId']);
  }
  return null;
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}
