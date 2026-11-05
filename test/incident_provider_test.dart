import 'package:campus_incident_app/models/incident_enums.dart';
import 'package:campus_incident_app/providers/incident_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

// Tests the business logic in IncidentProvider (search, filters, sorting,
// duplicate detection, staff queue) with in-memory data, no Firebase.
void main() {
  late IncidentProvider provider;

  final leak = makeIncident(
    id: 'leak',
    title: 'Leaking tap',
    category: IncidentCategory.water,
    building: 'Enterprise',
    createdAt: DateTime(2026, 11, 3),
  );
  final light = makeIncident(
    id: 'light',
    title: 'Corridor lights out',
    description: 'Half of the corridor lights stop working at night.',
    category: IncidentCategory.electricity,
    building: 'Learning Commons',
    status: IncidentStatus.inProgress,
    reporterId: 'student-2',
    affectedBy: ['a', 'b', 'c'],
    createdAt: DateTime(2026, 11, 2),
  );
  final chair = makeIncident(
    id: 'chair',
    title: 'Broken chair',
    description: 'Leg snapped off a chair in the study area.',
    category: IncidentCategory.furniture,
    building: 'Social Commons',
    status: IncidentStatus.resolved,
    priority: IncidentPriority.low,
    createdAt: DateTime(2026, 11, 1),
  );

  setUp(() {
    provider = IncidentProvider();
    // Firestore returns newest first; keep that order here too.
    provider.debugSetData([leak, light, chair], user: student);
  });

  group('search', () {
    test('matches title, description and location, ignoring case', () {
      provider.setQuery('TAP');
      expect(provider.visible.map((i) => i.id), ['leak']);

      provider.setQuery('study area');
      expect(provider.visible.map((i) => i.id), ['chair']);

      provider.setQuery('learning');
      expect(provider.visible.map((i) => i.id), ['light']);
    });

    test('empty search shows everything', () {
      provider.setQuery('   ');
      expect(provider.visible.length, 3);
    });
  });

  group('filters', () {
    test('status, category and building combine', () {
      provider.setStatus(IncidentStatus.inProgress);
      expect(provider.visible.map((i) => i.id), ['light']);

      provider.setStatus(null);
      provider.setCategory(IncidentCategory.furniture);
      expect(provider.visible.map((i) => i.id), ['chair']);

      provider.setBuilding('Enterprise');
      expect(provider.visible, isEmpty);
    });

    test('"My reports" shows only the signed-in user\'s reports', () {
      provider.setMineOnly(true);
      expect(provider.visible.map((i) => i.id), ['leak', 'chair']);
    });

    test('active filter count and clearing', () {
      provider.setStatus(IncidentStatus.resolved);
      provider.setMineOnly(true);
      expect(provider.activeFilterCount, 2);
      expect(provider.hasSearchOrFilters, isTrue);

      provider.clearFilters();
      expect(provider.activeFilterCount, 0);
      expect(provider.visible.length, 3);
    });
  });

  group('sorting', () {
    test('most affected first, newest first among equals', () {
      provider.setSort(SortOrder.mostAffected);
      expect(provider.visible.map((i) => i.id), ['light', 'leak', 'chair']);
    });
  });

  group('duplicate detection', () {
    test('finds open reports with the same category and building', () {
      final similar = provider.similarOpen(
        IncidentCategory.water,
        'Enterprise',
      );
      expect(similar.map((i) => i.id), ['leak']);
    });

    test('ignores closed reports and needs both fields', () {
      expect(
        provider.similarOpen(IncidentCategory.furniture, 'Social Commons'),
        isEmpty,
      );
      expect(provider.similarOpen(null, 'Enterprise'), isEmpty);
    });
  });

  group('staff queue', () {
    test('reopened first, then high priority, then most affected', () {
      final urgent = makeIncident(
        id: 'urgent',
        priority: IncidentPriority.high,
        createdAt: DateTime(2026, 11, 4),
      );
      final reopened = makeIncident(
        id: 'reopened',
        status: IncidentStatus.inReview,
        reporterConfirmed: false,
        createdAt: DateTime(2026, 11, 5),
      );
      provider.debugSetData([
        reopened,
        urgent,
        leak,
        light,
        chair,
      ], user: staff);

      expect(provider.needsAttention.map((i) => i.id), [
        'reopened',
        'urgent',
        'light',
        'leak',
      ]);
      expect(provider.reopenedCount, 1);
      expect(provider.awaitingConfirmationCount, 1); // the resolved chair
    });
  });

  group('counts', () {
    test('open and per-status counts', () {
      expect(provider.openCount, 2);
      expect(provider.countByStatus(IncidentStatus.resolved), 1);
      expect(
        provider.countByCategory(IncidentCategory.furniture),
        0,
        reason: 'resolved reports are not open',
      );
    });
  });

  test('students cannot change status, even by calling the provider', () async {
    final error = await provider.updateStatus(
      leak,
      IncidentStatus.resolved,
      'Fixed',
    );
    expect(error, contains('Only campus staff'));
  });
}
