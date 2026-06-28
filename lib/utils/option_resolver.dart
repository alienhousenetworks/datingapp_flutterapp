import '../models/profile_model.dart';

/// Resolves option UUIDs from the API into human-readable labels.
class OptionResolver {
  static final _uuidPattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  static bool isUuid(String value) => _uuidPattern.hasMatch(value.trim());

  static String resolveId(String value, List<NamedOption> options) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return trimmed;
    if (!isUuid(trimmed)) return trimmed;
    for (final option in options) {
      if (option.id == trimmed) return option.name;
    }
    return trimmed;
  }

  static List<String> resolveList(
    List<String> values,
    List<NamedOption> options,
  ) {
    return values
        .map((value) => resolveId(value, options))
        .where((value) => value.isNotEmpty)
        .toList();
  }

  static Set<String> resolveIdSet(
    List<String> values,
    List<NamedOption> options,
  ) {
    final ids = <String>{};
    for (final value in values) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) continue;
      if (isUuid(trimmed)) {
        ids.add(trimmed);
        continue;
      }
      for (final option in options) {
        if (option.name.toLowerCase() == trimmed.toLowerCase()) {
          ids.add(option.id);
          break;
        }
      }
    }
    return ids;
  }
}