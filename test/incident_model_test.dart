import 'package:campus_incident_app/models/incident_enums.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  group('Incident', () {
    test('anonymous reports never show the reporter name', () {
      final i = makeIncident(id: 'a', isAnonymous: true, reporterName: '');
      expect(i.displayReporter, 'Anonymous student');
    });

    test('named reports show the reporter name', () {
      expect(makeIncident(id: 'a').displayReporter, 'Test Student');
    });

    test('affected count includes the reporter', () {
      expect(makeIncident(id: 'a').affectedCount, 1);
      expect(makeIncident(id: 'a', affectedBy: ['x', 'y']).affectedCount, 3);
    });

    test('only "submitted" reports can be edited by the reporter', () {
      expect(makeIncident(id: 'a').isEditable, isTrue);
      expect(
        makeIncident(id: 'a', status: IncidentStatus.inProgress).isEditable,
        isFalse,
      );
    });

    test('resolved reports await confirmation until the reporter confirms', () {
      final resolved = makeIncident(id: 'a', status: IncidentStatus.resolved);
      expect(resolved.awaitingConfirmation, isTrue);

      final confirmed = makeIncident(
        id: 'a',
        status: IncidentStatus.resolved,
        reporterConfirmed: true,
      );
      expect(confirmed.awaitingConfirmation, isFalse);
    });
  });

  group('enums', () {
    test('unknown values from Firestore fall back safely', () {
      expect(IncidentCategory.fromName('nonsense'), IncidentCategory.other);
      expect(IncidentStatus.fromName(null), IncidentStatus.submitted);
      expect(IncidentPriority.fromName(''), IncidentPriority.medium);
    });

    test('resolved and rejected are closed, everything else is open', () {
      expect(IncidentStatus.resolved.isOpen, isFalse);
      expect(IncidentStatus.rejected.isOpen, isFalse);
      expect(IncidentStatus.inProgress.isOpen, isTrue);
    });
  });
}
