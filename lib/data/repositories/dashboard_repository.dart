import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fixitzed_fixer_app/services/api_client.dart';
import 'package:fixitzed_fixer_app/services/fixer_service.dart';
import 'package:fixitzed_fixer_app/services/notifications_service.dart';
import 'package:fixitzed_fixer_app/config.dart';
import 'package:fixitzed_fixer_app/data/models/dashboard_snapshot.dart';
import 'package:fixitzed_fixer_app/models/service_request.dart';

class FixerDashboardRepository {
  FixerDashboardRepository(this._api, this._notifications, this._fixerService);

  final ApiClient _api;
  final NotificationsService _notifications;
  final FixerService _fixerService;
  FixerDashboardSnapshot? _cache;
  DateTime? _fetchedAt;
  String? _etag;
  bool _hydrated = false;

  static const Duration _ttl = Duration(seconds: 45);
  static const _cachePayloadKey = 'fixer_dashboard.cache.payload';
  static const _cacheFetchedAtKey = 'fixer_dashboard.cache.fetched_at';
  static const _cacheEtagKey = 'fixer_dashboard.cache.etag';

  Future<FixerDashboardSnapshot?> readCachedDashboard() async {
    await _hydrateCache();
    if (_cache == null) return null;
    return _cache!.copyWith(fromCache: true);
  }

  Future<FixerDashboardSnapshot> fetchDashboard({
    bool forceRefresh = false,
  }) async {
    await _hydrateCache();
    if (!forceRefresh &&
        _cache != null &&
        _fetchedAt != null &&
        DateTime.now().difference(_fetchedAt!) < _ttl) {
      return _cache!.copyWith(fromCache: true);
    }

    try {
      return await _fetchFromDashboardEndpoint();
    } on _DashboardEndpointUnavailable {
      return _fetchLegacyDashboard();
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[FixerDashboard] fetch failed, falling back to cache: $e');
        debugPrint(st.toString());
      }
      if (_cache != null) {
        return _cache!.copyWith(fromCache: true);
      }
      rethrow;
    }
  }

  Future<FixerDashboardSnapshot> _fetchFromDashboardEndpoint() async {
    final res = await _api.get(
      '/api/fixer/dashboard',
      query: const {'limit': '5'},
      headers: {
        if ((_etag ?? '').isNotEmpty) 'If-None-Match': _etag!,
      },
    );

    if (kDebugMode) {
      debugPrint(
        '[FixerDashboard] GET /api/fixer/dashboard?limit=5 status=${res.statusCode} bodyBytes=${res.body.length}',
      );
    }

    if (res.statusCode == 304 && _cache != null) {
      final refreshed = _cache!.copyWith(
        fetchedAt: DateTime.now(),
        fromCache: true,
      );
      _storeMemory(refreshed, etag: _etag);
      await _persistCache();
      return refreshed;
    }

    if (res.statusCode == 404 || res.statusCode == 405) {
      throw const _DashboardEndpointUnavailable();
    }

    if (res.statusCode != 200) {
      throw Exception('Dashboard endpoint failed (${res.statusCode})');
    }

    final root = jsonDecode(res.body);
    if (root is! Map<String, dynamic>) {
      throw const FormatException('Invalid dashboard payload');
    }

    final data = root['data'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Missing dashboard data');
    }

    if (kDebugMode) {
      debugPrint(
        '[FixerDashboard] rootKeys=${root.keys.toList()} dataKeys=${data.keys.toList()}',
      );
    }

    final stats = data['stats'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(data['stats'] as Map)
        : <String, dynamic>{};
    final user = data['user'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(data['user'] as Map)
        : <String, dynamic>{};

    final recentRaw =
        (data['recent_requests'] as List?) ??
        (data['requests'] as List?) ??
        (data['active_requests'] as List?) ??
        const [];

    final requests = <ServiceRequest>[];
    for (final row in recentRaw.whereType<Map>()) {
      try {
        requests.add(ServiceRequest.fromJson(Map<String, dynamic>.from(row)));
      } catch (e, st) {
        if (kDebugMode) {
          final mapped = Map<String, dynamic>.from(row);
          debugPrint(
            '[FixerDashboard] recent_requests parse error: $e rowKeys=${mapped.keys.toList()}',
          );
          debugPrint(st.toString());
        }
      }
    }

    final unread = _asInt(
      stats['unread_notifications'] ?? root['unread_count'] ?? 0,
    );
    final coins = _asInt(stats['coin_balance'] ?? stats['coins'] ?? 0);
    final totalEarnings = _asDouble(
      stats['total_earnings'] ?? stats['earnings_total'] ?? 0,
    );
    final completedCount = _asInt(stats['completed_count'] ?? 0);

    final snapshot = FixerDashboardSnapshot(
      unreadNotifications: unread,
      activeRequests: requests,
      coins: coins,
      totalEarnings: totalEarnings,
      completedCount: completedCount,
      displayName: _parseDisplayName(user),
      avatarUrl: _parseAvatarUrl(user),
      location: _parseLocation(user),
      fetchedAt: DateTime.now(),
      serverUpdatedAt: _parseDateTime(data['updated_at']),
      version: data['version']?.toString(),
      fromCache: false,
    );

    _storeMemory(snapshot, etag: res.headers['etag']);
    await _persistCache();
    return snapshot;
  }

  Future<FixerDashboardSnapshot> _fetchLegacyDashboard() async {
    final notificationsFuture = _notifications.list();
    final requestsFuture = _fixerService.requests();
    final walletFuture = _fixerService.wallet();
    final meFuture = _api.get('/api/me');

    final notifications = await notificationsFuture;
    final requests = await requestsFuture;
    final wallet = await walletFuture;
    final meResponse = await meFuture;

    final unread = notifications.where((item) => !item.read).length;
    final coins = ((wallet['coin_balance'] ?? wallet['coins'] ?? 0) as num)
        .toInt();
    double totalEarnings = 0;
    final earningsRaw =
        wallet['total_earnings'] ?? wallet['earnings_total'] ?? wallet['total'];
    if (earningsRaw is num) {
      totalEarnings = earningsRaw.toDouble();
    } else if (earningsRaw is String) {
      totalEarnings = double.tryParse(earningsRaw) ?? 0;
    }

    final completedCount = requests
        .where((request) => request.status == 'completed')
        .length;

    final user = _parseUser(meResponse);

    final snapshot = FixerDashboardSnapshot(
      unreadNotifications: unread,
      activeRequests: requests,
      coins: coins,
      totalEarnings: totalEarnings,
      completedCount: completedCount,
      displayName: user.displayName,
      avatarUrl: user.avatarUrl,
      location: user.location,
      fetchedAt: DateTime.now(),
      serverUpdatedAt: null,
      version: null,
      fromCache: false,
    );
    _storeMemory(snapshot);
    await _persistCache();
    return snapshot;
  }

  Future<void> _hydrateCache() async {
    if (_hydrated) return;
    _hydrated = true;

    final prefs = await SharedPreferences.getInstance();
    final payloadRaw = prefs.getString(_cachePayloadKey);
    final fetchedMs = prefs.getInt(_cacheFetchedAtKey);
    _etag = prefs.getString(_cacheEtagKey);

    if (payloadRaw == null || fetchedMs == null) return;

    try {
      final decoded = jsonDecode(payloadRaw);
      if (decoded is! Map<String, dynamic>) return;
      final snapshot = FixerDashboardSnapshot.fromCacheJson(decoded);
      if (snapshot == null) return;
      _cache = snapshot;
      _fetchedAt = DateTime.fromMillisecondsSinceEpoch(fetchedMs);
    } catch (_) {
      // Ignore corrupt cache and fetch from network.
    }
  }

  void _storeMemory(FixerDashboardSnapshot snapshot, {String? etag}) {
    _cache = snapshot.copyWith(fromCache: false);
    _fetchedAt = DateTime.now();
    if (etag != null && etag.isNotEmpty) {
      _etag = etag;
    }
  }

  Future<void> _persistCache() async {
    if (_cache == null || _fetchedAt == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cachePayloadKey, jsonEncode(_cache!.toCacheJson()));
    await prefs.setInt(_cacheFetchedAtKey, _fetchedAt!.millisecondsSinceEpoch);
    if ((_etag ?? '').isNotEmpty) {
      await prefs.setString(_cacheEtagKey, _etag!);
    } else {
      await prefs.remove(_cacheEtagKey);
    }
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  double _asDouble(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  DateTime? _parseDateTime(dynamic value) {
    if (value is DateTime) return value.toLocal();
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value)?.toLocal();
    }
    return null;
  }

  String _parseDisplayName(Map<String, dynamic> raw) {
    final first = (raw['first_name'] ?? raw['firstName'] ?? '')
        .toString()
        .trim();
    final last = (raw['last_name'] ?? raw['lastName'] ?? '').toString().trim();
    String display =
        (raw['name'] ?? raw['full_name'] ?? raw['username'])
            ?.toString()
            .trim() ??
        '';
    if (display.isEmpty) {
      display = [first, last].where((s) => s.isNotEmpty).join(' ');
    }
    return display;
  }

  String? _parseAvatarUrl(Map<String, dynamic> raw) {
    final avatarRaw =
        (raw['profile_photo_path'] ??
                raw['avatar_url'] ??
                raw['avatar'] ??
                raw['profile_photo_url'] ??
                raw['photo'] ??
                raw['image'])
            ?.toString();
    final avatar = avatarRaw == null ? null : resolveMediaUrl(avatarRaw);
    return avatar?.isEmpty == false ? avatar : null;
  }

  String _parseLocation(Map<String, dynamic> raw) {
    return [raw['address'], raw['location'], raw['city'], raw['country']]
        .whereType<String>()
        .map((value) => value.trim())
        .firstWhere((value) => value.isNotEmpty, orElse: () => '');
  }

  _FixerUser _parseUser(http.Response response) {
    if (response.statusCode != 200) {
      return const _FixerUser('', null, '');
    }
    final body = jsonDecode(response.body);
    Map<String, dynamic>? raw;
    if (body is Map<String, dynamic>) {
      if (body['user'] is Map<String, dynamic>) {
        raw = Map<String, dynamic>.from(body['user'] as Map);
      } else if (body['data'] is Map<String, dynamic>) {
        raw = Map<String, dynamic>.from(body['data'] as Map);
      } else {
        raw = Map<String, dynamic>.from(body);
      }
    }
    if (raw == null) return const _FixerUser('', null, '');

    final first = (raw['first_name'] ?? raw['firstName'] ?? '')
        .toString()
        .trim();
    final last = (raw['last_name'] ?? raw['lastName'] ?? '').toString().trim();
    String display =
        (raw['name'] ?? raw['full_name'] ?? raw['username'])
            ?.toString()
            .trim() ??
        '';
    if (display.isEmpty) {
      display = [first, last].where((s) => s.isNotEmpty).join(' ');
    }

    final avatarRaw =
        (raw['profile_photo_path'] ??
                raw['avatar_url'] ??
                raw['avatar'] ??
                raw['profile_photo_url'] ??
                raw['photo'] ??
                raw['image'])
            ?.toString();
    final avatar = avatarRaw == null ? null : resolveMediaUrl(avatarRaw);

    final location =
        [raw['address'], raw['location'], raw['city'], raw['country']]
            .whereType<String>()
            .map((value) => value.trim())
            .firstWhere((value) => value.isNotEmpty, orElse: () => '');

    return _FixerUser(
      display,
      avatar?.isEmpty == false ? avatar : null,
      location,
    );
  }
}

class _DashboardEndpointUnavailable implements Exception {
  const _DashboardEndpointUnavailable();
}

class _FixerUser {
  const _FixerUser(this.displayName, this.avatarUrl, this.location);
  final String displayName;
  final String? avatarUrl;
  final String location;
}
