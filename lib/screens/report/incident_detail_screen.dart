import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../models/incident.dart';
import '../../models/incident_enums.dart';
import '../../providers/auth_provider.dart';
import '../../providers/incident_provider.dart';
import '../../widgets/state_views.dart';
import '../../widgets/status_chip.dart';
import '../../widgets/status_timeline.dart';
import '../../widgets/update_status_sheet.dart';
import 'new_report_screen.dart';
import 'photo_viewer_screen.dart';

/// Full details of one report.
///
/// It looks the report up by id in IncidentProvider instead of being
/// handed a copy, so when staff change the status (or someone taps
/// "Me too") this screen updates live.
class IncidentDetailScreen extends StatelessWidget {
  const IncidentDetailScreen({super.key, required this.incidentId});

  final String incidentId;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<IncidentProvider>();
    final uid = context.select<AuthProvider, String?>((a) => a.user?.uid);
    final isStaff = context.select<AuthProvider, bool>((a) => a.isStaff);
    final incident = provider.byId(incidentId);

    if (incident == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyView(
          icon: Icons.search_off,
          title: 'Report not found',
          message: 'It may have been deleted.',
        ),
      );
    }

    final isMine = incident.isReportedBy(uid);
    final busy = provider.isBusy(incident.id);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Report details'),
        actions: [
          if (isMine && incident.isEditable)
            IconButton(
              tooltip: 'Edit report',
              icon: const Icon(Icons.edit_outlined),
              onPressed: busy
                  ? null
                  : () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => NewReportScreen(existing: incident),
                      ),
                    ),
            ),
          // Reporter while still "Submitted"; staff at any time
          // (e.g. spam or abusive reports). Same rule in Firestore.
          if ((isMine && incident.isEditable) || isStaff)
            IconButton(
              tooltip: 'Delete report',
              icon: const Icon(Icons.delete_outline),
              onPressed: busy ? null : () => _delete(context, incident),
            ),
        ],
      ),
      // Staff-only action bar. Students never see it, and the Firestore
      // rules reject status changes from non-staff accounts anyway.
      bottomNavigationBar: isStaff
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: FilledButton.icon(
                  onPressed: busy
                      ? null
                      : () => UpdateStatusSheet.show(context, incident),
                  icon: const Icon(Icons.sync_alt),
                  label: const Text('Update status'),
                ),
              ),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          if (incident.photoUrl != null) _Photo(incident: incident),
          Row(
            children: [
              StatusChip(status: incident.status),
              const SizedBox(width: 8),
              _PriorityPill(priority: incident.priority),
              const Spacer(),
              if (isMine)
                Text(
                  'Your report',
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            incident.title,
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          _InfoRow(
            icon: incident.category.icon,
            text: incident.category.label,
            color: incident.category.color,
          ),
          _InfoRow(
            icon: Icons.place_outlined,
            text: incident.locationDetail.isEmpty
                ? incident.building
                : '${incident.building} · ${incident.locationDetail}',
          ),
          _InfoRow(
            icon: Icons.person_outline,
            text: isMine && incident.isAnonymous
                ? 'You (posted anonymously)'
                : incident.displayReporter,
          ),
          _InfoRow(
            icon: Icons.schedule,
            text: DateFormat('d MMM yyyy, HH:mm').format(incident.createdAt),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                incident.description,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _AffectedCard(incident: incident, uid: uid, busy: busy),
          if (isMine && incident.awaitingConfirmation) ...[
            const SizedBox(height: 12),
            _ConfirmFixCard(incident: incident, busy: busy),
          ],
          if (incident.status == IncidentStatus.resolved &&
              incident.reporterConfirmed == true) ...[
            const SizedBox(height: 12),
            const _ConfirmedBanner(),
          ],
          const SizedBox(height: 24),
          Text(
            'Progress',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          StatusTimeline(history: incident.history),
        ],
      ),
    );
  }

  Future<void> _delete(BuildContext context, Incident incident) async {
    final provider = context.read<IncidentProvider>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this report?'),
        content: const Text(
          'It will be removed for everyone, along with its photo. '
          'This can\'t be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (yes != true) return;

    final error = await provider.deleteReport(incident);
    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    navigator.pop();
    messenger.showSnackBar(const SnackBar(content: Text('Report deleted.')));
  }
}

// Pieces of the screen

class _Photo extends StatelessWidget {
  const _Photo({required this.incident});

  final Incident incident;

  @override
  Widget build(BuildContext context) {
    final tag = 'photo-${incident.id}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                PhotoViewerScreen(url: incident.photoUrl!, heroTag: tag),
          ),
        ),
        child: Hero(
          tag: tag,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(
              incident.photoUrl!,
              height: 220,
              width: double.infinity,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) => progress == null
                  ? child
                  : Container(
                      height: 220,
                      color: Colors.grey.shade200,
                      alignment: Alignment.center,
                      child: const CircularProgressIndicator(),
                    ),
              errorBuilder: (_, _, _) => Container(
                height: 120,
                color: Colors.grey.shade200,
                alignment: Alignment.center,
                child: const Text('Photo couldn\'t load'),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text, this.color});

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color ?? Colors.grey.shade600),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(color: Colors.grey.shade800)),
          ),
        ],
      ),
    );
  }
}

class _PriorityPill extends StatelessWidget {
  const _PriorityPill({required this.priority});

  final IncidentPriority priority;

  @override
  Widget build(BuildContext context) {
    final color = switch (priority) {
      IncidentPriority.high => AppTheme.accent,
      IncidentPriority.medium => Colors.blueGrey,
      IncidentPriority.low => Colors.grey,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '${priority.label} priority',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Signature feature 1: "This affects me too".
class _AffectedCard extends StatelessWidget {
  const _AffectedCard({
    required this.incident,
    required this.uid,
    required this.busy,
  });

  final Incident incident;
  final String? uid;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final count = incident.affectedCount;
    final isMine = incident.isReportedBy(uid);
    final affected = incident.isAffecting(uid);
    final canTap = !isMine && incident.status.isOpen;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
              child: const Icon(Icons.groups_outlined, color: AppTheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    count == 1
                        ? '1 student affected'
                        : '$count students affected',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    isMine
                        ? 'Others can tap "Me too" instead of re-reporting.'
                        : 'Same problem? Add yourself instead of reporting again.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
            if (canTap) ...[
              const SizedBox(width: 8),
              affected
                  ? OutlinedButton.icon(
                      onPressed: busy ? null : () => _toggle(context),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Added'),
                    )
                  : FilledButton.tonalIcon(
                      onPressed: busy ? null : () => _toggle(context),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Me too'),
                    ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _toggle(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final error = await context.read<IncidentProvider>().toggleAffected(
      incident,
    );
    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
    }
  }
}

/// Signature feature 2: the reporter confirms the fix or reopens it.
class _ConfirmFixCard extends StatelessWidget {
  const _ConfirmFixCard({required this.incident, required this.busy});

  final Incident incident;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final green = IncidentStatus.resolved.color;
    return Card(
      color: green.withValues(alpha: 0.06),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Staff marked this as resolved',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Is it actually fixed? Your answer helps staff close the loop.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: busy ? null : () => _stillBroken(context),
                    child: const Text('Still broken'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: green),
                    onPressed: busy ? null : () => _respond(context, true, ''),
                    child: const Text('Confirmed fixed'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _stillBroken(BuildContext context) async {
    final note = await showDialog<String>(
      context: context,
      builder: (_) => const _ReopenDialog(),
    );
    if (note == null || !context.mounted) return;
    await _respond(context, false, note);
  }

  Future<void> _respond(BuildContext context, bool fixed, String note) async {
    final messenger = ScaffoldMessenger.of(context);
    final error = await context.read<IncidentProvider>().respondToResolution(
      incident,
      fixed: fixed,
      note: note,
    );
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          error ??
              (fixed
                  ? 'Thanks for confirming!'
                  : 'Report reopened. Staff have been notified in its timeline.'),
        ),
      ),
    );
  }
}

class _ReopenDialog extends StatefulWidget {
  const _ReopenDialog();

  @override
  State<_ReopenDialog> createState() => _ReopenDialogState();
}

class _ReopenDialogState extends State<_ReopenDialog> {
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Still not fixed?'),
      content: TextField(
        controller: _note,
        maxLength: 200,
        minLines: 2,
        maxLines: 4,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          hintText: 'What\'s still wrong? (optional)',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _note.text),
          child: const Text('Reopen report'),
        ),
      ],
    );
  }
}

class _ConfirmedBanner extends StatelessWidget {
  const _ConfirmedBanner();

  @override
  Widget build(BuildContext context) {
    final green = IncidentStatus.resolved.color;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: green.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.verified_outlined, color: green),
          const SizedBox(width: 10),
          const Expanded(
            child: Text('The reporter confirmed this issue is fixed.'),
          ),
        ],
      ),
    );
  }
}
