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
import 'package:fixitzed_fixer_app/services/session_guard.dart';
import 'package:fixitzed_fixer_app/state/app_sync.dart';

class FixerService {
  FixerService({AppSync? sync}) : _sync = sync ?? AppSync.instance;

  final AppSync _sync;
  final _api = ApiClient.I;
  static final ValueNotifier<int?> priorityPointsNotifier = ValueNotifier<int?>(
    null,
  );
  static final Map<String, List<ServiceRequest>> _requestsCache =
      <String, List<ServiceRequest>>{};
  static final Map<String, DateTime> _requestsFetchedAt = <String, DateTime>{};
  static final Map<String, Future<List<ServiceRequest>>> _requestsInFlight =
      <String, Future<List<ServiceRequest>>>{};
  static List<ServiceRequest> _unassignedCache = const <ServiceRequest>[];
  static DateTime? _unassignedFetchedAt;
  static Future<List<ServiceRequest>>? _unassignedInFlight;
  static Map<String, dynamic> _walletCache = const <String, dynamic>{};
  static DateTime? _walletFetchedAt;
  static Future<Map<String, dynamic>>? _walletInFlight;
  static final Map<int, Map<String, dynamic>> _declinedCache =
      <int, Map<String, dynamic>>{};
  static const Duration _requestsTtl = Duration(seconds: 20);
  static const Duration _unassignedTtl = Duration(seconds: 20);
  static const Duration _walletTtl = Duration(minutes: 1);

  static void broadcastPriorityPoints(int? value) {
    if (priorityPointsNotifier.value != value) {
      priorityPointsNotifier.value = value;
    }
  }

  static void clearCache() {
    _requestsCache.clear();
    _requestsFetchedAt.clear();
    _requestsInFlight.clear();
    _unassignedCache = const <ServiceRequest>[];
    _unassignedFetchedAt = null;
    _unassignedInFlight = null;
    _walletCache = const <String, dynamic>{};
    _walletFetchedAt = null;
    _walletInFlight = null;
    _declinedCache.clear();
    broadcastPriorityPoints(null);
  }

  Future<Map<String, dynamic>?> dashboard() async {
    final res = await _api.get('/api/fixer/dashboard');
    if (res.statusCode == 200)
      return jsonDecode(res.body) as Map<String, dynamic>;
    return null;
  }

  Future<List<ServiceRequest>> requests({
    String? status,
    bool forceRefresh = false,
  }) async {
    final key = status?.trim().toLowerCase() ?? 'all';
    final now = DateTime.now();
    final cached = _requestsCache[key];
    final fetchedAt = _requestsFetchedAt[key];
    if (!forceRefresh &&
        cached != null &&
        fetchedAt != null &&
        now.difference(fetchedAt) < _requestsTtl) {
      _log('requests_cache_hit', <String, Object?>{
        'filter': key,
        'count': cached.length,
      });
      return List<ServiceRequest>.from(cached);
    }
    if (!forceRefresh) {
      final existing = _requestsInFlight[key];
      if (existing != null) {
        return existing;
      }
    }

    final future = _loadRequests(key: key, status: status);
    _requestsInFlight[key] = future;
    try {
      return await future;
    } finally {
      if (identical(_requestsInFlight[key], future)) {
        _requestsInFlight.remove(key);
      }
    }
  }

  Future<List<ServiceRequest>> _loadRequests({
    required String key,
    required String? status,
  }) async {
    try {
      final res = await _api.get(
        '/api/fixer/requests',
        query: {if (status != null) 'status': status},
      );
      if (res.statusCode == 200) {
        final requests = _parseRequestsList(jsonDecode(res.body));
        _requestsCache[key] = List<ServiceRequest>.from(requests);
        _requestsFetchedAt[key] = DateTime.now();
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
      _log('requests_failure', <String, Object?>{
        'status': res.statusCode,
        'filter': key,
      });
    } catch (error) {
      _log('requests_exception', <String, Object?>{
        'filter': key,
        'error': error.toString(),
      });
    }

    final cached = _requestsCache[key];
    if (cached != null) {
      _log('requests_cache_fallback', <String, Object?>{
        'filter': key,
        'count': cached.length,
      });
      return List<ServiceRequest>.from(cached);
    }
    return const <ServiceRequest>[];
  }

  /// Try to fetch unassigned/eligible requests for this fixer.
  /// If the backend doesn't expose this route, returns an empty list.
  Future<List<ServiceRequest>> unassigned({bool forceRefresh = false}) async {
    final now = DateTime.now();
    if (!forceRefresh &&
        _unassignedFetchedAt != null &&
        now.difference(_unassignedFetchedAt!) < _unassignedTtl) {
      _log('unassigned_cache_hit', <String, Object?>{
        'count': _unassignedCache.length,
      });
      return List<ServiceRequest>.from(_unassignedCache);
    }
    if (!forceRefresh && _unassignedInFlight != null) {
      return _unassignedInFlight!;
    }

    final future = _loadUnassigned();
    _unassignedInFlight = future;
    try {
      return await future;
    } finally {
      if (identical(_unassignedInFlight, future)) {
        _unassignedInFlight = null;
      }
    }
  }

  Future<List<ServiceRequest>> _loadUnassigned() async {
    try {
      final res = await _api.get('/api/fixer/requests/unassigned');
      if (res.statusCode == 200) {
        final requests = _parseRequestsList(jsonDecode(res.body));
        _unassignedCache = List<ServiceRequest>.from(requests);
        _unassignedFetchedAt = DateTime.now();
        unawaited(_notifyAssignments(requests));
        return requests;
      }
      _log('unassigned_failure', <String, Object?>{'status': res.statusCode});
    } catch (error) {
      _log('unassigned_exception', <String, Object?>{
        'error': error.toString(),
      });
    }

    if (_unassignedCache.isNotEmpty) {
      return List<ServiceRequest>.from(_unassignedCache);
    }
    return const <ServiceRequest>[];
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
      _invalidateRequestCaches();
      return ServiceRequest.fromJson(
        jsonDecode(res.body) as Map<String, dynamic>,
      );
    }
    return null;
  }

  // Accept a service request for this fixer according to provided routes
  Future<bool> acceptRequest(int id) async {
    final result = await acceptRequestDetailed(id);
    return result['success'] == true;
  }

  Future<Map<String, dynamic>> acceptRequestDetailed(int id) async {
    final res = await _api.post('/api/service-requests/$id/accept', body: {});
    final body = _decodeBody(res);
    if (kDebugMode) {
      debugPrint('acceptRequest id=$id status=${res.statusCode} body=$body');
    }
    final ok = res.statusCode == 200 || res.statusCode == 201;
    if (ok) {
      _invalidateRequestCaches(invalidateWallet: true);
      unawaited(profile());
      _emitRequests(action: 'accept', requestId: id, status: 'accepted');
    }
    return {
      'success': ok,
      'statusCode': res.statusCode,
      'message': body['message']?.toString(),
      'data': body['data'],
    };
  }

  // Update a request status (e.g., completed, cancelled)
  Future<bool> updateStatus(int id, String status) async {
    final res = await _api.patch('/api/requests/$id', body: {'status': status});
    final ok = res.statusCode >= 200 && res.statusCode < 300;
    if (ok) {
      _invalidateRequestCaches();
      _emitRequests(action: 'status', requestId: id, status: status);
    }
    return ok;
  }

  Future<Map<String, dynamic>> declineRequest(int id) async {
    final res = await _api.post('/api/fixer/requests/$id/decline', body: {});
    final body = _decodeBody(res);
    if (kDebugMode) {
      debugPrint('declineRequest id=$id status=${res.statusCode} body=$body');
    }
    final successFlag =
        res.statusCode >= 200 &&
        res.statusCode < 300 &&
        (body['success'] ?? true) == true;
    if (successFlag) {
      _invalidateRequestCaches();
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
      'statusCode': res.statusCode,
      'message': body['message']?.toString(),
      'data': body['data'],
    };
  }

  Future<bool> snoozeRequest(int id) async {
    final res = await _api.post('/api/fixer/requests/$id/snooze', body: {});
    final ok = res.statusCode >= 200 && res.statusCode < 300;
    if (ok) {
      _invalidateRequestCaches();
      _emitRequests(action: 'snooze', requestId: id);
    }
    return ok;
  }

  // Fetch a single request detail (may include contact info)
  Future<Map<String, dynamic>?> requestDetail(int id) async {
    final targets = [
      '/api/fixer/requests/$id',
      '/api/fixer/service-requests/$id',
      '/api/service-requests/$id',
      '/api/requests/$id',
      '/api/bookings/$id',
      '/api/fixer/bookings/$id',
    ];

    for (final path in targets) {
      try {
        final res = await _api.get(path);
        if (kDebugMode) {
          debugPrint(
            '[FixerService.requestDetail] GET $path status=${res.statusCode} bytes=${res.body.length}',
          );
        }
        if (res.statusCode == 200) {
          final root = jsonDecode(res.body);
          final unwrapped = _unwrapRequest(root);
          if (unwrapped != null) return unwrapped;
        }
      } catch (_) {
        // try next
      }
    }

    // Fallback: search collection endpoints
    for (final path in [
      '/api/fixer/requests',
      '/api/service-requests',
      '/api/requests',
      '/api/bookings',
    ]) {
      try {
        final res = await _api.get(path);
        if (kDebugMode) {
          debugPrint(
            '[FixerService.requestDetail] fallback GET $path status=${res.statusCode} bytes=${res.body.length}',
          );
        }
        if (res.statusCode != 200) continue;
        final root = jsonDecode(res.body);
        final list = _unwrapRequestList(root);
        if (list == null) continue;
        final match = list.firstWhere(
          (row) => _matchesId(row, id),
          orElse: () => const <String, dynamic>{},
        );
        if (match.isNotEmpty) {
          return Map<String, dynamic>.from(match);
        }
      } catch (_) {
        // continue to next fallback
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

  Map<String, dynamic>? _unwrapRequest(dynamic root) {
    if (root is Map<String, dynamic>) {
      for (final key in [
        'data',
        'request',
        'service_request',
        'serviceRequest',
        'booking',
      ]) {
        final inner = root[key];
        if (inner is Map) return Map<String, dynamic>.from(inner);
      }
      return Map<String, dynamic>.from(root);
    }
    return null;
  }

  List<Map<String, dynamic>>? _unwrapRequestList(dynamic root) {
    List? raw;
    if (root is List) raw = root;
    if (root is Map<String, dynamic>) {
      if (root['data'] is List) raw = root['data'] as List;
      if (root['data'] is Map && (root['data'] as Map)['data'] is List) {
        raw = (root['data'] as Map)['data'] as List;
      }
      if (raw == null && root['requests'] is List) {
        raw = root['requests'] as List;
      }
      raw ??=
          root.values.firstWhere((v) => v is List, orElse: () => const [])
              as List;
    }
    if (raw == null) return null;
    return raw
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
  }

  List<ServiceRequest> _parseRequestsList(dynamic root) {
    final list = _unwrapRequestList(root);
    if (list == null || list.isEmpty) {
      return const <ServiceRequest>[];
    }

    final requests = <ServiceRequest>[];
    for (final item in list) {
      try {
        requests.add(ServiceRequest.fromJson(item));
      } catch (error) {
        _log('request_parse_skipped', <String, Object?>{
          'error': error.toString(),
          'id': item['id']?.toString(),
        });
      }
    }
    return requests;
  }

  bool _matchesId(Map<String, dynamic> data, int id) {
    final raw = data['id'] ?? data['request_id'] ?? data['requestId'];
    if (raw is int && raw == id) return true;
    if (raw is num && raw.toInt() == id) return true;
    if (raw is String) {
      final parsed = int.tryParse(raw);
      if (parsed != null && parsed == id) return true;
    }
    return false;
  }

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
      _invalidateRequestCaches();
      _emitRequests(action: 'bill', requestId: id);
    }
    return ok;
  }

  // Wallet: balance and coins remaining
  Future<Map<String, dynamic>> wallet({bool forceRefresh = false}) async {
    final now = DateTime.now();
    if (!forceRefresh &&
        _walletCache.isNotEmpty &&
        _walletFetchedAt != null &&
        now.difference(_walletFetchedAt!) < _walletTtl) {
      _log('wallet_cache_hit', <String, Object?>{
        'keys': _walletCache.keys.length,
      });
      return Map<String, dynamic>.from(_walletCache);
    }
    if (!forceRefresh && _walletInFlight != null) {
      return _walletInFlight!;
    }

    final future = _loadWallet();
    _walletInFlight = future;
    try {
      return await future;
    } finally {
      if (identical(_walletInFlight, future)) {
        _walletInFlight = null;
      }
    }
  }

  Future<Map<String, dynamic>> _loadWallet() async {
    try {
      final res = await _api.get('/api/fixer/wallet');
      if (res.statusCode == 200) {
        final root = jsonDecode(res.body) as Map<String, dynamic>;
        final data = (root['data'] ?? root) as Map<String, dynamic>;
        _walletCache = Map<String, dynamic>.from(data);
        _walletFetchedAt = DateTime.now();
        return Map<String, dynamic>.from(_walletCache);
      }
      _log('wallet_failure', <String, Object?>{'status': res.statusCode});
    } catch (error) {
      _log('wallet_exception', <String, Object?>{'error': error.toString()});
    }

    return Map<String, dynamic>.from(_walletCache);
  }

  Future<Fixer?> updateMe({
    String? bio,
    String? availability,
    String? location,
    List<int>? serviceIds,
  }) async {
    final body = <String, dynamic>{
      if (bio != null) 'bio': bio,
      if (availability != null) 'availability': availability,
      if (location != null) 'location': location,
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
    await SessionGuard.evaluate(streamed);
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

  void _invalidateRequestCaches({bool invalidateWallet = false}) {
    _requestsFetchedAt.clear();
    _unassignedFetchedAt = null;
    if (invalidateWallet) {
      _walletFetchedAt = null;
    }
  }

  void _log(String event, [Map<String, Object?> details = const {}]) {
    if (!kDebugMode) {
      return;
    }
    final suffix = details.entries
        .map((entry) => '${entry.key}=${entry.value}')
        .join(' ');
    debugPrint(
      suffix.isEmpty
          ? '[FixerService] $event'
          : '[FixerService] $event $suffix',
    );
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
