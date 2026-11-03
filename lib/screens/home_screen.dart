import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_config.dart';
import '../core/app_theme.dart';
import '../models/incident_enums.dart';
import '../providers/auth_provider.dart';
import '../providers/incident_provider.dart';
import '../widgets/incident_card.dart';
import '../widgets/report_search_bar.dart';
import '../widgets/state_views.dart';
import 'report/incident_detail_screen.dart';
import 'report/new_report_screen.dart';

/// Home: greeting, quick counts, search/filters and the live list of
/// campus reports. Tapping a report opens its details.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user!;
    final incidents = context.watch<IncidentProvider>();
    final firstName = user.fullName.trim().isEmpty
        ? user.email.split('@').first
        : user.fullName.trim().split(' ').first;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          AppConfig.appName,
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          if (user.isStaff)
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Chip(
                label: Text('Staff'),
                visualDensity: VisualDensity.compact,
                avatar: Icon(Icons.badge_outlined, size: 16),
              ),
            ),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () => _confirmSignOut(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const NewReportScreen())),
        icon: const Icon(Icons.add),
        label: const Text('Report issue'),
      ),
      body: _body(context, incidents, firstName),
    );
  }

  Widget _body(
    BuildContext context,
    IncidentProvider incidents,
    String firstName,
  ) {
    if (incidents.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (incidents.loadError != null) {
      return ErrorView(message: incidents.loadError!, onRetry: incidents.retry);
    }

    final list = incidents.visible;
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hi $firstName',
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  'Spotted a problem on campus? Report it in under a minute.',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _StatTile(
                      label: 'Open',
                      value: incidents.openCount,
                      color: AppTheme.primary,
                    ),
                    const SizedBox(width: 10),
                    _StatTile(
                      label: 'In progress',
                      value: incidents.countByStatus(IncidentStatus.inProgress),
                      color: IncidentStatus.inProgress.color,
                    ),
                    const SizedBox(width: 10),
                    _StatTile(
                      label: 'Resolved',
                      value: incidents.countByStatus(IncidentStatus.resolved),
                      color: IncidentStatus.resolved.color,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const ReportSearchBar(),
              ],
            ),
          ),
        ),
        if (list.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: incidents.hasSearchOrFilters
                ? EmptyView(
                    icon: Icons.filter_alt_off_outlined,
                    title: 'No matching reports',
                    message: 'Try a different search or clear the filters.',
                    action: OutlinedButton(
                      onPressed: incidents.clearFilters,
                      child: const Text('Clear search and filters'),
                    ),
                  )
                : const EmptyView(
                    icon: Icons.inbox_outlined,
                    title: 'No reports yet',
                    message: 'Be the first to report an issue on campus.',
                  ),
          )
        else
          SliverPadding(
            // Bottom padding keeps the last card clear of the button.
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
            sliver: SliverList.builder(
              itemCount: list.length,
              itemBuilder: (context, i) => IncidentCard(
                incident: list[i],
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        IncidentDetailScreen(incidentId: list[i].id),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (yes == true && context.mounted) {
      await context.read<AuthProvider>().signOut();
    }
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$value',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }
}
