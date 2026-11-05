import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/incident.dart';
import '../models/incident_enums.dart';
import '../providers/incident_provider.dart';
import 'auth_scaffold.dart';

/// Staff-only sheet to move a report to a new status with a note.
/// The note becomes a timeline entry the reporter can read, so it is
/// required when rejecting or resolving (the reporter deserves a reason).
class UpdateStatusSheet extends StatefulWidget {
  const UpdateStatusSheet({super.key, required this.incident});

  final Incident incident;

  static Future<void> show(BuildContext context, Incident incident) =>
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => UpdateStatusSheet(incident: incident),
      );

  @override
  State<UpdateStatusSheet> createState() => _UpdateStatusSheetState();
}

class _UpdateStatusSheetState extends State<UpdateStatusSheet> {
  final _formKey = GlobalKey<FormState>();
  final _note = TextEditingController();
  IncidentStatus? _status;
  bool _saving = false;
  String? _error;

  bool get _noteRequired =>
      _status == IncidentStatus.rejected || _status == IncidentStatus.resolved;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_status == null) {
      setState(() => _error = 'Choose a new status');
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<IncidentProvider>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    setState(() {
      _saving = true;
      _error = null;
    });
    final error = await provider.updateStatus(
      widget.incident,
      _status!,
      _note.text,
    );
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _saving = false;
        _error = error;
      });
      return;
    }
    navigator.pop();
    messenger.showSnackBar(
      SnackBar(content: Text('Status changed to ${_status!.label}.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.incident.status;
    final text = Theme.of(context).textTheme;

    return Padding(
      // Lift the sheet above the keyboard.
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Update status',
                  style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  'Currently: ${current.label}',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                const SizedBox(height: 16),
                if (_error != null) ErrorBanner(message: _error!),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: IncidentStatus.values
                      .where((s) => s != current)
                      .map(
                        (s) => ChoiceChip(
                          label: Text(s.label),
                          selected: _status == s,
                          showCheckmark: false,
                          avatar: CircleAvatar(
                            backgroundColor: s.color,
                            radius: 5,
                          ),
                          onSelected: _saving
                              ? null
                              : (_) => setState(() {
                                  _status = s;
                                  _error = null;
                                }),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _note,
                  enabled: !_saving,
                  minLines: 2,
                  maxLines: 4,
                  maxLength: 300,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: _noteRequired
                        ? 'Note for the reporter (required)'
                        : 'Note for the reporter (optional)',
                    hintText: switch (_status) {
                      IncidentStatus.inReview =>
                        'e.g. Facilities team will inspect today',
                      IncidentStatus.inProgress =>
                        'e.g. Plumber booked for Thursday morning',
                      IncidentStatus.resolved => 'What was fixed?',
                      IncidentStatus.rejected => 'Why is this being rejected?',
                      _ => 'Visible to everyone in the timeline',
                    },
                    alignLabelWithHint: true,
                  ),
                  validator: (v) => _noteRequired && (v ?? '').trim().isEmpty
                      ? 'Please explain this to the reporter'
                      : null,
                ),
                const SizedBox(height: 12),
                LoadingButton(
                  label: 'Save status',
                  busy: _saving,
                  onPressed: _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
