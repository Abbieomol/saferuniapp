import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_config.dart';
import '../../core/validators.dart';
import '../../models/incident.dart';
import '../../models/incident_enums.dart';
import '../../providers/incident_provider.dart';
import '../../widgets/auth_scaffold.dart';
import '../../widgets/incident_card.dart';
import '../../widgets/photo_picker_field.dart';
import 'incident_detail_screen.dart';

/// Form for submitting a new incident report, or editing one the user
/// already sent (pass [existing]). Editing is allowed only while the report
/// is still "Submitted"; the photo and anonymity can't change after that.
///
/// What the user is typing (fields, chosen photo) is local to this screen,
/// so it uses setState. Submitting goes through IncidentProvider, which
/// owns the shared list of reports and the "sending" state.
class NewReportScreen extends StatefulWidget {
  const NewReportScreen({super.key, this.existing});

  final Incident? existing;

  @override
  State<NewReportScreen> createState() => _NewReportScreenState();
}

class _NewReportScreenState extends State<NewReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _locationDetail = TextEditingController();
  final _detailFieldKey = GlobalKey<FormFieldState<String>>();

  IncidentCategory? _category;
  String? _building;
  IncidentPriority _priority = IncidentPriority.medium;
  bool _anonymous = false;
  File? _photo;

  bool get _isOtherArea => _building == AppConfig.otherArea;
  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _title.text = e.title;
      _description.text = e.description;
      _locationDetail.text = e.locationDetail;
      _category = e.category;
      _building = AppConfig.buildings.contains(e.building) ? e.building : null;
      _priority = e.priority;
      _anonymous = e.isAnonymous;
    }
    // Clear any error left over from a previous attempt.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<IncidentProvider>().clearSubmitError(),
    );
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _locationDetail.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<IncidentProvider>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final ok = _isEditing
        ? await provider.updateReport(
            incidentId: widget.existing!.id,
            title: _title.text,
            description: _description.text,
            category: _category!,
            priority: _priority,
            building: _building!,
            locationDetail: _locationDetail.text,
          )
        : await provider.submitReport(
            title: _title.text,
            description: _description.text,
            category: _category!,
            priority: _priority,
            building: _building!,
            locationDetail: _locationDetail.text,
            isAnonymous: _anonymous,
            photo: _photo,
          );
    if (!ok) return; // error banner is shown from provider state

    navigator.pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          _isEditing
              ? 'Report updated.'
              : 'Report sent. You can track its status on the home screen.',
        ),
      ),
    );
  }

  bool get _hasChanges {
    final e = widget.existing;
    if (e == null) {
      return _title.text.isNotEmpty ||
          _description.text.isNotEmpty ||
          _locationDetail.text.isNotEmpty ||
          _category != null ||
          _building != null ||
          _photo != null;
    }
    return _title.text != e.title ||
        _description.text != e.description ||
        _locationDetail.text != e.locationDetail ||
        _category != e.category ||
        _building != e.building ||
        _priority != e.priority;
  }

  Future<bool> _confirmDiscard() async {
    if (!_hasChanges) return true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_isEditing ? 'Discard changes?' : 'Discard this report?'),
        content: const Text('What you\'ve entered will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return discard ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final incidents = context.watch<IncidentProvider>();
    final busy = incidents.submitting;
    final text = Theme.of(context).textTheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || busy) return;
        final navigator = Navigator.of(context);
        if (await _confirmDiscard()) navigator.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEditing ? 'Edit report' : 'Report an issue'),
        ),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                if (incidents.submitError != null)
                  ErrorBanner(message: incidents.submitError!),

                // ----- What -----
                const _SectionLabel('What happened?'),
                FormField<IncidentCategory>(
                  validator: (_) =>
                      _category == null ? 'Choose a category' : null,
                  builder: (field) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: IncidentCategory.values.map((c) {
                          final selected = c == _category;
                          return ChoiceChip(
                            avatar: Icon(c.icon, size: 18),
                            label: Text(c.label),
                            selected: selected,
                            showCheckmark: false,
                            onSelected: busy
                                ? null
                                : (_) {
                                    setState(() => _category = c);
                                    field.didChange(c);
                                  },
                          );
                        }).toList(),
                      ),
                      if (field.hasError)
                        Padding(
                          padding: const EdgeInsets.only(top: 8, left: 12),
                          child: Text(
                            field.errorText!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _title,
                  enabled: !busy,
                  maxLength: 80,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Short title',
                    hintText: 'e.g. Leaking tap in 2nd floor washroom',
                  ),
                  validator: Validators.title,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _description,
                  enabled: !busy,
                  minLines: 4,
                  maxLines: 8,
                  maxLength: 1000,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText:
                        'What did you notice, since when, and is anyone '
                        'at risk?',
                    alignLabelWithHint: true,
                  ),
                  validator: Validators.description,
                ),

                // ----- Where -----
                const _SectionLabel('Where is it?'),
                DropdownButtonFormField<String>(
                  initialValue: _building,
                  decoration: const InputDecoration(
                    labelText: 'Building or area',
                    prefixIcon: Icon(Icons.apartment_outlined),
                  ),
                  items: AppConfig.buildings
                      .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                      .toList(),
                  onChanged: busy
                      ? null
                      : (value) {
                          setState(() => _building = value);
                          // Re-check only the detail box (its rule depends on
                          // the building) once it has been shown an error.
                          if (_detailFieldKey.currentState?.hasError ?? false) {
                            _detailFieldKey.currentState!.validate();
                          }
                        },
                  validator: (v) =>
                      v == null ? 'Choose where the issue is' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: _detailFieldKey,
                  controller: _locationDetail,
                  enabled: !busy,
                  maxLength: 120,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: _isOtherArea
                        ? 'Describe the location (required)'
                        : 'Room or exact spot (optional)',
                    hintText: _isOtherArea
                        ? 'e.g. Footpath between the gate and the gym'
                        : 'e.g. Room 204, near the lifts',
                    prefixIcon: const Icon(Icons.place_outlined),
                  ),
                  validator: (v) => Validators.locationDetail(v, _building),
                ),

                if (!_isEditing)
                  _SimilarReports(
                    reports: incidents.similarOpen(_category, _building),
                  ),

                // ----- How urgent -----
                const _SectionLabel('How urgent is it?'),
                SegmentedButton<IncidentPriority>(
                  segments: IncidentPriority.values
                      .map((p) => ButtonSegment(value: p, label: Text(p.label)))
                      .toList(),
                  selected: {_priority},
                  onSelectionChanged: busy
                      ? null
                      : (s) => setState(() => _priority = s.first),
                ),
                if (_category == IncidentCategory.safety)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      'If someone is in immediate danger, contact campus '
                      'security directly as well as reporting here.',
                      style: text.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),

                // ----- Photo & privacy (new reports only) -----
                if (_isEditing)
                  Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: Text(
                      'The photo and anonymity can\'t be changed after a '
                      'report is sent. Delete and re-report if needed.',
                      style: text.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                if (!_isEditing) ...[
                  const _SectionLabel('Photo'),
                  PhotoPickerField(
                    photo: _photo,
                    enabled: !busy,
                    onChanged: (f) => setState(() => _photo = f),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _anonymous,
                    onChanged: busy
                        ? null
                        : (v) => setState(() => _anonymous = v),
                    title: const Text('Report anonymously'),
                    subtitle: const Text(
                      'Your name isn\'t stored with the report. You can '
                      'still track and edit it.',
                    ),
                  ),
                ],

                const SizedBox(height: 20),
                LoadingButton(
                  label: _isEditing
                      ? 'Save changes'
                      : _photo == null
                      ? 'Submit report'
                      : 'Upload & submit',
                  busy: busy,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleMedium
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// Shown when an open report already exists for the same category and
/// place, nudging the student to tap "Me too" rather than duplicate it.
class _SimilarReports extends StatelessWidget {
  const _SimilarReports({required this.reports});

  final List<Incident> reports;

  @override
  Widget build(BuildContext context) {
    if (reports.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline, color: Colors.amber.shade800),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Already reported?',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'These open reports match. If it\'s the same problem, open it '
            'and tap "Me too" instead.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
          ),
          const SizedBox(height: 8),
          for (final r in reports)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(r.category.icon),
              title: Text(
                r.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '${r.affectedCount} affected · ${formatWhen(r.createdAt)}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => IncidentDetailScreen(incidentId: r.id),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
