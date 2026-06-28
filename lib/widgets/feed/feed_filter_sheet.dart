import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/feed_filters.dart';
import '../../models/profile_model.dart';
import '../../providers/feed_filter_provider.dart';
import '../../providers/feed_provider.dart';
import '../../providers/profile_provider.dart';

enum _FilterSection { age, location, intent, gender }

/// Bottom sheet for discover feed filters (age, location, intent, gender, online).
class FeedFilterSheet extends ConsumerStatefulWidget {
  const FeedFilterSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF141416),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const Padding(
        padding: EdgeInsets.only(bottom: 0),
        child: FeedFilterSheet(),
      ),
    );
  }

  @override
  ConsumerState<FeedFilterSheet> createState() => _FeedFilterSheetState();
}

class _FeedFilterSheetState extends ConsumerState<FeedFilterSheet> {
  FeedFilters? _draft;
  _FilterSection? _openSection;
  late final TextEditingController _cityCtrl;
  late final TextEditingController _stateCtrl;
  late final TextEditingController _countryCtrl;

  @override
  void initState() {
    super.initState();
    _cityCtrl = TextEditingController();
    _stateCtrl = TextEditingController();
    _countryCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _countryCtrl.dispose();
    super.dispose();
  }

  FeedFilters get draft => _draft ?? ref.read(feedFiltersProvider);

  void _syncRegionControllers(FeedFilters f) {
    _cityCtrl.text = f.city ?? '';
    _stateCtrl.text = f.state ?? '';
    _countryCtrl.text = f.country ?? '';
  }

  void _toggleGender(String id) {
    setState(() {
      final ids = List<String>.from(draft.genderIds);
      if (ids.contains(id)) {
        ids.remove(id);
      } else {
        ids.add(id);
      }
      _draft = draft.copyWith(genderIds: ids);
    });
  }

  Future<void> _apply() async {
    ref.read(feedFiltersProvider.notifier).update(draft);
    Navigator.pop(context);
    await ref.read(feedProvider.notifier).refreshFeed();
  }

  void _reset() {
    setState(() {
      _draft = FeedFilters.defaults;
      _openSection = null;
      _syncRegionControllers(FeedFilters.defaults);
    });
    ref.read(feedFiltersProvider.notifier).reset();
    ref.read(feedProvider.notifier).refreshFeed();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (_draft == null) {
      _draft = ref.read(feedFiltersProvider);
      _syncRegionControllers(_draft!);
    }
    final options = ref.watch(optionsProvider);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final f = draft;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        minChildSize: 0.45,
        maxChildSize: 0.92,
        builder: (_, scrollCtrl) => Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF444444),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(
                children: [
                  Text(
                    'Filters',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _reset,
                    child: Text(
                      'Reset',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF888888),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                children: [
                  _quickToggles(),
                  const SizedBox(height: 16),
                  _sectionTile(
                    title: 'Age',
                    subtitle: f.ageLabel(),
                    section: _FilterSection.age,
                    child: _agePanel(),
                  ),
                  _sectionTile(
                    title: 'Location',
                    subtitle: f.locationLabel(),
                    section: _FilterSection.location,
                    child: _locationPanel(),
                  ),
                  _sectionTile(
                    title: 'Intent',
                    subtitle: _intentLabel(options.intents, f),
                    section: _FilterSection.intent,
                    child: _intentPanel(options.intents),
                  ),
                  if (options.genders.isNotEmpty)
                    _sectionTile(
                      title: 'Gender',
                      subtitle: _genderLabel(options.genders, f),
                      section: _FilterSection.gender,
                      child: _genderPanel(options.genders),
                    ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _apply,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF2E74),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      'Apply filters',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickToggles() {
    return GestureDetector(
      onTap: () => setState(
        () => _draft = draft.copyWith(
          currentlyOnline: !draft.currentlyOnline,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: draft.currentlyOnline
              ? const Color(0xFFFF2E74).withValues(alpha: 0.15)
              : const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: draft.currentlyOnline
                ? const Color(0xFFFF2E74)
                : const Color(0xFF333333),
          ),
        ),
        child: Row(
          children: [
            Text(
              draft.currentlyOnline ? '🟢 Online now' : 'Online now',
              style: GoogleFonts.outfit(
                color: draft.currentlyOnline
                    ? const Color(0xFFFF2E74)
                    : const Color(0xFFCCCCCC),
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const Spacer(),
            Icon(
              draft.currentlyOnline
                  ? Icons.check_circle_rounded
                  : Icons.circle_outlined,
              color: draft.currentlyOnline
                  ? const Color(0xFFFF2E74)
                  : const Color(0xFF666666),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTile({
    required String title,
    required String subtitle,
    required _FilterSection section,
    required Widget child,
  }) {
    final open = _openSection == section;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: open ? const Color(0xFFFF2E74) : const Color(0xFF2A2A30),
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(
              () => _openSection = open ? null : section,
            ),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      subtitle,
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF888888),
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    open
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: const Color(0xFF888888),
                  ),
                ],
              ),
            ),
          ),
          if (open)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: child,
            ),
        ],
      ),
    );
  }

  Widget _agePanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Min age: ${draft.minAge}',
          style: GoogleFonts.outfit(color: const Color(0xFFAAAAAA), fontSize: 12),
        ),
        Slider(
          value: draft.minAge.toDouble(),
          min: 18,
          max: 80,
          divisions: 62,
          activeColor: const Color(0xFFFF2E74),
          onChanged: (v) {
            final min = v.round();
            setState(() {
              _draft = draft.copyWith(
                minAge: min,
                maxAge: min > draft.maxAge ? min : draft.maxAge,
              );
            });
          },
        ),
        Text(
          'Max age: ${draft.maxAge}',
          style: GoogleFonts.outfit(color: const Color(0xFFAAAAAA), fontSize: 12),
        ),
        Slider(
          value: draft.maxAge.toDouble(),
          min: 18,
          max: 100,
          divisions: 82,
          activeColor: const Color(0xFFFF2E74),
          onChanged: (v) {
            final max = v.round();
            setState(() {
              _draft = draft.copyWith(
                maxAge: max,
                minAge: max < draft.minAge ? max : draft.minAge,
              );
            });
          },
        ),
      ],
    );
  }

  Widget _locationPanel() {
    final profile = ref.watch(profileProvider).profile;
    final isDistance = draft.locationMode == FeedLocationMode.distance;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _chip(
                label: 'Near me',
                selected: isDistance,
                onTap: () => setState(
                  () => _draft = draft.copyWith(
                    locationMode: FeedLocationMode.distance,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _chip(
                label: 'By city/region',
                selected: !isDistance,
                onTap: () {
                  final next = draft.copyWith(
                    locationMode: FeedLocationMode.region,
                    city: draft.city ??
                        (profile?.city?.trim().isNotEmpty == true
                            ? profile!.city!.trim()
                            : null),
                    state: draft.state ??
                        (profile?.state?.trim().isNotEmpty == true
                            ? profile!.state!.trim()
                            : null),
                    country: draft.country ??
                        (profile?.country?.trim().isNotEmpty == true
                            ? profile!.country!.trim()
                            : null),
                  );
                  setState(() {
                    _draft = next;
                    _syncRegionControllers(next);
                  });
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (isDistance)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: kDistanceFilterOptions.map((km) {
              final selected = draft.distance == km;
              final label = km == 0 ? 'Anywhere' : '$km km';
              return _chip(
                label: label,
                selected: selected,
                onTap: () => setState(
                  () => _draft = draft.copyWith(distance: km),
                ),
              );
            }).toList(),
          )
        else ...[
          _regionField(
            label: 'City',
            controller: _cityCtrl,
            onChanged: (v) => setState(
              () => _draft = draft.copyWith(
                city: v.trim().isEmpty ? null : v.trim(),
                clearCity: v.trim().isEmpty,
              ),
            ),
          ),
          const SizedBox(height: 10),
          _regionField(
            label: 'State',
            controller: _stateCtrl,
            onChanged: (v) => setState(
              () => _draft = draft.copyWith(
                state: v.trim().isEmpty ? null : v.trim(),
                clearState: v.trim().isEmpty,
              ),
            ),
          ),
          const SizedBox(height: 10),
          _regionField(
            label: 'Country',
            controller: _countryCtrl,
            onChanged: (v) => setState(
              () => _draft = draft.copyWith(
                country: v.trim().isEmpty ? null : v.trim(),
                clearCountry: v.trim().isEmpty,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Set at least one field. More specific filters narrow results.',
            style: GoogleFonts.outfit(
              color: const Color(0xFF777777),
              fontSize: 11,
            ),
          ),
        ],
      ],
    );
  }

  Widget _regionField({
    required String label,
    required TextEditingController controller,
    required ValueChanged<String> onChanged,
  }) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: GoogleFonts.outfit(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.outfit(color: const Color(0xFF888888)),
        filled: true,
        fillColor: const Color(0xFF252528),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF3A3A40)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF3A3A40)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFFF2E74)),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }

  Widget _intentPanel(List<NamedOption> intents) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _chip(
          label: 'Any',
          selected: draft.intentId == null || draft.intentId!.isEmpty,
          onTap: () => setState(
            () => _draft = draft.copyWith(clearIntent: true),
          ),
        ),
        ...intents.map(
          (opt) => _chip(
            label: opt.name,
            selected: draft.intentId == opt.id,
            onTap: () => setState(
              () => _draft = draft.copyWith(intentId: opt.id),
            ),
          ),
        ),
      ],
    );
  }

  Widget _genderPanel(List<NamedOption> genders) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: genders.map((g) {
        final selected = draft.genderIds.contains(g.id);
        return _chip(
          label: g.name,
          selected: selected,
          onTap: () => _toggleGender(g.id),
        );
      }).toList(),
    );
  }

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFFF2E74).withValues(alpha: 0.2)
              : const Color(0xFF252528),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? const Color(0xFFFF2E74)
                : const Color(0xFF3A3A40),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            color: selected ? const Color(0xFFFF2E74) : const Color(0xFFBBBBBB),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  String _intentLabel(List<NamedOption> intents, FeedFilters f) {
    if (f.intentId == null || f.intentId!.isEmpty) return 'Any';
    for (final o in intents) {
      if (o.id == f.intentId) return o.name;
    }
    return 'Selected';
  }

  String _genderLabel(List<NamedOption> genders, FeedFilters f) {
    if (f.genderIds.isEmpty) return 'All';
    final names = genders
        .where((g) => f.genderIds.contains(g.id))
        .map((g) => g.name)
        .toList();
    if (names.isEmpty) return '${f.genderIds.length} selected';
    return names.join(', ');
  }
}