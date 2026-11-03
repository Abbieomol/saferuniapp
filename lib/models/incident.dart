import 'package:cloud_firestore/cloud_firestore.dart';

import 'incident_enums.dart';

/// One entry in a report's status timeline.
class StatusUpdate {
  final IncidentStatus status;
  final String note;
  final String updatedBy;
  final DateTime at;

  const StatusUpdate({
    required this.status,
    required this.note,
    required this.updatedBy,
    required this.at,
  });

  factory StatusUpdate.fromMap(Map<String, dynamic> map) => StatusUpdate(
    status: IncidentStatus.fromName(map['status'] as String?),
    note: map['note'] as String? ?? '',
    updatedBy: map['updatedBy'] as String? ?? '',
    at: (map['at'] as Timestamp?)?.toDate() ?? DateTime.now(),
  );

  Map<String, dynamic> toMap() => {
    'status': status.name,
    'note': note,
    'updatedBy': updatedBy,
    'at': Timestamp.fromDate(at),
  };
}

/// An incident report stored at `incidents/{id}` in Firestore.
class Incident {
  final String id;
  final String title;
  final String description;
  final IncidentCategory category;
  final IncidentPriority priority;
  final IncidentStatus status;
  final String building;
  final String locationDetail;
  final String? photoUrl;
  final String? photoPath; // Storage path, kept so the photo can be deleted
  final String reporterId;
  final String reporterName;
  final bool isAnonymous;
  final List<StatusUpdate> history;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Incident({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.priority,
    required this.status,
    required this.building,
    required this.locationDetail,
    required this.reporterId,
    required this.reporterName,
    required this.isAnonymous,
    required this.history,
    required this.createdAt,
    required this.updatedAt,
    this.photoUrl,
    this.photoPath,
  });

  /// Name shown to other students; anonymous reports hide the reporter.
  String get displayReporter =>
      isAnonymous ? 'Anonymous student' : reporterName;

  factory Incident.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final rawHistory = (data['history'] as List<dynamic>?) ?? const [];
    return Incident(
      id: doc.id,
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      category: IncidentCategory.fromName(data['category'] as String?),
      priority: IncidentPriority.fromName(data['priority'] as String?),
      status: IncidentStatus.fromName(data['status'] as String?),
      building: data['building'] as String? ?? '',
      locationDetail: data['locationDetail'] as String? ?? '',
      photoUrl: data['photoUrl'] as String?,
      photoPath: data['photoPath'] as String?,
      reporterId: data['reporterId'] as String? ?? '',
      reporterName: data['reporterName'] as String? ?? '',
      isAnonymous: data['isAnonymous'] as bool? ?? false,
      history: rawHistory
          .map((e) => StatusUpdate.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      // A just-written document can briefly have a null server timestamp.
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
