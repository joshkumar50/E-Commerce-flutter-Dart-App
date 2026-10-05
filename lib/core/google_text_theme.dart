import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Applies a Google Font to every role of an SDK [TextTheme].
///
/// `GoogleFonts.*TextTheme()` returns `material_ui.TextTheme`, which is not
/// assignable to `ThemeData.textTheme` from `package:flutter/material.dart`.
/// [TextStyle] is shared across both libraries, so applying the font per role
/// avoids the type clash.
TextTheme withGoogleFont(
  TextTheme base,
  TextStyle Function({TextStyle? textStyle}) font,
) {
  TextStyle? apply(TextStyle? style) =>
      style == null ? null : font(textStyle: style);

  return base.copyWith(
    displayLarge: apply(base.displayLarge),
    displayMedium: apply(base.displayMedium),
    displaySmall: apply(base.displaySmall),
    headlineLarge: apply(base.headlineLarge),
    headlineMedium: apply(base.headlineMedium),
    headlineSmall: apply(base.headlineSmall),
    titleLarge: apply(base.titleLarge),
    titleMedium: apply(base.titleMedium),
    titleSmall: apply(base.titleSmall),
    bodyLarge: apply(base.bodyLarge),
    bodyMedium: apply(base.bodyMedium),
    bodySmall: apply(base.bodySmall),
    labelLarge: apply(base.labelLarge),
    labelMedium: apply(base.labelMedium),
    labelSmall: apply(base.labelSmall),
  );
}

/// Inter text theme built from the SDK light baseline.
TextTheme interTextTheme([TextTheme? base]) {
  return withGoogleFont(base ?? ThemeData.light().textTheme, GoogleFonts.inter);
}
