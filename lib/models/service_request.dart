import 'fixer.dart';

class ServiceRequest {
  final int id;
  final Service service;
  final Customer customer;
  final Fixer? fixer;
  final DateTime? scheduledAt;
  final String status; // pending|accepted|ongoing|completed|cancelled
  final String? location;
  final String? customerContact;
  final bool customerContactVisible;

  ServiceRequest({
    required this.id,
    required this.service,
    required this.customer,
    required this.fixer,
    required this.scheduledAt,
    required this.status,
    required this.location,
    required this.customerContact,
    required this.customerContactVisible,
  });

  factory ServiceRequest.fromJson(Map<String, dynamic> j) {
    int parseId(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

    Map<String, dynamic> asMap(dynamic v) => v is Map<String, dynamic> ? v : <String, dynamic>{};

    // Service may be nested as 'service' or provided via flat fields
    final svcMap = asMap(j['service'] ?? j['service_data'] ?? {});
    final custMap = asMap(j['customer'] ?? j['user'] ?? (asMap(j['customer_data'])));
    final fixerMap = asMap(j['fixer'] ?? j['assigned_to'] ?? j['fixer_data'] ?? {});
    final scheduledRaw = j['scheduled_at'] ?? j['schedule'] ?? j['scheduledAt'];
    final status = (j['status'] ?? j['state'] ?? 'pending').toString();
    final loc = j['location']?.toString();
    final contactVisible = (j['customer_contact_visible'] == true);
    String? contact;
    if (contactVisible && custMap.isNotEmpty) {
      final rawContact = custMap['contact_number'] ?? custMap['phone'] ?? custMap['mobile'] ?? custMap['telephone'];
      if (rawContact != null) {
        final str = rawContact.toString().trim();
        if (str.isNotEmpty) contact = str;
      }
    }

    // Build Service safely
    final serviceId = parseId(svcMap['id'] ?? j['service_id']);
    final serviceName = (svcMap['name'] ?? j['service_name'] ?? 'Service').toString();

    // Build Customer safely
    Customer customer;
    if (custMap.isNotEmpty) {
      customer = Customer.fromJson(custMap);
    } else {
      final cid = parseId(j['customer_id']);
      final cname = (j['customer_name'] ?? j['customer'] ?? '').toString();
      customer = Customer(id: cid, name: cname.isNotEmpty ? cname : 'Customer');
    }

    // Optional fixer
    Fixer? fixer;
    if (fixerMap.isNotEmpty) {
      fixer = Fixer.fromJson(fixerMap);
    } else if (j['fixer_id'] != null) {
      // Minimal placeholder when only fixer_id known
      fixer = Fixer(
        id: parseId(j['fixer_id']),
        user: User(id: 0, firstName: null, lastName: null, email: '', profilePhotoUrl: null),
        bio: null,
        availability: 'available',
        ratingAvg: null,
        services: const [],
      );
    }

    return ServiceRequest(
      id: parseId(j['id']),
      service: Service(id: serviceId, name: serviceName, price: null),
      customer: customer,
      fixer: fixer,
      scheduledAt: (scheduledRaw is String && scheduledRaw.isNotEmpty)
          ? DateTime.tryParse(scheduledRaw)
          : null,
      status: status,
      location: loc,
      customerContact: contact,
      customerContactVisible: contactVisible,
    );
  }
}

class Customer {
  final int id;
  final String name;
  Customer({required this.id, required this.name});
  factory Customer.fromJson(Map<String, dynamic> j) {
    int parseId(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }
    final first = (j['first_name'] ?? j['firstName'] ?? '').toString();
    final last = (j['last_name'] ?? j['lastName'] ?? '').toString();
    final combined = ('$first $last').trim();
    final name = (j['name'] ?? j['full_name'] ?? combined).toString().trim();
    return Customer(id: parseId(j['id']), name: name);
  }
}
