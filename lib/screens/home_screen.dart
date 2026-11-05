import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/app_config.dart';
import '../core/app_theme.dart';
import '../models/app_user.dart';
import '../models/incident_enums.dart';
import '../providers/auth_provider.dart';
import '../providers/incident_provider.dart';
import '../widgets/incident_card.dart';
import '../widgets/report_search_bar.dart';
import '../widgets/safer_uni_logo.dart';
import '../widgets/state_views.dart';
import 'report/incident_detail_screen.dart';
import 'report/new_report_screen.dart';

/// Home: branded header with greeting and live counts, then search,
/// filters and the live list of campus reports.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user!;
    final incidents = context.watch<IncidentProvider>();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const NewReportScreen())),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Report issue'),
        ),
        body: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _Hero(
                user: user,
                incidents: incidents,
                onSignOut: () => _confirmSignOut(context),
              ),
            ),
            if (incidents.offline)
              const SliverToBoxAdapter(child: OfflineBanner()),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 18, 16, 14),
                child: ReportSearchBar(),
              ),
            ),
            ..._listSlivers(context, incidents),
          ],
        ),
      ),
    );
  }

  List<Widget> _listSlivers(BuildContext context, IncidentProvider incidents) {
    if (incidents.loading) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (incidents.loadError != null) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: ErrorView(
            message: incidents.loadError!,
            onRetry: incidents.retry,
          ),
        ),
      ];
    }

    final list = incidents.visible;
    if (list.isEmpty) {
      return [
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
        ),
      ];
    }

    return [
      SliverPadding(
        // Bottom padding keeps the last card clear of the button.
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
        sliver: SliverList.builder(
          itemCount: list.length,
          itemBuilder: (context, i) => IncidentCard(
            incident: list[i],
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => IncidentDetailScreen(incidentId: list[i].id),
              ),
            ),
          ),
        ),
      ),
    ];
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You can sign back in with your ALU email.'),
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

/// Navy header: logo, name, role, greeting and three live counts.
class _Hero extends StatelessWidget {
  const _Hero({
    required this.user,
    required this.incidents,
    required this.onSignOut,
  });

  final AppUser user;
  final IncidentProvider incidents;
  final VoidCallback onSignOut;

  String get _firstName => user.fullName.trim().isEmpty
      ? user.email.split('@').first
      : user.fullName.trim().split(' ').first;

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final topInset = MediaQuery.paddingOf(context).top;

    return Container(
      decoration: const BoxDecoration(
        gradient: AppTheme.heroGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      padding: EdgeInsets.fromLTRB(20, topInset + 12, 12, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SaferUniLogo(size: 30, onDark: true),
              const SizedBox(width: 8),
              Text(
                AppConfig.appName,
                style: text.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              if (user.isStaff) const _StaffBadge(),
              IconButton(
                tooltip: 'Sign out',
                color: Colors.white,
                icon: const Icon(Icons.logout_rounded),
                onPressed: onSignOut,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            '$_greeting, $_firstName',
            style: text.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text(
              'Spotted a problem around ${AppConfig.campusName}? '
              'Report it in under a minute.',
              style: text.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.78),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              children: [
                _HeroStat(
                  label: 'Open',
                  value: incidents.openCount,
                  dot: Colors.white,
                ),
                const SizedBox(width: 10),
                _HeroStat(
                  label: 'In progress',
                  value: incidents.countByStatus(IncidentStatus.inProgress),
                  dot: IncidentStatus.inProgress.color,
                ),
                const SizedBox(width: 10),
                _HeroStat(
                  label: 'Resolved',
                  value: incidents.countByStatus(IncidentStatus.resolved),
                  dot: IncidentStatus.resolved.color,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({
    required this.label,
    required this.value,
    required this.dot,
  });

  final String label;
  final int value;
  final Color dot;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$value',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StaffBadge extends StatelessWidget {
  const _StaffBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.accent,
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.badge_outlined, size: 14, color: Colors.white),
          SizedBox(width: 4),
          Text(
            'Staff',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
