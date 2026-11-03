/// Campus-specific settings for ALU Rwanda.
///
/// Everything that would change if the app were rolled out to another
/// campus lives here, so the rest of the code never hard-codes it.
class AppConfig {
  AppConfig._();

  static const String campusName = 'ALU Rwanda';
  static const String appName = 'Safer Uni';

  /// Only these email domains may register or sign in.
  /// The role (student/staff) is NOT decided by the domain — it is stored
  /// in Firestore and can only be changed from the Firebase console.
  static const String studentDomain = 'alustudent.com';
  static const String staffDomain = 'alueducation.com';
  static const List<String> allowedEmailDomains = [studentDomain, staffDomain];

  /// Choice for anywhere not in [buildings]. When picked, the reporter
  /// must describe the place in the free-text location field.
  static const String otherArea = 'Other area';

  /// Campus buildings shown in the location picker.
  static const List<String> buildings = [
    'Enterprise',
    'Social Commons',
    'Learning Commons',
    'Parking',
    otherArea,
  ];

  static bool isAllowedEmail(String email) {
    final parts = email.trim().toLowerCase().split('@');
    if (parts.length != 2 || parts.first.isEmpty) return false;
    return allowedEmailDomains.contains(parts.last);
  }
}
