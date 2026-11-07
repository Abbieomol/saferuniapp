import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import '../models/incident.dart';
import '../models/incident_enums.dart';
import '../services/incident_repository.dart';


enum SortOrder {
  newest('Newest first'),
  mostAffected('Most affected');

  const SortOrder(this.label);
  final String label;
}

class IncidentProvider extends ChangeNotifier {
  IncidentProvider({IncidentRepository? repository})
    : _repoOverride = repository;

  IncidentRepository? _repoOverride;
  IncidentRepository get _repo => _repoOverride ??= IncidentRepository();

  StreamSubscription<({List<Incident> items, bool fromCache})>? _sub;
  Timer? _offlineTimer;
  bool _offline = false;
  bool _lastSubmitQueued = false;
  AppUser? _user;

  List<Incident> _all = const [];
  bool _loading = false;
  String? _loadError;
  bool _submitting = false;
  String? _submitError;

 
  String _query = '';
  IncidentCategory? _category;
  IncidentStatus? _status;
  String? _building;
  bool _mineOnly = false;
  SortOrder _sort = SortOrder.newest;


  AppUser? get user => _user;


  bool get offline => _offline;

  /// The last report was saved offline and will send when reconnected.
  bool get lastSubmitQueued => _lastSubmitQueued;
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


  int countByCategory(IncidentCategory c) =>
      _all.where((i) => i.category == c && i.status.isOpen).length;

  bool isReopened(Incident i) =>
      i.status == IncidentStatus.inReview && i.reporterConfirmed == false;


  List<Incident> get needsAttention {
    int rank(IncidentPriority p) => switch (p) {
      IncidentPriority.high => 0,
      IncidentPriority.medium => 1,
      IncidentPriority.low => 2,
    };
    final open = _all.where((i) => i.status.isOpen).toList()
      ..sort((a, b) {
        final reopened = (isReopened(a) ? 0 : 1).compareTo(
          isReopened(b) ? 0 : 1,
        );
        if (reopened != 0) return reopened;
        final priority = rank(a.priority).compareTo(rank(b.priority));
        if (priority != 0) return priority;
        final affected = b.affectedCount.compareTo(a.affectedCount);
        if (affected != 0) return affected;
        return a.createdAt.compareTo(b.createdAt);
      });
    return open;
  }

  int get reopenedCount => _all.where(isReopened).length;

  int get awaitingConfirmationCount =>
      _all.where((i) => i.awaitingConfirmation).length;

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
      (feed) {
        _all = feed.items;
        _loading = false;
        _loadError = null;
        _trackConnection(feed.fromCache);
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

  void _trackConnection(bool fromCache) {
    if (!fromCache) {
      _offlineTimer?.cancel();
      _offline = false;
      return;
    }
    if (_offline || (_offlineTimer?.isActive ?? false)) return;
    _offlineTimer = Timer(const Duration(seconds: 3), () {
      _offline = true;
      notifyListeners();
    });
  }

  @visibleForTesting
  void debugSetData(List<Incident> incidents, {AppUser? user}) {
    _all = incidents;
    _user = user;
    _loading = false;
    notifyListeners();
  }

  void retry() {
    _sub?.cancel();
    _listen();
    notifyListeners();
  }


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
    _lastSubmitQueued = false;
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
    } on TimeoutException {
      // No connection: Firestore has saved it on the phone and will
      // send it automatically, so this still counts as success.
      _lastSubmitQueued = true;
      return true;
    } catch (e, stack) {
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
      await _repo
          .updateDetails(
            incidentId: incidentId,
            title: title,
            description: description,
            category: category,
            priority: priority,
            building: building,
            locationDetail: locationDetail,
          )
          .timeout(IncidentRepository.writeTimeout);
      return true;
    } on TimeoutException {
      return true; // saved offline; syncs automatically
    } catch (e, stack) {
      debugPrint('updateReport failed: $e\n$stack');
      _submitError = _friendlyError(e);
      return false;
    } finally {
      _submitting = false;
      notifyListeners();
    }
  }


  final Set<String> _busyIds = {};

  /// True while an action on this report is in flight.
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

  Future<String?> updateStatus(
    Incident incident,
    IncidentStatus status,
    String note,
  ) {
    final staff = _user;
    if (staff == null || !staff.isStaff) {
      return Future.value('Only campus staff can change a report\'s status.');
    }
    return _action(
      incident.id,
      () => _repo.updateStatus(
        incidentId: incident.id,
        status: status,
        note: note,
        staff: staff,
      ),
    );
  }

  Future<String?> deleteReport(Incident incident) =>
      _action(incident.id, () => _repo.delete(incident));

  Future<String?> _action(String id, Future<void> Function() run) async {
    _busyIds.add(id);
    notifyListeners();
    try {
      await run().timeout(IncidentRepository.writeTimeout);
      return null;
    } on TimeoutException {
      // Applied to the local copy already; Firestore syncs it later.
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
    _offlineTimer?.cancel();
    super.dispose();
  }
}
