import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/fixer.dart';
import '../models/service_request.dart';
import 'api_client.dart';
import 'local_notification_service.dart';

class FixerService {
  final _api = ApiClient.I;

  Future<Map<String, dynamic>?> dashboard() async {
    final res = await _api.get('/api/fixer/dashboard');
    if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    return null;
  }

  Future<List<ServiceRequest>> requests({String? status}) async {
    final res = await _api.get('/api/fixer/requests', query: {
      if (status != null) 'status': status,
    });
    if (res.statusCode != 200) return [];
    final root = jsonDecode(res.body);
    List<dynamic>? list;
    if (root is List) {
      list = root;
    } else if (root is Map<String, dynamic>) {
      // common patterns: { data: [...] } or { data: { data: [...] } } or { requests: [...] }
      final data = root['data'];
      if (data is List) list = data;
      if (data is Map && data['data'] is List) list = data['data'] as List;
      if (list == null && root['requests'] is List) list = root['requests'] as List;
      // fallback: first array value in map
      list ??= root.values.firstWhere(
        (v) => v is List,
        orElse: () => const [],
      ) as List;
    }
    final requests = (list ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(ServiceRequest.fromJson)
        .toList();
    unawaited(_notifyAssignments(requests));
    return requests;
  }

  /// Try to fetch unassigned/eligible requests for this fixer.
  /// If the backend doesn't expose this route, returns an empty list.
  Future<List<ServiceRequest>> unassigned() async {
    final res = await _api.get('/api/fixer/requests/unassigned');
    if (res.statusCode == 200) {
      final root = jsonDecode(res.body);
      List list;
      if (root is Map<String, dynamic>) {
        final data = root['data'];
        list = (data is Map<String, dynamic>) ? (data['data'] as List? ?? []) : (data as List? ?? []);
      } else if (root is List) {
        list = root;
      } else {
        list = [];
      }
      final requests =
          list.whereType<Map<String, dynamic>>().map(ServiceRequest.fromJson).toList();
      unawaited(_notifyAssignments(requests));
      return requests;
    }
    return [];
  }

  Future<List<ServiceRequest>> requestsToday() async {
    final res = await _api.get('/api/fixer/requests/today');
    if (res.statusCode == 200) {
      final list = jsonDecode(res.body) as List;
      return list.map((e) => ServiceRequest.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  Future<ServiceRequest?> transition(int id, String action) async {
    final res = await _api.patch('/api/fixer/requests/$id/$action', body: {});
    if (res.statusCode == 200) {
      return ServiceRequest.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    }
    return null;
  }

  // Accept a service request for this fixer according to provided routes
  Future<bool> acceptRequest(int id) async {
    final res = await _api.post('/api/service-requests/$id/accept', body: {});
    return res.statusCode == 200 || res.statusCode == 201;
  }

  // Update a request status (e.g., completed, cancelled)
  Future<bool> updateStatus(int id, String status) async {
    final res = await _api.patch('/api/requests/$id', body: {'status': status});
    return res.statusCode >= 200 && res.statusCode < 300;
  }

  // Fetch a single request detail (may include contact info)
  Future<Map<String, dynamic>?> requestDetail(int id) async {
    final res = await _api.get('/api/requests/$id');
    if (res.statusCode != 200) return null;
    final root = jsonDecode(res.body);
    if (root is Map<String, dynamic>) {
      // Prefer data if exists
      if (root['data'] is Map<String, dynamic>) {
        return Map<String, dynamic>.from(root['data'] as Map);
      }
      return Map<String, dynamic>.from(root);
    }
    return null;
  }

  Future<bool> createPayment(int id, double amount) async {
    // Only customers can create payments on backend
    return false;
  }

  Future<bool> createBill(int id, double amount) async {
    final res = await _api.post('/api/fixer/requests/$id/bill', body: {
      'amount': amount,
    });
    return res.statusCode >= 200 && res.statusCode < 300;
  }

  // Wallet: balance and coins remaining
  Future<Map<String, dynamic>> wallet() async {
    final res = await _api.get('/api/fixer/wallet');
    if (res.statusCode == 200) {
      final root = jsonDecode(res.body) as Map<String, dynamic>;
      final data = (root['data'] ?? root) as Map<String, dynamic>;
      return data;
    }
    return {};
  }

  Future<Fixer?> updateMe({String? bio, String? availability, List<int>? serviceIds}) async {
    final body = <String, dynamic>{
      if (bio != null) 'bio': bio,
      if (availability != null) 'availability': availability,
      if (serviceIds != null) 'service_ids': serviceIds,
    };
    final res = await _api.patch('/api/fixer/me', body: body);
    if (res.statusCode == 200) {
      return Fixer.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    }
    return null;
  }

  Future<bool> uploadAvatar(String filePath) async {
    final req = await _api.multipart('/api/me/avatar', method: 'POST');
    req.files.add(await http.MultipartFile.fromPath('avatar', filePath));
    final streamed = await req.send();
    return streamed.statusCode == 200;
  }

  Future<void> _notifyAssignments(List<ServiceRequest> requests) async {
    try {
      if (requests.isEmpty) return;
      final prefs = await SharedPreferences.getInstance();
      final seen = prefs.getStringList('fixer_seen_request_ids')?.toSet() ?? <String>{};
      final newIds = <String>[];

      for (final req in requests) {
        final id = req.id.toString();
        if (seen.contains(id)) continue;
        newIds.add(id);

        final service = req.service.name;
        final scheduled = req.scheduledAt != null
            ? DateFormat('d MMM HH:mm').format(req.scheduledAt!.toLocal())
            : null;
        final body = scheduled != null ? '$service • $scheduled' : service;

        await LocalNotificationService.instance.showInstant(
          id: req.id,
          title: 'New service request',
          body: body,
          payload: 'fixer_request:${req.id}',
        );
      }

      if (newIds.isNotEmpty) {
        seen.addAll(newIds);
        await prefs.setStringList('fixer_seen_request_ids', seen.toList());
      }
    } catch (_) {
      // Ignore notification errors to keep UX smooth.
    }
  }
}
