import 'package:fixitzed_fixer_app/models/fixer.dart';

class ServiceRequest {
  final int id;
  final Service service;
  final Customer customer;
  final Fixer? fixer;
  final DateTime? scheduledAt;
  final DateTime? declinedAt;
  final DateTime? snoozedUntil;
  final DateTime? canceledAt;
  final String status;
  final String? location;
  final String? customerContact;
  final bool customerContactVisible;
  final String? cancellationReasonKey;
  final String? cancellationReasonLabel;
  final String? cancellationNote;
  final String? canceledBy;

  ServiceRequest({
    required this.id,
    required this.service,
    required this.customer,
    required this.fixer,
    required this.scheduledAt,
    required this.declinedAt,
    required this.snoozedUntil,
    required this.canceledAt,
    required this.status,
    required this.location,
    required this.customerContact,
    required this.customerContactVisible,
    required this.cancellationReasonKey,
    required this.cancellationReasonLabel,
    required this.cancellationNote,
    required this.canceledBy,
  });

  factory ServiceRequest.fromJson(Map<String, dynamic> j) {
    int parseId(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

    Map<String, dynamic> asMap(dynamic v) =>
        v is Map<String, dynamic> ? v : <String, dynamic>{};

    // Service may be nested as 'service' or provided via flat fields
    final svcMap = asMap(j['service'] ?? j['service_data'] ?? {});
    final custMap = asMap(
      j['customer'] ?? j['user'] ?? (asMap(j['customer_data'])),
    );
    final fixerMap = asMap(
      j['fixer'] ?? j['assigned_to'] ?? j['fixer_data'] ?? {},
    );
    final scheduledRaw = j['scheduled_at'] ?? j['schedule'] ?? j['scheduledAt'];
    bool isTruthy(dynamic value) {
      if (value is bool) return value;
      if (value is num) return value != 0;
      if (value is String) {
        final normalized = value.trim().toLowerCase();
        return normalized == 'true' ||
            normalized == '1' ||
            normalized == 'yes' ||
            normalized == 'y';
      }
      return false;
    }

    String? firstNonEmpty(Iterable<dynamic> values) {
      for (final raw in values) {
        if (raw == null) continue;
        final str = raw.toString().trim();
        if (str.isNotEmpty && str.toLowerCase() != 'null') return str;
      }
      return null;
    }

    final status = (j['status'] ?? j['state'] ?? 'pending').toString();
    final loc = j['location']?.toString();
    final statusLower = status.toLowerCase();
    final contactVisible =
        isTruthy(j['customer_contact_visible']) ||
        statusLower == 'accepted' ||
        statusLower == 'completed';
    final contact = contactVisible
        ? firstNonEmpty([
            j['customer_contact'],
            j['contact'],
            custMap['contact_number'],
            custMap['phone'],
            custMap['mobile'],
            custMap['telephone'],
            custMap['phone_number'],
            custMap['mobile_number'],
            custMap['primary_phone'],
            custMap['contact'],
          ])
        : null;

    // Build Service safely
    final serviceId = parseId(svcMap['id'] ?? j['service_id']);
    final serviceName = (svcMap['name'] ?? j['service_name'] ?? 'Service')
        .toString();

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
        user: User(
          id: 0,
          firstName: null,
          lastName: null,
          email: '',
          profilePhotoUrl: null,
        ),
        bio: null,
        location: null,
        availability: 'available',
        ratingAvg: null,
        services: const [],
        priorityPoints: 0,
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
      declinedAt: (j['declined_at'] is String)
          ? DateTime.tryParse(j['declined_at'])
          : null,
      snoozedUntil: (j['fixer_snoozed_until'] is String)
          ? DateTime.tryParse(j['fixer_snoozed_until'])
          : null,
      canceledAt: (j['canceled_at'] is String)
          ? DateTime.tryParse(j['canceled_at'])
          : null,
      status: status,
      location: loc,
      customerContact: contact,
      customerContactVisible: contactVisible,
      cancellationReasonKey: firstNonEmpty([j['cancellation_reason_key']]),
      cancellationReasonLabel: firstNonEmpty([j['cancellation_reason_label']]),
      cancellationNote: firstNonEmpty([j['cancellation_note']]),
      canceledBy: firstNonEmpty([j['canceled_by']]),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'service': service.toJson(),
      'customer': customer.toJson(),
      'fixer': fixer?.toJson(),
      'scheduled_at': scheduledAt?.toIso8601String(),
      'declined_at': declinedAt?.toIso8601String(),
      'fixer_snoozed_until': snoozedUntil?.toIso8601String(),
      'canceled_at': canceledAt?.toIso8601String(),
      'status': status,
      'location': location,
      'customer_contact': customerContact,
      'customer_contact_visible': customerContactVisible,
      'cancellation_reason_key': cancellationReasonKey,
      'cancellation_reason_label': cancellationReasonLabel,
      'cancellation_note': cancellationNote,
      'canceled_by': canceledBy,
    };
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

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}
