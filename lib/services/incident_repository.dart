import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';
import '../models/incident.dart';
import '../models/incident_enums.dart';
import 'storage_service.dart';

/// All Firestore reads and writes for incident reports (the CRUD layer).
class IncidentRepository {
  IncidentRepository({FirebaseFirestore? db, StorageService? storage})
    : _incidents = (db ?? FirebaseFirestore.instance).collection('incidents'),
      _storage = storage ?? StorageService();

  final CollectionReference<Map<String, dynamic>> _incidents;
  final StorageService _storage;

  // ---------- Read ----------

  /// Every report, newest first. Filtering and search happen in the
  /// IncidentProvider so changing a filter doesn't re-query Firestore.
  Stream<List<Incident>> watchAll() => _incidents
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map(Incident.fromDoc).toList());

  Stream<Incident?> watchOne(String id) => _incidents
      .doc(id)
      .snapshots()
      .map((doc) => doc.exists ? Incident.fromDoc(doc) : null);

  // ---------- Create ----------

  Future<void> create({
    required AppUser reporter,
    required String title,
    required String description,
    required IncidentCategory category,
    required IncidentPriority priority,
    required String building,
    required String locationDetail,
    required bool isAnonymous,
    File? photo,
  }) async {
    String? photoUrl;
    String? photoPath;
    if (photo != null) {
      final uploaded = await _storage.uploadIncidentPhoto(
        uid: reporter.uid,
        file: photo,
      );
      photoUrl = uploaded.url;
      photoPath = uploaded.path;
    }

    final firstEntry = StatusUpdate(
      status: IncidentStatus.submitted,
      note: 'Report submitted',
      updatedBy: 'Reporter',
      at: DateTime.now(),
    );

    try {
      await _incidents.add({
        'title': title.trim(),
        'description': description.trim(),
        'category': category.name,
        'priority': priority.name,
        'status': IncidentStatus.submitted.name,
        'building': building,
        'locationDetail': locationDetail.trim(),
        'photoUrl': photoUrl,
        'photoPath': photoPath,
        // reporterId is an opaque uid, needed so the rules can let the
        // reporter edit/delete. The name is not stored for anonymous
        // reports, so it can't leak to anyone reading the database.
        'reporterId': reporter.uid,
        'reporterName': isAnonymous ? '' : reporter.fullName,
        'isAnonymous': isAnonymous,
        'history': [firstEntry.toMap()],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Don't leave an orphaned photo if the report itself failed.
      if (photoPath != null) await _storage.deletePhoto(photoPath);
      rethrow;
    }
  }

  // ---------- Update ----------

  /// Staff only (enforced by security rules). Appends to the timeline.
  Future<void> updateStatus({
    required String incidentId,
    required IncidentStatus status,
    required String note,
    required AppUser staff,
  }) {
    final entry = StatusUpdate(
      status: status,
      note: note.trim().isEmpty
          ? 'Status changed to ${status.label}'
          : note.trim(),
      updatedBy: staff.fullName,
      at: DateTime.now(),
    );
    return _incidents.doc(incidentId).update({
      'status': status.name,
      'history': FieldValue.arrayUnion([entry.toMap()]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Reporter may correct their own report while it is still "submitted".
  Future<void> updateDetails({
    required String incidentId,
    required String title,
    required String description,
    required IncidentCategory category,
    required IncidentPriority priority,
    required String building,
    required String locationDetail,
  }) {
    return _incidents.doc(incidentId).update({
      'title': title.trim(),
      'description': description.trim(),
      'category': category.name,
      'priority': priority.name,
      'building': building,
      'locationDetail': locationDetail.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// "This affects me too": adds or removes only the caller's own uid.
  /// arrayUnion/arrayRemove avoid overwriting other students' taps.
  Future<void> setAffected({
    required String incidentId,
    required String uid,
    required bool affected,
  }) {
    return _incidents.doc(incidentId).update({
      'affectedBy': affected
          ? FieldValue.arrayUnion([uid])
          : FieldValue.arrayRemove([uid]),
    });
  }

  /// Reporter's answer after staff mark a report resolved.
  /// Confirmed: stays resolved. Still broken: reopens as "In review".
  Future<void> respondToResolution({
    required String incidentId,
    required bool fixed,
    required String note,
  }) {
    final status = fixed ? IncidentStatus.resolved : IncidentStatus.inReview;
    final entry = StatusUpdate(
      status: status,
      note: note.trim().isNotEmpty
          ? note.trim()
          : fixed
          ? 'Reporter confirmed the issue is fixed'
          : 'Reporter says the issue is still not fixed',
      updatedBy: 'Reporter',
      at: DateTime.now(),
    );
    return _incidents.doc(incidentId).update({
      'status': status.name,
      'reporterConfirmed': fixed,
      'history': FieldValue.arrayUnion([entry.toMap()]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ---------- Delete ----------

  /// Reporter (while still "submitted") or staff. Removes the photo too.
  Future<void> delete(Incident incident) async {
    await _incidents.doc(incident.id).delete();
    if (incident.photoPath != null) {
      await _storage.deletePhoto(incident.photoPath!);
    }
  }
}
