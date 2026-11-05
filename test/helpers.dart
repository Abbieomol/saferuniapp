import 'package:campus_incident_app/models/app_user.dart';
import 'package:campus_incident_app/models/incident.dart';
import 'package:campus_incident_app/models/incident_enums.dart';

/// Builders for test data, so each test only states what matters to it.

const student = AppUser(
  uid: 'student-1',
  email: 'student@alustudent.com',
  fullName: 'Test Student',
  role: UserRole.student,
);

const otherStudent = AppUser(
  uid: 'student-2',
  email: 'other@alustudent.com',
  fullName: 'Other Student',
  role: UserRole.student,
);

const staff = AppUser(
  uid: 'staff-1',
  email: 'staff@alueducation.com',
  fullName: 'Test Staff',
  role: UserRole.staff,
);

Incident makeIncident({
  required String id,
  String title = 'Broken tap in washroom',
  String description = 'The tap will not close and water is leaking.',
  IncidentCategory category = IncidentCategory.water,
  IncidentPriority priority = IncidentPriority.medium,
  IncidentStatus status = IncidentStatus.submitted,
  String building = 'Enterprise',
  String locationDetail = '',
  String reporterId = 'student-1',
  String reporterName = 'Test Student',
  bool isAnonymous = false,
  List<String> affectedBy = const [],
  bool? reporterConfirmed,
  DateTime? createdAt,
}) {
  final created = createdAt ?? DateTime(2026, 11, 1, 9);
  return Incident(
    id: id,
    title: title,
    description: description,
    category: category,
    priority: priority,
    status: status,
    building: building,
    locationDetail: locationDetail,
    reporterId: reporterId,
    reporterName: reporterName,
    isAnonymous: isAnonymous,
    history: [
      StatusUpdate(
        status: IncidentStatus.submitted,
        note: 'Report submitted',
        updatedBy: 'Reporter',
        at: created,
      ),
    ],
    affectedBy: affectedBy,
    reporterConfirmed: reporterConfirmed,
    createdAt: created,
    updatedAt: created,
  );
}
