import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:fixitzed_fixer_app/models/service_catalog.dart';
import 'package:fixitzed_fixer_app/services/api_client.dart';

class CatalogService {
  CatalogService({ApiClient? client}) : _api = client ?? ApiClient.I;

  final ApiClient _api;
  List<ServiceCatalogSection>? _cache;
  DateTime? _fetchedAt;
  static const Duration _ttl = Duration(minutes: 10);

  Future<List<ServiceCatalogSection>> fetchCatalog({bool forceRefresh = false}) async {
    final now = DateTime.now();
    if (!forceRefresh &&
        _cache != null &&
        _fetchedAt != null &&
        now.difference(_fetchedAt!) < _ttl) {
      return List<ServiceCatalogSection>.from(_cache!);
    }

    final responses = await Future.wait<http.Response>([
      _api.get('/api/categories', query: {'per_page': '200'}),
      _api.get('/api/subcategories', query: {'per_page': '500'}),
      _api.get('/api/services', query: {'per_page': '1000'}),
    ]);

    final categories = _toMapMap(responses[0]);
    final subcategories = _toMapMap(responses[1]);
    final services = _toList(responses[2]);

    final categoryNames = <int, String>{};
    for (final entry in categories) {
      final id = _parseInt(entry['id']);
      if (id == null) continue;
      final name = entry['name']?.toString() ?? 'Category $id';
      categoryNames[id] = name;
    }

    final subcategoryIndex = <int, Map<String, dynamic>>{};
    for (final entry in subcategories) {
      final id = _parseInt(entry['id']);
      final catId = _parseInt(entry['category_id']);
      if (id == null || catId == null) continue;
      subcategoryIndex[id] = {
        'category_id': catId,
        'name': entry['name']?.toString(),
      };
    }

    final groupedBySubcategory = <int, List<ServiceCatalogItem>>{};
    final groupedByCategory = <int, List<ServiceCatalogItem>>{};
    for (final raw in services) {
      final id = _parseInt(raw['id']);
      final subId = _parseInt(raw['subcategory_id']);
      if (id == null || subId == null) continue;
      final sub = subcategoryIndex[subId];
      final categoryId =
          _parseInt(raw['category_id']) ?? sub?['category_id'] as int?;
      if (categoryId == null) continue;
      final name = raw['name']?.toString() ?? 'Service $id';
      double? price;
      final priceRaw = raw['price'];
      if (priceRaw is num) {
        price = priceRaw.toDouble();
      } else if (priceRaw is String) {
        price = double.tryParse(priceRaw);
      }
      final item = ServiceCatalogItem(
        id: id,
        name: name,
        categoryId: categoryId,
        subcategoryId: subId,
        price: price,
        subcategoryName: sub?['name']?.toString(),
      );
      groupedBySubcategory.putIfAbsent(subId, () => <ServiceCatalogItem>[]).add(item);
      groupedByCategory.putIfAbsent(categoryId, () => <ServiceCatalogItem>[]).add(item);
    }

    final sections = <ServiceCatalogSection>[];
    // Prefer grouping by subcategory to ensure all catalogs surface even if
    // categories API is sparse; fall back to category grouping when no
    // subcategory is available.
    if (groupedBySubcategory.isNotEmpty) {
      groupedBySubcategory.forEach((subId, items) {
        items.sort((a, b) => a.name.compareTo(b.name));
        final sub = subcategoryIndex[subId];
        final subName = sub?['name']?.toString();
        final catName =
            categoryNames[_parseInt(sub?['category_id']) ?? -1] ?? 'Services';
        final name =
            (subName != null && subName.isNotEmpty) ? subName : catName;
        sections.add(
          ServiceCatalogSection(id: subId, name: name, items: items),
        );
      });
    } else {
      groupedByCategory.forEach((categoryId, items) {
        final name = categoryNames[categoryId] ?? 'Category $categoryId';
        items.sort((a, b) => a.name.compareTo(b.name));
        sections.add(
          ServiceCatalogSection(id: categoryId, name: name, items: items),
        );
      });
    }

    sections.sort((a, b) => a.name.compareTo(b.name));

    _cache = sections;
    _fetchedAt = now;
    return List<ServiceCatalogSection>.from(sections);
  }

  List<Map<String, dynamic>> _toMapMap(http.Response response) {
    final decoded = _decode(response);
    if (decoded is Map<String, dynamic>) {
      if (decoded['data'] is List) {
        return (decoded['data'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    }
    if (decoded is List) {
      return decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return const [];
  }

  List<Map<String, dynamic>> _toList(http.Response response) {
    final decoded = _decode(response);
    if (decoded is Map<String, dynamic>) {
      if (decoded['data'] is List) {
        return (decoded['data'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    }
    if (decoded is List) {
      return decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return const [];
  }

  dynamic _decode(http.Response response) {
    try {
      return jsonDecode(response.body);
    } catch (_) {
      return null;
    }
  }

  int? _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

}
