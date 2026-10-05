import 'package:flutter/services.dart';

/// Centralized security validation logic for Phase 5 Input Sanitization.
class AppValidators {
  /// Regular expression to match potentially dangerous characters and patterns
  /// including HTML tags, quotes, javascript pseudo-protocols, and control chars.
  static final RegExp _maliciousPattern = RegExp(
    "[<>\"']|javascript:|onerror=|\\x00-\\x1F",
    caseSensitive: false,
  );

  /// Validates that the input does not contain malicious characters.
  /// Returns null if valid, or an error string if invalid.
  static String? validateSanitized(String? value, {String? fieldName}) {
    if (value == null || value.isEmpty) {
      return null; // Let required validators handle emptiness if needed
    }
    if (_maliciousPattern.hasMatch(value)) {
      return 'Invalid characters detected in ${fieldName ?? 'input'}.';
    }
    return null;
  }

  /// Validates that the input is not empty and does not contain malicious characters.
  static String? validateRequiredSanitized(String? value, {String? fieldName}) {
    if (value == null || value.trim().isEmpty) {
      return '${fieldName ?? 'Field'} is required.';
    }
    return validateSanitized(value, fieldName: fieldName);
  }
}

class AppInputFormatters {
  /// A formatter that denies dangerous characters for general text inputs.
  static final TextInputFormatter safeText = FilteringTextInputFormatter.deny(
    RegExp("[<>\"'\\x00-\\x1F]"),
  );
  
  /// A strictly allowed alphanumeric formatter.
  static final TextInputFormatter alphanumeric = FilteringTextInputFormatter.allow(
    RegExp(r"[a-zA-Z0-9\s]"),
  );
}
