import 'package:flutter/material.dart';

/// Types of problem a student can report.
enum IncidentCategory {
  facilities('Broken facilities', Icons.build_outlined, Color(0xFF6D5BD0)),
  water('Water shortage', Icons.water_drop_outlined, Color(0xFF0EA5E9)),
  electricity('Electricity outage', Icons.bolt_outlined, Color(0xFFF59E0B)),
  furniture('Damaged furniture', Icons.chair_outlined, Color(0xFF9A6B3F)),
  sanitation('Sanitation', Icons.cleaning_services_outlined, Color(0xFF10B981)),
  safety('Safety concern', Icons.health_and_safety_outlined, Color(0xFFEF4444)),
  other('Other', Icons.help_outline, Color(0xFF64748B));

  const IncidentCategory(this.label, this.icon, this.color);
  final String label;
  final IconData icon;

  /// Used for the category's icon tile so types are easy to tell apart.
  final Color color;

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
