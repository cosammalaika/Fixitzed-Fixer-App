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
        id: j['id'] as int,
        user: User.fromJson(j['user'] as Map<String, dynamic>),
        bio: j['bio'] as String?,
        availability: (j['availability'] ?? 'available') as String,
        ratingAvg: j['rating_avg'] == null ? null : (j['rating_avg'] as num).toDouble(),
        services: ((j['services'] ?? []) as List)
            .map((e) => Service.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
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
}

class Service {
  final int id;
  final String name;
  final double? price;

  Service({required this.id, required this.name, this.price});

  factory Service.fromJson(Map<String, dynamic> j) => Service(
        id: j['id'] as int,
        name: j['name'] as String,
        price: j['price'] == null ? null : (j['price'] as num).toDouble(),
      );
}

