class Plan {
  final int id;
  final String name;
  final int durationDays;
  final double price;
  final String currency;

  Plan({required this.id, required this.name, required this.durationDays, required this.price, required this.currency});

  factory Plan.fromJson(Map<String, dynamic> j) => Plan(
        id: j['id'] as int,
        name: j['name'] as String,
        durationDays: j['duration_days'] as int,
        price: (j['price'] as num).toDouble(),
        currency: (j['currency'] ?? 'ZMW') as String,
      );
}

class Subscription {
  final int id;
  final Plan plan;
  final String status;
  final DateTime? startedAt;
  final DateTime? expiresAt;
  final String? paymentStatus;

  Subscription({
    required this.id,
    required this.plan,
    required this.status,
    required this.startedAt,
    required this.expiresAt,
    required this.paymentStatus,
  });

  factory Subscription.fromJson(Map<String, dynamic> j) => Subscription(
        id: j['id'] as int,
        plan: Plan.fromJson(j['plan'] as Map<String, dynamic>),
        status: j['status'] as String,
        startedAt: j['started_at'] == null ? null : DateTime.parse(j['started_at'] as String),
        expiresAt: j['expires_at'] == null ? null : DateTime.parse(j['expires_at'] as String),
        paymentStatus: j['payment_status'] as String?,
      );
}

