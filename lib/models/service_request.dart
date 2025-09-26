import 'fixer.dart';

class ServiceRequest {
  final int id;
  final Service service;
  final Customer customer;
  final Fixer? fixer;
  final DateTime? scheduledAt;
  final String status; // pending|accepted|ongoing|completed|cancelled
  final String? location;

  ServiceRequest({
    required this.id,
    required this.service,
    required this.customer,
    required this.fixer,
    required this.scheduledAt,
    required this.status,
    required this.location,
  });

  factory ServiceRequest.fromJson(Map<String, dynamic> j) => ServiceRequest(
        id: j['id'] as int,
        service: Service.fromJson(j['service'] as Map<String, dynamic>),
        customer: Customer.fromJson(j['customer'] as Map<String, dynamic>),
        fixer: j['fixer'] == null ? null : Fixer.fromJson(j['fixer'] as Map<String, dynamic>),
        scheduledAt: j['scheduled_at'] == null ? null : DateTime.parse(j['scheduled_at'] as String),
        status: j['status'] as String,
        location: j['location'] as String?,
      );
}

class Customer {
  final int id;
  final String name;
  Customer({required this.id, required this.name});
  factory Customer.fromJson(Map<String, dynamic> j) => Customer(
        id: j['id'] as int,
        name: (j['name'] ?? '${j['first_name'] ?? ''} ${j['last_name'] ?? ''}').toString().trim(),
      );
}

