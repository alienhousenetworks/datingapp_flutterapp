// ─── Theme Models ─────────────────────────────────────────────

class ThemeConfig {
  final String? layoutId;
  final String? bgId;
  final String? bgVariantId;
  final String? colorToken;
  final String? assignedAt;

  ThemeConfig({
    this.layoutId,
    this.bgId,
    this.bgVariantId,
    this.colorToken,
    this.assignedAt,
  });

  factory ThemeConfig.fromJson(Map<String, dynamic> json) => ThemeConfig(
        layoutId: json['layout_id'],
        bgId: json['bg_id'],
        bgVariantId: json['bg_variant_id'],
        colorToken: json['color_token'],
        assignedAt: json['assigned_at'],
      );

  Map<String, dynamic> toJson() => {
        if (layoutId != null) 'layout_id': layoutId,
        if (bgId != null) 'bg_id': bgId,
        if (bgVariantId != null) 'bg_variant_id': bgVariantId,
      };

  ThemeConfig copyWith({
    String? layoutId,
    String? bgId,
    String? bgVariantId,
    String? colorToken,
  }) =>
      ThemeConfig(
        layoutId: layoutId ?? this.layoutId,
        bgId: bgId ?? this.bgId,
        bgVariantId: bgVariantId ?? this.bgVariantId,
        colorToken: colorToken ?? this.colorToken,
        assignedAt: assignedAt,
      );
}

class LayoutOption {
  final String layoutId;
  final String name;
  final String description;

  LayoutOption({
    required this.layoutId,
    required this.name,
    required this.description,
  });

  factory LayoutOption.fromJson(Map<String, dynamic> json) => LayoutOption(
        layoutId: json['layout_id'] ?? '',
        name: json['name'] ?? '',
        description: json['description'] ?? '',
      );
}

class BackgroundVariantOption {
  final String bgVariantId;
  final String name;
  final String? colorToken;

  BackgroundVariantOption({
    required this.bgVariantId,
    required this.name,
    this.colorToken,
  });

  factory BackgroundVariantOption.fromJson(Map<String, dynamic> json) =>
      BackgroundVariantOption(
        bgVariantId: json['bg_variant_id'] ?? '',
        name: json['name'] ?? '',
        colorToken: json['color_token'],
      );
}

class BackgroundOption {
  final String bgId;
  final String name;
  final String description;
  final List<BackgroundVariantOption> variants;

  BackgroundOption({
    required this.bgId,
    required this.name,
    required this.description,
    required this.variants,
  });

  factory BackgroundOption.fromJson(Map<String, dynamic> json) =>
      BackgroundOption(
        bgId: json['bg_id'] ?? '',
        name: json['name'] ?? '',
        description: json['description'] ?? '',
        variants: (json['variants'] as List<dynamic>? ?? [])
            .map((v) => BackgroundVariantOption.fromJson(v))
            .toList(),
      );
}

class ThemeOptionsResponse {
  final List<LayoutOption> layouts;
  final List<BackgroundOption> backgrounds;

  ThemeOptionsResponse({required this.layouts, required this.backgrounds});

  factory ThemeOptionsResponse.fromJson(Map<String, dynamic> json) =>
      ThemeOptionsResponse(
        layouts: (json['layouts'] as List<dynamic>? ?? [])
            .map((l) => LayoutOption.fromJson(l))
            .toList(),
        backgrounds: (json['backgrounds'] as List<dynamic>? ?? [])
            .map((b) => BackgroundOption.fromJson(b))
            .toList(),
      );
}
