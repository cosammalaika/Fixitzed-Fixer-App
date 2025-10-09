class ServiceCatalogItem {
  ServiceCatalogItem({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.subcategoryId,
    this.price,
    this.subcategoryName,
  });

  final int id;
  final String name;
  final int categoryId;
  final int subcategoryId;
  final double? price;
  final String? subcategoryName;
}

class ServiceCatalogSection {
  ServiceCatalogSection({
    required this.id,
    required this.name,
    required this.items,
  });

  final int id;
  final String name;
  final List<ServiceCatalogItem> items;
}
