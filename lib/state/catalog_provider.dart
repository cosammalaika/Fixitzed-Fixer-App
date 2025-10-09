import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/service_catalog.dart';
import '../services/catalog_service.dart';
import 'service_providers.dart';

final serviceCatalogProvider = FutureProvider<List<ServiceCatalogSection>>((
  ref,
) {
  final CatalogService service = ref.read(catalogServiceProvider);
  return service.fetchCatalog();
});
