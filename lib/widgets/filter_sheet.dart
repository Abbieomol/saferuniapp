import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_config.dart';
import '../models/incident_enums.dart';
import '../providers/incident_provider.dart';

/// Bottom sheet with every filter. Changes apply instantly through
/// IncidentProvider, so the list behind the sheet updates as you tap.
class FilterSheet extends StatelessWidget {
  const FilterSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const FilterSheet(),
  );

  @override
  Widget build(BuildContext context) {
    final p = context.watch<IncidentProvider>();
    final text = Theme.of(context).textTheme;

    Widget section(String title) => Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      child: Text(
        title,
        style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
    );

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Filter reports',
                    style: text.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed:
                        p.activeFilterCount == 0 && p.sort == SortOrder.newest
                        ? null
                        : p.clearFilters,
                    child: const Text('Reset'),
                  ),
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Only my reports'),
                value: p.mineOnly,
                onChanged: p.setMineOnly,
              ),
              section('Sort by'),
              SegmentedButton<SortOrder>(
                segments: SortOrder.values
                    .map((s) => ButtonSegment(value: s, label: Text(s.label)))
                    .toList(),
                selected: {p.sort},
                onSelectionChanged: (s) => p.setSort(s.first),
              ),
              section('Status'),
              _ChipGroup<IncidentStatus>(
                values: IncidentStatus.values,
                selected: p.status,
                label: (s) => s.label,
                onSelected: p.setStatus,
              ),
              section('Category'),
              _ChipGroup<IncidentCategory>(
                values: IncidentCategory.values,
                selected: p.category,
                label: (c) => c.label,
                icon: (c) => c.icon,
                onSelected: p.setCategory,
              ),
              section('Location'),
              _ChipGroup<String>(
                values: AppConfig.buildings,
                selected: p.building,
                label: (b) => b,
                onSelected: p.setBuilding,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Show ${p.visible.length} '
                    '${p.visible.length == 1 ? 'report' : 'reports'}',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Single-choice chips; tapping the selected chip clears it.
class _ChipGroup<T> extends StatelessWidget {
  const _ChipGroup({
    required this.values,
    required this.selected,
    required this.label,
    required this.onSelected,
    this.icon,
  });

  final List<T> values;
  final T? selected;
  final String Function(T) label;
  final IconData Function(T)? icon;
  final ValueChanged<T?> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: values.map((v) {
        final isSelected = v == selected;
        return ChoiceChip(
          avatar: icon == null ? null : Icon(icon!(v), size: 18),
          label: Text(label(v)),
          selected: isSelected,
          showCheckmark: false,
          onSelected: (_) => onSelected(isSelected ? null : v),
        );
      }).toList(),
    );
  }
}
