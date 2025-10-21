// ignore_for_file: unnecessary_cast

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fixitzed_fixer_app/models/fixer.dart';
import 'package:fixitzed_fixer_app/models/service_request.dart';
import 'package:fixitzed_fixer_app/services/api_client.dart';
import 'package:fixitzed_fixer_app/services/local_notification_service.dart';
import 'package:fixitzed_fixer_app/state/app_sync.dart';

class FixerService {
  FixerService({AppSync? sync}) : _sync = sync ?? AppSync.instance;

  final AppSync _sync;
  final _api = ApiClient.I;
  static final ValueNotifier<int?> priorityPointsNotifier =
      ValueNotifier<int?>(null);

  static void broadcastPriorityPoints(int? value) {
    if (priorityPointsNotifier.value != value) {
      priorityPointsNotifier.value = value;
    }
  }

  Future<Map<String, dynamic>?> dashboard() async {
    final res = await _api.get('/api/fixer/dashboard');
    if (res.statusCode == 200)
      return jsonDecode(res.body) as Map<String, dynamic>;
    return null;
  }

  Future<List<ServiceRequest>> requests({String? status}) async {
    final res = await _api.get(
      '/api/fixer/requests',
      query: {if (status != null) 'status': status},
    );
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
      if (list == null && root['requests'] is List)
        list = root['requests'] as List;
      // fallback: first array value in map
      list ??=
          root.values.firstWhere((v) => v is List, orElse: () => const [])
              as List;
    }
    final requests = (list ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(ServiceRequest.fromJson)
        .toList();
    unawaited(_notifyAssignments(requests));
    if (status == 'declined') {
      for (final req in requests) {
        _declinedCache[req.id] = req.toJson();
      }
    }
    final priority = requests
        .map((req) => req.fixer?.priorityPoints)
        .whereType<int>()
        .fold<int?>(null, (prev, element) => prev ?? element);
    if (priority != null) {
      broadcastPriorityPoints(priority);
    }

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
        list = (data is Map<String, dynamic>)
            ? (data['data'] as List? ?? [])
            : (data as List? ?? []);
      } else if (root is List) {
        list = root;
      } else {
        list = [];
      }
      final requests = list
          .whereType<Map<String, dynamic>>()
          .map(ServiceRequest.fromJson)
          .toList();
      unawaited(_notifyAssignments(requests));
      return requests;
    }
    return [];
  }

  Future<List<ServiceRequest>> requestsToday() async {
    final res = await _api.get('/api/fixer/requests/today');
    if (res.statusCode == 200) {
      final list = jsonDecode(res.body) as List;
      return list
          .map((e) => ServiceRequest.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<ServiceRequest?> transition(int id, String action) async {
    final res = await _api.patch('/api/fixer/requests/$id/$action', body: {});
    if (res.statusCode == 200) {
      return ServiceRequest.fromJson(
        jsonDecode(res.body) as Map<String, dynamic>,
      );
    }
    return null;
  }

  // Accept a service request for this fixer according to provided routes
  Future<bool> acceptRequest(int id) async {
    final res = await _api.post('/api/service-requests/$id/accept', body: {});
    final ok = res.statusCode == 200 || res.statusCode == 201;
    if (ok) {
      unawaited(profile());
      _emitRequests(action: 'accept', requestId: id, status: 'accepted');
    }
    return ok;
  }

  // Update a request status (e.g., completed, cancelled)
  Future<bool> updateStatus(int id, String status) async {
    final res = await _api.patch('/api/requests/$id', body: {'status': status});
    final ok = res.statusCode >= 200 && res.statusCode < 300;
    if (ok) {
      _emitRequests(action: 'status', requestId: id, status: status);
    }
    return ok;
  }

  Future<Map<String, dynamic>> declineRequest(int id) async {
    final res = await _api.post('/api/fixer/requests/$id/decline', body: {});
    final body = _decodeBody(res);
    final successFlag =
        res.statusCode >= 200 &&
        res.statusCode < 300 &&
        (body['success'] ?? true) == true;
    if (successFlag) {
      final points = _extractPriorityPoints(body);
      if (points != null) {
        broadcastPriorityPoints(points);
      } else {
        unawaited(profile());
      }
      _emitRequests(action: 'decline', requestId: id, status: 'declined');
    }
    return {
      'success': successFlag,
      'message': body['message']?.toString(),
      'data': body['data'],
    };
  }

  Future<bool> snoozeRequest(int id) async {
    final res = await _api.post('/api/fixer/requests/$id/snooze', body: {});
    final ok = res.statusCode >= 200 && res.statusCode < 300;
    if (ok) {
      _emitRequests(action: 'snooze', requestId: id);
    }
    return ok;
  }

  // Fetch a single request detail (may include contact info)
  Future<Map<String, dynamic>?> requestDetail(int id) async {
    final res = await _api.get('/api/requests/$id');
    if (res.statusCode == 200) {
      final root = jsonDecode(res.body);
      if (root is Map<String, dynamic>) {
        if (root['data'] is Map<String, dynamic>) {
          return Map<String, dynamic>.from(root['data'] as Map);
        }
        return Map<String, dynamic>.from(root);
      }
    }

    final declined = _declinedCache[id];
    if (declined != null) {
      final data = Map<String, dynamic>.from(declined);
      data['status'] = 'declined';
      return data;
    }

    return null;
  }

  final Map<int, Map<String, dynamic>> _declinedCache = {};

  /// Fetch wallet ledger entries with optional filters.
  Future<List<Map<String, dynamic>>> walletHistory({String? filter}) async {
    final res = await _api.get(
      '/api/fixer/wallet/history',
      query: {if (filter != null && filter.isNotEmpty) 'filter': filter},
    );
    if (res.statusCode != 200) return const [];
    final decoded = jsonDecode(res.body);
    List raw;
    if (decoded is Map<String, dynamic>) {
      final data = decoded['data'];
      if (data is List) {
        raw = data;
      } else {
        raw = [];
      }
    } else if (decoded is List) {
      raw = decoded;
    } else {
      raw = [];
    }
    return raw.whereType<Map<String, dynamic>>().toList();
  }

  Future<bool> createPayment(int id, double amount) async {
    // Only customers can create payments on backend
    return false;
  }

  Future<bool> createBill(int id, double amount) async {
    final res = await _api.post(
      '/api/fixer/requests/$id/bill',
      body: {'amount': amount},
    );
    final ok = res.statusCode >= 200 && res.statusCode < 300;
    if (ok) {
      _emitRequests(action: 'bill', requestId: id);
    }
    return ok;
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

  Future<Fixer?> updateMe({
    String? bio,
    String? availability,
    List<int>? serviceIds,
  }) async {
    final body = <String, dynamic>{
      if (bio != null) 'bio': bio,
      if (availability != null) 'availability': availability,
      if (serviceIds != null) 'service_ids': serviceIds,
    };
    final res = await _api.patch('/api/fixer/me', body: body);
    if (res.statusCode == 200) {
      final mapped = _extractFixer(_decodeBody(res));
      if (mapped != null) {
        final fixer = Fixer.fromJson(mapped);
        _emitProfile(action: 'profileUpdated');
        return fixer;
      }
    }
    return null;
  }

  Future<bool> uploadAvatar(String filePath) async {
    final req = await _api.multipart('/api/me/avatar', method: 'POST');
    req.files.add(await http.MultipartFile.fromPath('avatar', filePath));
    final streamed = await req.send();
    final ok = streamed.statusCode == 200;
    if (ok) {
      _emitProfile(action: 'avatarUpdated');
    }
    return ok;
  }

  Future<Fixer?> profile() async {
    final res = await _api.get('/api/fixer/me');
    if (res.statusCode != 200) return null;
    final mapped = _extractFixer(_decodeBody(res));
    if (mapped != null) {
      final fixer = Fixer.fromJson(mapped);
      broadcastPriorityPoints(fixer.priorityPoints);
      return fixer;
    }
    return null;
  }

  Future<void> _notifyAssignments(List<ServiceRequest> requests) async {
    try {
      if (requests.isEmpty) return;
      final prefs = await SharedPreferences.getInstance();
      final seen =
          prefs.getStringList('fixer_seen_request_ids')?.toSet() ?? <String>{};
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

  Map<String, dynamic> _decodeBody(http.Response res) {
    try {
      final data = jsonDecode(res.body);
      if (data is Map<String, dynamic>) return data;
    } catch (_) {}
    return {};
  }

  void _emitRequests({
    String action = 'update',
    int? requestId,
    String? status,
  }) {
    _sync.emit(
      AppSyncTopic.requests,
      payload: <String, dynamic>{
        'action': action,
        if (requestId != null) 'requestId': requestId,
        if (status != null) 'status': status,
      },
    );
    _sync.emit(
      AppSyncTopic.dashboard,
      payload: const <String, dynamic>{'source': 'requests'},
    );
  }

  void _emitProfile({String action = 'profile'}) {
    _sync.emit(
      AppSyncTopic.profile,
      payload: <String, dynamic>{'action': action},
    );
    _sync.emit(
      AppSyncTopic.dashboard,
      payload: const <String, dynamic>{'source': 'profile'},
    );
  }

  Map<String, dynamic>? _extractFixer(Map<String, dynamic> body) {
    Map<String, dynamic>? candidate;

    void hydrate(Map<String, dynamic> target, Map<String, dynamic> source) {
      if (!target.containsKey('services') && source['services'] is List) {
        final list = List<dynamic>.from(source['services'] as List);
        if (list.every((element) => element is Map)) {
          target['services'] = list
              .map((item) => Map<String, dynamic>.from(item as Map))
              .toList();
        } else {
          target['services'] = list;
        }
      }
      if (!target.containsKey('user') && source['user'] is Map) {
        target['user'] = Map<String, dynamic>.from(source['user'] as Map);
      }
    }

    bool looksLikeFixer(Map<String, dynamic> map) {
      return map.containsKey('services') ||
          map.containsKey('bio') ||
          map.containsKey('user');
    }

    Map<String, dynamic>? tryMap(dynamic value) {
      if (value is Map) {
        return Map<String, dynamic>.from(value);
      }
      return null;
    }

    final data = tryMap(body['data']);
    if (data != null) {
      if (looksLikeFixer(data)) {
        candidate = data;
      } else {
        final nested =
            tryMap(data['fixer']) ??
            tryMap(data['fixer_profile']) ??
            tryMap(data['fixerProfile']);
        if (nested != null) {
          hydrate(nested, data);
          candidate = nested;
        }
      }
    }

    final resolved =
        candidate ??
        tryMap(body['fixer']) ??
        tryMap(body['fixer_profile']) ??
        tryMap(body['fixerProfile']);
    if (resolved != null) {
      hydrate(resolved, body);
      candidate = resolved;
    }

    if (candidate == null &&
        body.containsKey('id') &&
        body.containsKey('user')) {
      candidate = Map<String, dynamic>.from(body);
    }

    if (candidate == null) return null;

    final services = candidate['services'];
    if (services is List) {
      candidate['services'] = services
          .map((item) {
            if (item is Map) {
              final map = Map<String, dynamic>.from(item);
              map['id'] = _parseId(map['id'] ?? map['service_id']);
              if (map['name'] == null && map['id'] != null) {
                map['name'] = 'Service #${map['id']}';
              }
              return map;
            }
            final id = _parseId(item);
            if (id == null) return null;
            return {'id': id, 'name': 'Service #$id', 'price': null};
          })
          .whereType<Map<String, dynamic>>()
          .toList();
    }

    if (!candidate.containsKey('user') && body['user'] is Map) {
      candidate['user'] = Map<String, dynamic>.from(body['user']);
    }

    return candidate;
  }

  int? _parseId(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}

int? _extractPriorityPoints(dynamic data) {
  int? parseInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  if (data is Map) {
    final map = Map<String, dynamic>.from(data as Map);
    for (final key in const ['priority_points', 'priorityPoints']) {
      final val = parseInt(map[key]);
      if (val != null) return val;
    }
    for (final key in const ['data', 'fixer', 'profile', 'user']) {
      if (map[key] != null) {
        final nested = _extractPriorityPoints(map[key]);
        if (nested != null) return nested;
      }
    }
  }
  return null;
}
