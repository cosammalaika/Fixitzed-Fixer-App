import 'package:meta/meta.dart';

import 'package:fixitzed_fixer_app/models/service_request.dart';

@immutable
class FixerDashboardSnapshot {
  const FixerDashboardSnapshot({
    required this.unreadNotifications,
    required this.activeRequests,
    required this.coins,
    required this.totalEarnings,
    required this.completedCount,
    required this.displayName,
    required this.avatarUrl,
    required this.location,
    required this.fetchedAt,
    this.serverUpdatedAt,
    this.version,
    this.fromCache = false,
  });

  final int unreadNotifications;
  final List<ServiceRequest> activeRequests;
  final int coins;
  final double totalEarnings;
  final int completedCount;
  final String displayName;
  final String? avatarUrl;
  final String location;
  final DateTime fetchedAt;
  final DateTime? serverUpdatedAt;
  final String? version;
  final bool fromCache;

  FixerDashboardSnapshot copyWith({
    int? unreadNotifications,
    List<ServiceRequest>? activeRequests,
    int? coins,
    double? totalEarnings,
    int? completedCount,
    String? displayName,
    String? avatarUrl,
    String? location,
    DateTime? fetchedAt,
    DateTime? serverUpdatedAt,
    String? version,
    bool? fromCache,
  }) {
    return FixerDashboardSnapshot(
      unreadNotifications: unreadNotifications ?? this.unreadNotifications,
      activeRequests: activeRequests ?? this.activeRequests,
      coins: coins ?? this.coins,
      totalEarnings: totalEarnings ?? this.totalEarnings,
      completedCount: completedCount ?? this.completedCount,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      location: location ?? this.location,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      serverUpdatedAt: serverUpdatedAt ?? this.serverUpdatedAt,
      version: version ?? this.version,
      fromCache: fromCache ?? this.fromCache,
    );
  }

  Map<String, dynamic> toCacheJson() {
    return {
      'unread_notifications': unreadNotifications,
      'active_requests': activeRequests.map((request) => request.toJson()).toList(),
      'coins': coins,
      'total_earnings': totalEarnings,
      'completed_count': completedCount,
      'display_name': displayName,
      'avatar_url': avatarUrl,
      'location': location,
      'fetched_at': fetchedAt.toUtc().toIso8601String(),
      'server_updated_at': serverUpdatedAt?.toUtc().toIso8601String(),
      'version': version,
    };
  }

  static FixerDashboardSnapshot? fromCacheJson(Map<String, dynamic>? json) {
    if (json == null) return null;

    final rawRequests = (json['active_requests'] as List?) ?? const [];
    final requests = rawRequests
        .whereType<Map>()
        .map((row) => ServiceRequest.fromJson(Map<String, dynamic>.from(row)))
        .toList();

    int asInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    double asDouble(dynamic value) {
      if (value is double) return value;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0;
      return 0;
    }

    DateTime parseDate(dynamic value) {
      if (value is DateTime) return value;
      if (value is String) {
        return DateTime.tryParse(value)?.toLocal() ?? DateTime.now();
      }
      return DateTime.now();
    }

    DateTime? parseNullableDate(dynamic value) {
      if (value is DateTime) return value;
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value)?.toLocal();
      }
      return null;
    }

    return FixerDashboardSnapshot(
      unreadNotifications: asInt(json['unread_notifications']),
      activeRequests: requests,
      coins: asInt(json['coins']),
      totalEarnings: asDouble(json['total_earnings']),
      completedCount: asInt(json['completed_count']),
      displayName: (json['display_name'] ?? '').toString(),
      avatarUrl: (json['avatar_url'] as String?)?.trim().isEmpty == true
          ? null
          : json['avatar_url'] as String?,
      location: (json['location'] ?? '').toString(),
      fetchedAt: parseDate(json['fetched_at']),
      serverUpdatedAt: parseNullableDate(json['server_updated_at']),
      version: (json['version'] as String?)?.trim(),
      fromCache: true,
    );
  }
}
