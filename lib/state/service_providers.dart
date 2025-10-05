import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/api_client.dart';
import '../services/fixer_service.dart';
import '../services/notifications_service.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient.I);
final fixerServiceProvider = Provider<FixerService>((ref) => FixerService());
final notificationsServiceProvider = Provider<NotificationsService>(
  (ref) => NotificationsService(),
);
