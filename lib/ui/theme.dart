import 'package:flutter/material.dart';

/// Floodlit Night tokens. Menus, HUD and the Flame renderer all read from here.
abstract final class StrikerColors {
  static const ink = Color(0xff0a1226);
  static const surface = Color(0xff111d3a);
  static const raised = Color(0xff182848);
  static const outline = Color(0xff2a3d66);
  static const text = Color(0xfff4f1e8);
  static const muted = Color(0xffa8b3cc);
  static const faint = Color(0xff6b7898);
  static const gold = Color(0xffffb340);
  static const goldPressed = Color(0xffe69a26);
  static const goldSoft = Color(0x22ffb340);
  static const goldLine = Color(0x88ffb340);
  static const onGold = Color(0xff1a1200);
  static const grass = Color(0xff1f8a4c);
  static const grassStripe = Color(0xff23985a);
  static const pitchLine = Color(0xffe8f5e9);
  static const cyan = Color(0xff5fd4ff);
  static const cyanSoft = Color(0x445fd4ff);
  static const cyanLine = Color(0x665fd4ff);
  static const coral = Color(0xffff6b6b);
  static const coralSoft = Color(0x18ff6b6b);
  static const coralLine = Color(0x55ff6b6b);
  static const skin = Color(0xffd99c71);
  static const hair = Color(0xff24372d);
  static const defender = Color(0xffff686b);
  static const ball = Color(0xfff8faed);
  static const ballPatch = Color(0xff233e37);
  static const flood = Color(0xffd6f7ff);
  static const scrimTop = Color(0xf00a1226);
  static const scrimBottom = Color(0xc70a1226);

  static const inkValue = 0xff0a1226;
  static const goldValue = 0xffffb340;
  static const grassValue = 0xff1f8a4c;
  static const grassStripeValue = 0xff23985a;
  static const cyanValue = 0xff5fd4ff;
  static const coralValue = 0xffff6b6b;
  static const sweeperKit = 0xffffd166;
}

abstract final class StrikerFonts {
  static const display = 'BarlowCondensed';
  static const body = 'Barlow';
}

abstract final class StrikerSpace {
  static const edge = 16.0;
  static const group = 12.0;
  static const action = 8.0;
  static const radius = 16.0;
  static const buttonRadius = 14.0;
  static const chipRadius = 12.0;
  static const primaryHeight = 56.0;
  static const touch = 48.0;
}

abstract final class StrikerText {
  static const eyebrow = TextStyle(
    fontFamily: StrikerFonts.display,
    color: StrikerColors.gold,
    fontSize: 11,
    height: 1.2,
    letterSpacing: 2,
    fontWeight: FontWeight.w700,
  );

  static const caption = TextStyle(
    fontFamily: StrikerFonts.body,
    color: StrikerColors.muted,
    fontSize: 12,
    height: 1.4,
    fontWeight: FontWeight.w500,
  );

  static const body = TextStyle(
    fontFamily: StrikerFonts.body,
    color: StrikerColors.muted,
    fontSize: 14,
    height: 1.5,
    fontWeight: FontWeight.w400,
  );

  static const button = TextStyle(
    fontFamily: StrikerFonts.display,
    fontSize: 16,
    height: 1.1,
    letterSpacing: 1,
    fontWeight: FontWeight.w700,
  );

  static const title = TextStyle(
    fontFamily: StrikerFonts.display,
    color: StrikerColors.text,
    fontSize: 24,
    height: 1.1,
    fontWeight: FontWeight.w700,
  );

  static const headline = TextStyle(
    fontFamily: StrikerFonts.display,
    color: StrikerColors.text,
    fontSize: 34,
    height: 1.02,
    letterSpacing: -0.8,
    fontWeight: FontWeight.w900,
  );

  static const score = TextStyle(
    fontFamily: StrikerFonts.display,
    color: StrikerColors.text,
    fontSize: 72,
    height: 1.0,
    letterSpacing: -1.5,
    fontWeight: FontWeight.w900,
  );

  static const statLabel = TextStyle(
    fontFamily: StrikerFonts.display,
    color: StrikerColors.muted,
    fontSize: 10,
    letterSpacing: 1.8,
    fontWeight: FontWeight.w600,
  );

  static const statValue = TextStyle(
    fontFamily: StrikerFonts.display,
    color: StrikerColors.text,
    fontSize: 28,
    height: 1.1,
    fontWeight: FontWeight.w900,
  );
}

ButtonStyle _filled(Color background, Color foreground, {double height = 52}) =>
    ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return StrikerColors.raised;
        }
        if (states.contains(WidgetState.pressed)) return StrikerColors.goldPressed;
        return background;
      }),
      foregroundColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.disabled) ? StrikerColors.faint : foreground),
      minimumSize: WidgetStatePropertyAll(Size(StrikerSpace.touch, height)),
      padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 18, vertical: 14)),
      shape: WidgetStatePropertyAll(RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(StrikerSpace.buttonRadius))),
      elevation: const WidgetStatePropertyAll(0),
      textStyle: const WidgetStatePropertyAll(StrikerText.button),
    );

ThemeData strikerTheme() {
  final scheme = const ColorScheme.dark(
    primary: StrikerColors.gold,
    onPrimary: StrikerColors.onGold,
    surface: StrikerColors.ink,
    onSurface: StrikerColors.text,
    secondary: StrikerColors.cyan,
    onSecondary: StrikerColors.ink,
    error: StrikerColors.coral,
    outline: StrikerColors.outline,
  );
  return ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: StrikerColors.ink,
    fontFamily: StrikerFonts.body,
    textTheme: const TextTheme(
      bodyLarge: StrikerText.body,
      bodyMedium: StrikerText.body,
      bodySmall: StrikerText.caption,
      titleLarge: TextStyle(
        fontFamily: StrikerFonts.display,
        color: StrikerColors.text,
        fontSize: 22,
        height: 1.2,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: TextStyle(
        fontFamily: StrikerFonts.body,
        color: StrikerColors.text,
        fontSize: 16,
        height: 1.3,
        fontWeight: FontWeight.w600,
      ),
      titleSmall: TextStyle(
        fontFamily: StrikerFonts.body,
        color: StrikerColors.text,
        fontSize: 14,
        height: 1.3,
        fontWeight: FontWeight.w600,
      ),
      labelLarge: StrikerText.button,
      labelSmall: StrikerText.eyebrow,
    ),
    iconTheme: const IconThemeData(color: StrikerColors.muted, size: 22),
    dividerColor: StrikerColors.outline,
    filledButtonTheme: FilledButtonThemeData(
        style: _filled(StrikerColors.gold, StrikerColors.onGold, height: 56)),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.disabled)
                ? StrikerColors.faint
                : StrikerColors.text),
        minimumSize: const WidgetStatePropertyAll(Size(StrikerSpace.touch, 48)),
        padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
        side: WidgetStateProperty.resolveWith((states) => BorderSide(
            color: states.contains(WidgetState.disabled)
                ? StrikerColors.outline.withValues(alpha: .5)
                : StrikerColors.outline)),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(StrikerSpace.buttonRadius))),
        textStyle: const WidgetStatePropertyAll(StrikerText.button),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.disabled)
                ? StrikerColors.faint
                : StrikerColors.gold),
        minimumSize: const WidgetStatePropertyAll(Size(StrikerSpace.touch, 44)),
        textStyle: const WidgetStatePropertyAll(StrikerText.button),
      ),
    ),
    cardTheme: CardThemeData(
      color: StrikerColors.raised,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(StrikerSpace.radius),
        side: const BorderSide(color: StrikerColors.outline),
      ),
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: StrikerColors.gold,
      textColor: StrikerColors.text,
      subtitleTextStyle: StrikerText.caption,
    ),
    expansionTileTheme: const ExpansionTileThemeData(
      iconColor: StrikerColors.gold,
      collapsedIconColor: StrikerColors.muted,
      textColor: StrikerColors.text,
      collapsedTextColor: StrikerColors.text,
      backgroundColor: Colors.transparent,
      collapsedBackgroundColor: Colors.transparent,
      tilePadding: EdgeInsets.symmetric(horizontal: 4),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected)
              ? StrikerColors.onGold
              : StrikerColors.muted),
      trackColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected)
              ? StrikerColors.gold
              : StrikerColors.outline),
    ),
    dividerTheme: const DividerThemeData(color: StrikerColors.outline, space: 16),
    tooltipTheme: const TooltipThemeData(
      decoration: BoxDecoration(
        color: StrikerColors.raised,
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
      textStyle: TextStyle(color: StrikerColors.text, fontSize: 12),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: StrikerColors.raised,
      contentTextStyle: StrikerText.body,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: StrikerColors.gold,
      linearTrackColor: StrikerColors.outline,
    ),
  );
}

Duration strikerMotion(BuildContext context, [Duration fallback = const Duration(milliseconds: 220)]) {
  if (MediaQuery.of(context).disableAnimations) return Duration.zero;
  // Widget tests keep outgoing AnimatedSwitcher children, which breaks unique text finds.
  if (WidgetsBinding.instance.runtimeType.toString().contains('Test')) return Duration.zero;
  return fallback;
}
