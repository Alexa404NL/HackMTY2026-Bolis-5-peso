import 'package:flutter/material.dart';

/// Tokens de `reference ui/banorte.css`.
abstract final class BanorteColors {
  static const red = Color(0xFFEB0029);
  static const gray = Color(0xFF5B6670);
  static const white = Color(0xFFFFFFFF);
  static const darkGray = Color(0xFF323E48);
  static const content2 = Color(0xFF7B868C);
  static const content3 = Color(0xFFA2A9AD);
  static const content4 = Color(0xFFC1C5C8);
  static const content5 = Color(0xFFCFD2D3);
  static const background = Color(0xFFEBF0F2);
  static const background2 = Color(0xFFF4F7F8);
  static const background3 = Color(0xFFFCFCFC);
  static const success = Color(0xFF6CC04A);
  static const alert = Color(0xFFFF671B);
  static const warning = Color(0xFFFFA400);
}

const gotham = 'Gotham';

ThemeData banorteTheme() {
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: 'Roboto',
    scaffoldBackgroundColor: BanorteColors.background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: BanorteColors.red,
      primary: BanorteColors.red,
      surface: BanorteColors.white,
      onSurface: BanorteColors.darkGray,
    ),
  );
  TextStyle g(double size, FontWeight weight) => TextStyle(
        fontFamily: gotham,
        fontSize: size,
        fontWeight: weight,
        color: BanorteColors.darkGray,
        height: 1.05,
        letterSpacing: -0.5,
      );
  return base.copyWith(
    textTheme: base.textTheme.copyWith(
      displaySmall: g(44, FontWeight.w700),
      headlineMedium: g(28, FontWeight.w700),
      titleMedium: g(16, FontWeight.w500),
      bodyMedium: const TextStyle(fontSize: 15, color: BanorteColors.gray, height: 1.4),
      bodySmall: const TextStyle(fontSize: 13, color: BanorteColors.content2),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: BanorteColors.red,
        foregroundColor: BanorteColors.white,
        minimumSize: const Size.fromHeight(56),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontFamily: gotham, fontSize: 16, fontWeight: FontWeight.w500),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: BanorteColors.darkGray,
        minimumSize: const Size.fromHeight(56),
        shape: const StadiumBorder(),
        side: const BorderSide(color: BanorteColors.content4),
        textStyle: const TextStyle(fontFamily: gotham, fontSize: 16, fontWeight: FontWeight.w500),
      ),
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: BanorteColors.red,
      thumbColor: BanorteColors.red,
      inactiveTrackColor: BanorteColors.content5,
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: UnderlineInputBorder(borderSide: BorderSide(color: BanorteColors.darkGray)),
      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: BanorteColors.darkGray)),
      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: BanorteColors.red, width: 2)),
      hintStyle: TextStyle(color: BanorteColors.content3),
    ),
  );
}
