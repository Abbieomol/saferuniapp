import 'package:campus_incident_app/models/incident_enums.dart';
import 'package:campus_incident_app/widgets/auth_scaffold.dart';
import 'package:campus_incident_app/widgets/incident_card.dart';
import 'package:campus_incident_app/widgets/status_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('StatusChip shows the status label', (tester) async {
    await tester.pumpWidget(
      wrap(const StatusChip(status: IncidentStatus.inProgress)),
    );
    expect(find.text('In progress'), findsOneWidget);
  });

  testWidgets('LoadingButton disables itself and shows a spinner while busy', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      wrap(LoadingButton(label: 'Submit', busy: true, onPressed: () => taps++)),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Submit'), findsNothing);
    await tester.tap(find.byType(FilledButton));
    expect(taps, 0);
  });

  testWidgets('IncidentCard shows title, location, status and tap', (
    tester,
  ) async {
    var tapped = false;
    final incident = makeIncident(
      id: 'x',
      title: 'Lights out on stairs',
      building: 'Learning Commons',
      locationDetail: 'Main staircase',
      status: IncidentStatus.inReview,
      priority: IncidentPriority.high,
      affectedBy: ['a', 'b'],
    );
    await tester.pumpWidget(
      wrap(IncidentCard(incident: incident, onTap: () => tapped = true)),
    );

    expect(find.text('Lights out on stairs'), findsOneWidget);
    expect(find.text('Learning Commons · Main staircase'), findsOneWidget);
    expect(find.text('In review'), findsOneWidget);
    expect(find.text('High'), findsOneWidget);
    expect(find.text('3'), findsOneWidget); // affected count

    await tester.tap(find.byType(IncidentCard));
    expect(tapped, isTrue);
  });
}
