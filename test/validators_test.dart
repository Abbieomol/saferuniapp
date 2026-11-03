import 'package:campus_incident_app/core/app_config.dart';
import 'package:campus_incident_app/core/validators.dart';
import 'package:flutter_test/flutter_test.dart';

// Unit tests for the form rules. They run without Firebase or a device:
//   flutter test
void main() {
  group('ALU email', () {
    test('accepts student and staff domains', () {
      expect(Validators.aluEmail('l.omol@alustudent.com'), isNull);
      expect(Validators.aluEmail('staff@alueducation.com'), isNull);
      expect(Validators.aluEmail('  Mixed@ALUSTUDENT.com '), isNull);
    });

    test('rejects other domains and bad input', () {
      expect(Validators.aluEmail('someone@gmail.com'), isNotNull);
      expect(Validators.aluEmail('fake@alustudent.com.evil.com'), isNotNull);
      expect(Validators.aluEmail('not-an-email'), isNotNull);
      expect(Validators.aluEmail(''), isNotNull);
    });
  });

  group('password', () {
    test('needs 8+ characters with a letter and a number', () {
      expect(Validators.password('abc123'), isNotNull);
      expect(Validators.password('abcdefgh'), isNotNull);
      expect(Validators.password('12345678'), isNotNull);
      expect(Validators.password('safer2026'), isNull);
    });
  });

  group('location detail', () {
    test('required only for "Other area"', () {
      expect(Validators.locationDetail('', 'Enterprise'), isNull);
      expect(Validators.locationDetail('', AppConfig.otherArea), isNotNull);
      expect(
        Validators.locationDetail('Path behind the gym', AppConfig.otherArea),
        isNull,
      );
    });
  });

  group('report text', () {
    test('title and description lengths', () {
      expect(Validators.title('Leak'), isNotNull);
      expect(Validators.title('Leaking tap in washroom'), isNull);
      expect(Validators.description('Broken'), isNotNull);
      expect(
        Validators.description('The tap on the second floor will not close.'),
        isNull,
      );
    });
  });
}
