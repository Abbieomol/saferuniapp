import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import '../models/incident.dart';
import '../models/incident_enums.dart';
import '../services/incident_repository.dart';

/// How the feed is ordered.
enum SortOrder {
  newest('Newest first'),
  mostAffected('Most affected');

  const SortOrder(this.label);
  final String label;
}

/// App-wide incident state, shared through Provider.
///
/// Holds one live Firestore subscription to every report, plus the
/// current search text and filters. Every screen that shows reports reads
/// from here, so a new report or a staff status change appears on all
/// screens at once without manual refreshing.
class IncidentProvider extends ChangeNotifier {
  IncidentProvider({IncidentRepository? repository})
    : _repo = repository ?? IncidentRepository();

  final IncidentRepository _repo;
  StreamSubscription<List<Incident>>? _sub;
  AppUser? _user;

  List<Incident> _all = const [];
  bool _loading = false;
  String? _loadError;
  bool _submitting = false;
  String? _submitError;

  // Filters (used by the feed; stage 3 adds the filter UI).
  String _query = '';
  IncidentCategory? _category;
  IncidentStatus? _status;
  String? _building;
  bool _mineOnly = false;
  SortOrder _sort = SortOrder.newest;

  // ---------- Getters ----------

  AppUser? get user => _user;
  bool get loading => _loading;
  String? get loadError => _loadError;
  bool get submitting => _submitting;
  String? get submitError => _submitError;
  List<Incident> get all => _all;

  String get query => _query;
  IncidentCategory? get category => _category;
  IncidentStatus? get status => _status;
  String? get building => _building;
  bool get mineOnly => _mineOnly;
  SortOrder get sort => _sort;
  bool get hasSearchOrFilters =>
      _query.trim().isNotEmpty || activeFilterCount > 0;

  int get activeFilterCount => [
    _category != null,
    _status != null,
    _building != null,
    _mineOnly,
  ].where((on) => on).length;

  /// Reports after search, filters and sorting are applied.
  List<Incident> get visible {
    final q = _query.trim().toLowerCase();
    final result = _all.where((i) {
      if (_category != null && i.category != _category) return false;
      if (_status != null && i.status != _status) return false;
      if (_building != null && i.building != _building) return false;
      if (_mineOnly && i.reporterId != _user?.uid) return false;
      if (q.isEmpty) return true;
      return i.title.toLowerCase().contains(q) ||
          i.description.toLowerCase().contains(q) ||
          i.building.toLowerCase().contains(q) ||
          i.locationDetail.toLowerCase().contains(q) ||
          i.category.label.toLowerCase().contains(q);
    }).toList();
    if (_sort == SortOrder.mostAffected) {
      // Stable: equal counts keep newest-first order from Firestore.
      final indexed = result.asMap().entries.toList()
        ..sort((a, b) {
          final byCount = b.value.affectedCount.compareTo(
            a.value.affectedCount,
          );
          return byCount != 0 ? byCount : a.key.compareTo(b.key);
        });
      return indexed.map((e) => e.value).toList();
    }
    return result;
  }

  /// Open reports in the same place and category: shown on the report
  /// form so students can tap "Me too" instead of filing a duplicate.
  List<Incident> similarOpen(IncidentCategory? category, String? building) {
    if (category == null || building == null) return const [];
    return _all
        .where(
          (i) =>
              i.status.isOpen &&
              i.category == category &&
              i.building == building,
        )
        .take(3)
        .toList();
  }

  int get myReportCount => _all.where((i) => i.isReportedBy(_user?.uid)).length;

  int countByStatus(IncidentStatus s) =>
      _all.where((i) => i.status == s).length;

  int get openCount => _all.where((i) => i.status.isOpen).length;

  Incident? byId(String id) {
    for (final i in _all) {
      if (i.id == id) return i;
    }
    return null;
  }

  // ---------- Connecting to the signed-in user ----------

  /// Called by ChangeNotifierProxyProvider whenever AuthProvider changes.
  /// Runs during a build, so it must not call notifyListeners directly.
  void updateUser(AppUser? user) {
    final sameAccount = user?.uid == _user?.uid;
    _user = user;
    if (sameAccount) return;

    _sub?.cancel();
    _sub = null;
    _all = const [];
    _loadError = null;
    _clearFiltersSilently();

    if (user == null) {
      _loading = false;
      return;
    }
    _listen();
  }

  void _listen() {
    _loading = true;
    _sub = _repo.watchAll().listen(
      (list) {
        _all = list;
        _loading = false;
        _loadError = null;
        notifyListeners();
      },
      onError: (Object e) {
        _loading = false;
        _loadError =
            'Could not load reports. Check your connection and try again.';
        notifyListeners();
      },
    );
  }

  void retry() {
    _sub?.cancel();
    _listen();
    notifyListeners();
  }

  // ---------- Filters ----------

  void setQuery(String value) {
    _query = value;
    notifyListeners();
  }

  void setCategory(IncidentCategory? value) {
    _category = value;
    notifyListeners();
  }

  void setStatus(IncidentStatus? value) {
    _status = value;
    notifyListeners();
  }

  void setBuilding(String? value) {
    _building = value;
    notifyListeners();
  }

  void setMineOnly(bool value) {
    _mineOnly = value;
    notifyListeners();
  }

  void setSort(SortOrder value) {
    _sort = value;
    notifyListeners();
  }

  void clearFilters() {
    _clearFiltersSilently();
    notifyListeners();
  }

  void _clearFiltersSilently() {
    _query = '';
    _category = null;
    _status = null;
    _building = null;
    _mineOnly = false;
    _sort = SortOrder.newest;
  }

  // ---------- Creating a report ----------

  Future<bool> submitReport({
    required String title,
    required String description,
    required IncidentCategory category,
    required IncidentPriority priority,
    required String building,
    required String locationDetail,
    required bool isAnonymous,
    File? photo,
  }) async {
    final reporter = _user;
    if (reporter == null) return false;

    _submitting = true;
    _submitError = null;
    notifyListeners();
    try {
      await _repo.create(
        reporter: reporter,
        title: title,
        description: description,
        category: category,
        priority: priority,
        building: building,
        locationDetail: locationDetail,
        isAnonymous: isAnonymous,
        photo: photo,
      );
      return true;
    } catch (e, stack) {
      // Full details go to the terminal running `flutter run`.
      debugPrint('submitReport failed: $e\n$stack');
      _submitError = _friendlyError(e);
      return false;
    } finally {
      _submitting = false;
      notifyListeners();
    }
  }

  void clearSubmitError() {
    _submitError = null;
    notifyListeners();
  }

  // ---------- Editing an existing report ----------

  Future<bool> updateReport({
    required String incidentId,
    required String title,
    required String description,
    required IncidentCategory category,
    required IncidentPriority priority,
    required String building,
    required String locationDetail,
  }) async {
    _submitting = true;
    _submitError = null;
    notifyListeners();
    try {
      await _repo.updateDetails(
        incidentId: incidentId,
        title: title,
        description: description,
        category: category,
        priority: priority,
        building: building,
        locationDetail: locationDetail,
      );
      return true;
    } catch (e, stack) {
      debugPrint('updateReport failed: $e\n$stack');
      _submitError = _friendlyError(e);
      return false;
    } finally {
      _submitting = false;
      notifyListeners();
    }
  }

  // ---------- One-tap actions on a report ----------
  // Each returns null on success or a message for a SnackBar.

  final Set<String> _busyIds = {};

  /// True while an action on this report is in flight (disables buttons).
  bool isBusy(String incidentId) => _busyIds.contains(incidentId);

  Future<String?> toggleAffected(Incident incident) {
    final uid = _user?.uid;
    if (uid == null) return Future.value('Please sign in again.');
    return _action(
      incident.id,
      () => _repo.setAffected(
        incidentId: incident.id,
        uid: uid,
        affected: !incident.isAffecting(uid),
      ),
    );
  }

  Future<String?> respondToResolution(
    Incident incident, {
    required bool fixed,
    String note = '',
  }) => _action(
    incident.id,
    () => _repo.respondToResolution(
      incidentId: incident.id,
      fixed: fixed,
      note: note,
    ),
  );

  Future<String?> deleteReport(Incident incident) =>
      _action(incident.id, () => _repo.delete(incident));

  Future<String?> _action(String id, Future<void> Function() run) async {
    _busyIds.add(id);
    notifyListeners();
    try {
      await run();
      return null;
    } catch (e, stack) {
      debugPrint('Action on $id failed: $e\n$stack');
      return _friendlyError(e);
    } finally {
      _busyIds.remove(id);
      notifyListeners();
    }
  }

  static String _friendlyError(Object e) {
    if (e is FirebaseException) {
      switch (e.code) {
        case 'permission-denied':
        case 'unauthorized':
          return 'You don\'t have permission to do that. '
              'Make sure your email is verified.';
        case 'unavailable':
        case 'retry-limit-exceeded':
          return 'No connection to the server. Check your internet and try again.';
        case 'canceled':
          return 'Upload was cancelled.';
        case 'bucket-not-found':
        case 'no-default-bucket':
          return 'Photo storage isn\'t set up for this app yet.';
      }
      return 'That didn\'t work (${e.plugin}/${e.code}). Please try again.';
    }
    return 'Something went wrong. Please try again.';
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
