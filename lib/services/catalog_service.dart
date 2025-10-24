import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:fixitzed_fixer_app/models/service_catalog.dart';
import 'package:fixitzed_fixer_app/services/api_client.dart';

class CatalogService {
  CatalogService({ApiClient? client}) : _api = client ?? ApiClient.I;

  final ApiClient _api;

  Future<List<ServiceCatalogSection>> fetchCatalog() async {
    final responses = await Future.wait<http.Response>([
      _api.get('/api/categories'),
      _api.get('/api/subcategories'),
      _api.get('/api/services'),
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

    final grouped = <int, List<ServiceCatalogItem>>{};
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
      grouped.putIfAbsent(categoryId, () => <ServiceCatalogItem>[]).add(item);
    }

    final sections = <ServiceCatalogSection>[];
    grouped.forEach((categoryId, items) {
      final name = categoryNames[categoryId] ?? 'Category $categoryId';
      items.sort((a, b) => a.name.compareTo(b.name));
      sections.add(
        ServiceCatalogSection(id: categoryId, name: name, items: items),
      );
    });

    sections.sort((a, b) => a.name.compareTo(b.name));

    final normalized = <ServiceCatalogSection>[];
    for (final section in sections) {
      final bySubcategory = <int?, List<ServiceCatalogItem>>{};
      for (final item in section.items) {
        final key = item.subcategoryId == 0 ? null : item.subcategoryId;
        bySubcategory.putIfAbsent(key, () => <ServiceCatalogItem>[]).add(item);
      }

      if (bySubcategory.length > 1) {
        final entries = bySubcategory.entries.toList()
          ..sort((a, b) {
            final aName =
                a.value.first.subcategoryName?.trim().toLowerCase() ?? '';
            final bName =
                b.value.first.subcategoryName?.trim().toLowerCase() ?? '';
            return aName.compareTo(bName);
          });
        var fallbackIndex = 0;
        for (final entry in entries) {
          fallbackIndex += 1;
          final items = List<ServiceCatalogItem>.from(entry.value)
            ..sort((a, b) => a.name.compareTo(b.name));
          final rawName = items.first.subcategoryName?.trim();
          final name = (rawName != null && rawName.isNotEmpty)
              ? rawName
              : '${section.name} $fallbackIndex';
          final subcategoryId =
              entry.key ?? -(section.id * 1000 + fallbackIndex);
          normalized.add(
            ServiceCatalogSection(id: subcategoryId, name: name, items: items),
          );
        }
      } else {
        normalized.add(section);
      }
    }

    normalized.sort((a, b) => a.name.compareTo(b.name));
    return normalized;
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
