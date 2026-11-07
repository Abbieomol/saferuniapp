# Safer Uni

Safer Uni is a campus incident reporting app for ALU Rwanda. When something on campus is broken or unsafe, such as a leaking tap in Learning Commons, lights out in the parking lot or even security concerns, students can report it from a phone and follow it until it is fixed. Campus staff get a separate view for reviewing reports and updating each one as the work progresses.

- Demo video: =====

## Features

**Students can:**

- sign up with an ALU email only, and verify it before using the app
- report an issue with a category, description, building (Enterprise, Social Commons, Learning Commons, Parking, or "Other area" with a description) and urgency
- attach an optional photo
- report anonymously, with no name saved on the report
- browse, search and filter all campus reports by status, category or building
- open a report to see its photo, details and a timeline of every status change
- edit or delete self-submitted reports before staff begin work
- tap "Me too" on another student's open report
- confirm a fix, or reopen the report, once staff mark it as resolved
- keep reporting even when offline; reports are saved on the phone and sent once the connection returns

**Staff can also:**

- view a dashboard with report counts per status and open issues per category
- work through a "Needs attention" list ordered by reopened reports, then urgent ones, then the most affected
- change a report's status with a note visible to the student (a note is required when resolving or rejecting)
- delete spam or abusive reports

## Built with

| Part | Technology |
|---|---|
| App | Flutter |
| State management | Provider |
| Sign-in | Firebase Authentication with email verification |
| Database | Cloud Firestore |
| Photos | Firebase Storage, compressed on the device before upload |
| Access control | Firestore and Storage security rules |
| Font | Plus Jakarta Sans (google_fonts) |

## Project structure

UI, app state and Firebase access are kept in separate folders:

lib/
  core/       campus settings (domains, buildings), theme, form validation
  models/     data shapes: users, incidents, status updates
  services/   all communication with Firebase
  providers/  app-wide state that screens listen to
  screens/    login, home, report form, report details, staff dashboard
  widgets/    reusable pieces such as cards, chips, the timeline and the filter sheet

Screens never talk to Firebase directly. All data flows through two providers:

- AuthProvider tracks whether the user is signed out, waiting for email verification, or signed in, and whether the account is student or staff. The app's first screen reads this state and shows the right page, so signing in or out needs no manual navigation.
- IncidentProvider holds a single live connection to all reports in Firestore, plus the current search and filters. Every screen reads from it, so new reports and staff updates appear everywhere immediately. It is linked to AuthProvider, connecting on sign-in and disconnecting on sign-out.

setState is used only for state that belongs to a single screen, such as text typed into a form.

Provider was chosen because it is the Flutter team's recommended starting point, simple to read and explain, and sufficient for an app with two pieces of shared state. Riverpod or BLoC would also work but would add structure the app does not need at this size.

## Running the app

Requirements: Flutter, Android Studio with an emulator, Node.js, the Firebase CLI (`npm install -g firebase-tools`) and the FlutterFire CLI (`dart pub global activate flutterfire_cli`).

```bash
git clone https://github.com/Abbieomol/saferuniapp.git
cd saferuniapp
flutter pub get
```

The app is connected to the project's own Firebase backend. To run it against a different Firebase project:

1. Create a Firebase project and enable Email/Password sign-in, Firestore and Storage (Storage requires the Blaze plan).
2. Connect the app: `flutterfire configure --project=<project-id> --platforms=android`
3. Deploy the security rules: `firebase deploy --only "firestore:rules,storage" --project <project-id>`
4. Start the app: `flutter run`

To try the staff side, register and verify an ALU email in the app, then set that user's `role` to `staff` in Firestore. The Staff badge and Dashboard tab appear immediately.

## Future improvements

- push notifications when a report's status changes
- a screen for managing staff inside the app instead of the Firebase console
- photo uploads still need internet; only text reports work offline
- if a report is deleted while offline, its photo can be left behind in Storage

## About

Leila Omol, Formative 2 assignment.