class Category {
  final String id;
  final String name;
  final String description;
  final String icon;
  final bool active;

  Category({
    required this.id,
    required this.name,
    this.description = '',
    this.icon = '☕',
    this.active = true,
  });
}
