import 'package:flutter/material.dart';

/// Types of problem a student can report.
enum IncidentCategory {
  facilities('Broken facilities', Icons.build_outlined),
  water('Water shortage', Icons.water_drop_outlined),
  electricity('Electricity outage', Icons.bolt_outlined),
  furniture('Damaged furniture', Icons.chair_outlined),
  sanitation('Sanitation', Icons.cleaning_services_outlined),
  safety('Safety concern', Icons.health_and_safety_outlined),
  other('Other', Icons.help_outline);

  const IncidentCategory(this.label, this.icon);
  final String label;
  final IconData icon;

  static IncidentCategory fromName(String? name) => IncidentCategory.values
      .firstWhere((c) => c.name == name, orElse: () => IncidentCategory.other);
}

/// Lifecycle of a report, from submission to resolution.
/// Only staff may move a report between these states (enforced by
/// Firestore security rules, not just the UI).
enum IncidentStatus {
  submitted('Submitted', Color(0xFF6B7280)),
  inReview('In review', Color(0xFF2563EB)),
  inProgress('In progress', Color(0xFFD97706)),
  resolved('Resolved', Color(0xFF16A34A)),
  rejected('Rejected', Color(0xFFDC2626));

  const IncidentStatus(this.label, this.color);
  final String label;
  final Color color;

  bool get isOpen => this != resolved && this != rejected;

  static IncidentStatus fromName(String? name) =>
      IncidentStatus.values.firstWhere(
        (s) => s.name == name,
        orElse: () => IncidentStatus.submitted,
      );
}

/// How urgent the reporter thinks the issue is.
enum IncidentPriority {
  low('Low'),
  medium('Medium'),
  high('High');

  const IncidentPriority(this.label);
  final String label;

  static IncidentPriority fromName(String? name) => IncidentPriority.values
      .firstWhere((p) => p.name == name, orElse: () => IncidentPriority.medium);
}
