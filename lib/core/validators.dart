import 'app_config.dart';

/// Form validators shared by every screen, so rules are defined once.
/// Each returns an error message, or null when the value is valid.
class Validators {
  Validators._();

  static String? required(String? value, {String field = 'This field'}) {
    if (value == null || value.trim().isEmpty) return '$field is required';
    return null;
  }

  static String? aluEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Email is required';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'Enter a valid email address';
    }
    if (!AppConfig.isAllowedEmail(email)) {
      return 'Use your ALU email '
          '(@${AppConfig.studentDomain} or @${AppConfig.staffDomain})';
    }
    return null;
  }

  static String? password(String? value) {
    final pw = value ?? '';
    if (pw.isEmpty) return 'Password is required';
    if (pw.length < 8) return 'Use at least 8 characters';
    if (!RegExp(r'[A-Za-z]').hasMatch(pw) || !RegExp(r'\d').hasMatch(pw)) {
      return 'Include at least one letter and one number';
    }
    return null;
  }

  static String? fullName(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) return 'Name is required';
    if (name.length < 3) return 'Enter your full name';
    return null;
  }

  static String? title(String? value) {
    final t = value?.trim() ?? '';
    if (t.isEmpty) return 'Give the issue a short title';
    if (t.length < 5) return 'Title is too short';
    if (t.length > 80) return 'Keep the title under 80 characters';
    return null;
  }

  static String? description(String? value) {
    final d = value?.trim() ?? '';
    if (d.isEmpty) return 'Describe the issue';
    if (d.length < 15) return 'Add a bit more detail (at least 15 characters)';
    if (d.length > 1000) return 'Keep the description under 1000 characters';
    return null;
  }

  /// The free-text location box is required only for "Other area",
  /// where the building alone doesn't say where the problem is.
  static String? locationDetail(String? value, String? building) {
    final detail = value?.trim() ?? '';
    if (building == AppConfig.otherArea && detail.isEmpty) {
      return 'Describe where this is (e.g. "path behind the gym")';
    }
    if (detail.length > 120) return 'Keep this under 120 characters';
    return null;
  }
}
