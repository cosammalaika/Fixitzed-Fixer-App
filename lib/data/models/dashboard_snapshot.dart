import 'package:meta/meta.dart';

import '../../models/service_request.dart';

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
}
