import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../models/incident.dart';
import '../../models/incident_enums.dart';
import '../../providers/auth_provider.dart';
import '../../providers/incident_provider.dart';
import '../../widgets/incident_card.dart';
import '../../widgets/state_views.dart';
import '../report/incident_detail_screen.dart';

/// Staff overview: workload by status and category, and a prioritised
/// queue of open reports.
///
/// Also checks the role itself, so even if this screen were reached by
/// mistake a student would only see "Staff only".
class StaffDashboardScreen extends StatelessWidget {
  const StaffDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isStaff = context.select<AuthProvider, bool>((a) => a.isStaff);
    if (!isStaff) {
      return Scaffold(
        appBar: AppBar(title: const Text('Staff dashboard')),
        body: const EmptyView(
          icon: Icons.lock_outline,
          title: 'Staff only',
          message: 'This area is for authorised campus staff.',
        ),
      );
    }

    final p = context.watch<IncidentProvider>();
    final queue = p.needsAttention;
    final text = Theme.of(context).textTheme;

    Widget heading(String title, [String? subtitle]) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (subtitle != null)
            Text(
              subtitle,
              style: text.bodySmall?.copyWith(color: Colors.grey.shade600),
            ),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Staff dashboard',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: p.loading
          ? const Center(child: CircularProgressIndicator())
          : p.loadError != null
          ? ErrorView(message: p.loadError!, onRetry: p.retry)
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                        child: _StatusGrid(provider: p),
                      ),
                      if (p.reopenedCount > 0 ||
                          p.awaitingConfirmationCount > 0)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                          child: _Alerts(provider: p),
                        ),
                      heading('Open reports by category'),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _CategoryBars(provider: p),
                      ),
                      heading(
                        'Needs attention',
                        'Reopened first, then high priority, most affected and oldest',
                      ),
                    ],
                  ),
                ),
                if (queue.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyView(
                      icon: Icons.task_alt,
                      title: 'All caught up',
                      message: 'There are no open reports right now.',
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                    sliver: SliverList.builder(
                      itemCount: queue.length,
                      itemBuilder: (context, i) => _QueueItem(
                        incident: queue[i],
                        reopened: p.isReopened(queue[i]),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _StatusGrid extends StatelessWidget {
  const _StatusGrid({required this.provider});

  final IncidentProvider provider;

  @override
  Widget build(BuildContext context) {
    final tiles = IncidentStatus.values
        .map(
          (s) => _CountTile(
            label: s.label,
            count: provider.countByStatus(s),
            color: s.color,
          ),
        )
        .toList();
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.35,
      children: [
        _CountTile(
          label: 'Open',
          count: provider.openCount,
          color: AppTheme.primary,
        ),
        ...tiles,
      ],
    );
  }
}

class _CountTile extends StatelessWidget {
  const _CountTile({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$count',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }
}

class _Alerts extends StatelessWidget {
  const _Alerts({required this.provider});

  final IncidentProvider provider;

  @override
  Widget build(BuildContext context) {
    final lines = <String>[
      if (provider.reopenedCount > 0)
        '${provider.reopenedCount} reopened by the reporter as still broken',
      if (provider.awaitingConfirmationCount > 0)
        '${provider.awaitingConfirmationCount} resolved, waiting for the reporter to confirm',
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.notifications_active_outlined,
            color: AppTheme.accent,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [for (final l in lines) Text(l)],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryBars extends StatelessWidget {
  const _CategoryBars({required this.provider});

  final IncidentProvider provider;

  @override
  Widget build(BuildContext context) {
    final counts = {
      for (final c in IncidentCategory.values) c: provider.countByCategory(c),
    };
    final max = counts.values.fold(0, (a, b) => a > b ? a : b);
    if (max == 0) {
      return Text(
        'No open reports.',
        style: TextStyle(color: Colors.grey.shade600),
      );
    }
    final sorted = counts.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      children: [
        for (final e in sorted)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Icon(e.key.icon, size: 18, color: Colors.grey.shade700),
                const SizedBox(width: 8),
                SizedBox(
                  width: 120,
                  child: Text(
                    e.key.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: e.value / max,
                      minHeight: 10,
                      backgroundColor: Colors.grey.shade200,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 24,
                  child: Text(
                    '${e.value}',
                    textAlign: TextAlign.end,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _QueueItem extends StatelessWidget {
  const _QueueItem({required this.incident, required this.reopened});

  final Incident incident;
  final bool reopened;

  @override
  Widget build(BuildContext context) {
    final card = IncidentCard(
      incident: incident,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => IncidentDetailScreen(incidentId: incident.id),
        ),
      ),
    );
    if (!reopened) return card;
    return Stack(
      children: [
        card,
        Positioned(
          top: 6,
          right: 6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppTheme.accent,
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              'Reopened',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
