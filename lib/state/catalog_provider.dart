import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fixitzed_fixer_app/models/service_catalog.dart';
import 'package:fixitzed_fixer_app/services/catalog_service.dart';
import 'package:fixitzed_fixer_app/state/service_providers.dart';

final serviceCatalogProvider = FutureProvider<List<ServiceCatalogSection>>((
  ref,
) {
  final CatalogService service = ref.read(catalogServiceProvider);
  return service.fetchCatalog();
});
