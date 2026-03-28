class CategoryDto {
  final int id;
  final String name;
  final String icon;
  final String slug;

  CategoryDto({
    required this.id,
    required this.name,
    required this.icon,
    required this.slug,
  });

  factory CategoryDto.fromJson(Map<String, dynamic> json) {
    return CategoryDto(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      icon: json['icon'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'slug': slug,
    };
  }
}
