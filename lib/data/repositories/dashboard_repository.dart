import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/service_request.dart';
import '../../services/api_client.dart';
import '../../services/fixer_service.dart';
import '../../services/notifications_service.dart';
import '../../config.dart';
import '../models/dashboard_snapshot.dart';

class FixerDashboardRepository {
  FixerDashboardRepository(this._api, this._notifications, this._fixerService);

  final ApiClient _api;
  final NotificationsService _notifications;
  final FixerService _fixerService;

  Future<FixerDashboardSnapshot> fetchDashboard() async {
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

    return FixerDashboardSnapshot(
      unreadNotifications: unread,
      activeRequests: requests,
      coins: coins,
      totalEarnings: totalEarnings,
      completedCount: completedCount,
      displayName: user.displayName,
      avatarUrl: user.avatarUrl,
      location: user.location,
      fetchedAt: DateTime.now(),
    );
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

class _FixerUser {
  const _FixerUser(this.displayName, this.avatarUrl, this.location);
  final String displayName;
  final String? avatarUrl;
  final String location;
}
