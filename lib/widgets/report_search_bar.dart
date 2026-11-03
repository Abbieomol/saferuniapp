import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/incident_enums.dart';
import '../providers/incident_provider.dart';
import 'filter_sheet.dart';

/// Search box, filter button and quick status chips above the feed.
class ReportSearchBar extends StatefulWidget {
  const ReportSearchBar({super.key});

  @override
  State<ReportSearchBar> createState() => _ReportSearchBarState();
}

class _ReportSearchBarState extends State<ReportSearchBar> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: context.read<IncidentProvider>().query,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<IncidentProvider>();
    // Keep the box in sync if the query is cleared elsewhere (e.g. Reset).
    // Cleared after this frame: changing a controller mid-build isn't allowed.
    if (p.query.isEmpty && _controller.text.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _controller.clear();
      });
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                onChanged: p.setQuery,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search reports',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _controller.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _controller.clear();
                            p.setQuery('');
                          },
                        ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Badge(
              isLabelVisible: p.activeFilterCount > 0,
              label: Text('${p.activeFilterCount}'),
              child: IconButton.filledTonal(
                tooltip: 'Filters',
                iconSize: 24,
                padding: const EdgeInsets.all(14),
                icon: const Icon(Icons.tune),
                onPressed: () => FilterSheet.show(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _QuickChip(
                label: 'All',
                selected: p.status == null && !p.mineOnly,
                onTap: () {
                  p.setStatus(null);
                  p.setMineOnly(false);
                },
              ),
              _QuickChip(
                label: 'My reports',
                selected: p.mineOnly,
                onTap: () => p.setMineOnly(!p.mineOnly),
              ),
              for (final s in IncidentStatus.values)
                _QuickChip(
                  label: s.label,
                  selected: p.status == s,
                  color: s.color,
                  onTap: () => p.setStatus(p.status == s ? null : s),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        avatar: color == null
            ? null
            : CircleAvatar(backgroundColor: color, radius: 4),
        onSelected: (_) => onTap(),
      ),
    );
  }
}
