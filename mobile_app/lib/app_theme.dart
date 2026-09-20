import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

abstract final class PinpinsColors {
  static const leaf = Color(0xFF66734A);
  static const deepLeaf = Color(0xFF354327);
  static const cream = Color(0xFFF5EDDC);
  static const toastedCream = Color(0xFFEAD8B8);
  static const gold = Color(0xFFD59B2D);
  static const brown = Color(0xFF5A3826);
  static const ink = Color(0xFF3D3028);
  static const paper = Color(0xFFFFFDF7);
  static const border = Color(0x2E4A2F1F);
}

ThemeData pinpinsTheme() {
  const sans = 'PinpinsSans';
  const serif = 'PinpinsSerif';
  const heading = TextStyle(
    fontFamily: serif,
    color: PinpinsColors.brown,
    fontWeight: FontWeight.w900,
    height: 1.08,
    letterSpacing: -0.5,
  );
  const body = TextStyle(
    fontFamily: sans,
    color: PinpinsColors.ink,
    height: 1.5,
  );
  const scheme = ColorScheme.light(
    primary: PinpinsColors.brown,
    onPrimary: PinpinsColors.paper,
    secondary: PinpinsColors.gold,
    onSecondary: PinpinsColors.ink,
    surface: PinpinsColors.paper,
    onSurface: PinpinsColors.ink,
    error: PinpinsColors.brown,
    onError: PinpinsColors.paper,
    outline: PinpinsColors.border,
    shadow: Color(0x244A2F1F),
  );
  final fieldBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: const BorderSide(color: PinpinsColors.border, width: 2),
  );
  final textTheme = TextTheme(
    displayLarge: heading.copyWith(fontSize: 48),
    displayMedium: heading.copyWith(fontSize: 40),
    displaySmall: heading.copyWith(fontSize: 34),
    headlineLarge: heading.copyWith(fontSize: 32),
    headlineMedium: heading.copyWith(fontSize: 28),
    headlineSmall: heading.copyWith(fontSize: 24),
    titleLarge: heading.copyWith(fontSize: 21),
    titleMedium: body.copyWith(
      color: PinpinsColors.brown,
      fontSize: 16,
      fontWeight: FontWeight.w900,
      height: 1.25,
    ),
    titleSmall: body.copyWith(
      color: PinpinsColors.deepLeaf,
      fontSize: 14,
      fontWeight: FontWeight.w700,
      height: 1.25,
    ),
    bodyLarge: body.copyWith(fontSize: 17),
    bodyMedium: body.copyWith(fontSize: 15),
    bodySmall: body.copyWith(fontSize: 13),
    labelLarge: body.copyWith(
      color: PinpinsColors.brown,
      fontSize: 14,
      fontWeight: FontWeight.w900,
      height: 1.1,
    ),
    labelMedium: body.copyWith(
      color: PinpinsColors.deepLeaf,
      fontSize: 12,
      fontWeight: FontWeight.w900,
      letterSpacing: .4,
      height: 1.1,
    ),
    labelSmall: body.copyWith(
      color: PinpinsColors.deepLeaf,
      fontSize: 11,
      fontWeight: FontWeight.w700,
      height: 1.1,
    ),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: sans,
    textTheme: textTheme,
    primaryTextTheme: textTheme,
    scaffoldBackgroundColor: PinpinsColors.cream,
    canvasColor: PinpinsColors.cream,
    splashColor: PinpinsColors.leaf.withValues(alpha: .12),
    highlightColor: PinpinsColors.gold.withValues(alpha: .1),
    focusColor: PinpinsColors.leaf.withValues(alpha: .18),
    hoverColor: PinpinsColors.leaf.withValues(alpha: .08),
    dividerTheme: const DividerThemeData(
      color: PinpinsColors.border,
      thickness: 1,
      space: 24,
    ),
    iconTheme: const IconThemeData(color: PinpinsColors.deepLeaf),
    appBarTheme: AppBarTheme(
      backgroundColor: PinpinsColors.cream,
      foregroundColor: PinpinsColors.brown,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: heading.copyWith(fontSize: 20),
      toolbarTextStyle: body.copyWith(fontWeight: FontWeight.w700),
      iconTheme: const IconThemeData(color: PinpinsColors.deepLeaf),
      actionsIconTheme: const IconThemeData(color: PinpinsColors.deepLeaf),
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: PinpinsColors.paper,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    ),
    cardTheme: CardThemeData(
      color: PinpinsColors.paper,
      surfaceTintColor: Colors.transparent,
      elevation: 3,
      shadowColor: scheme.shadow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: PinpinsColors.border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: PinpinsColors.paper,
      labelStyle: textTheme.labelLarge,
      hintStyle: body.copyWith(color: PinpinsColors.ink.withValues(alpha: .62)),
      errorStyle: body.copyWith(
        color: PinpinsColors.brown,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
      border: fieldBorder,
      enabledBorder: fieldBorder,
      focusedBorder: fieldBorder.copyWith(
        borderSide: const BorderSide(color: PinpinsColors.deepLeaf, width: 2),
      ),
      errorBorder: fieldBorder.copyWith(
        borderSide: const BorderSide(color: PinpinsColors.brown, width: 2),
      ),
      focusedErrorBorder: fieldBorder.copyWith(
        borderSide: const BorderSide(color: PinpinsColors.brown, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: PinpinsColors.brown,
        foregroundColor: PinpinsColors.paper,
        disabledBackgroundColor: PinpinsColors.border,
        disabledForegroundColor: PinpinsColors.ink.withValues(alpha: .5),
        minimumSize: const Size(48, 52),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: const StadiumBorder(),
        textStyle: textTheme.labelLarge,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: PinpinsColors.brown,
        foregroundColor: PinpinsColors.paper,
        elevation: 2,
        minimumSize: const Size(48, 52),
        shape: const StadiumBorder(),
        textStyle: textTheme.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: PinpinsColors.brown,
        minimumSize: const Size(48, 52),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        side: const BorderSide(color: PinpinsColors.brown, width: 2),
        shape: const StadiumBorder(),
        textStyle: textTheme.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: PinpinsColors.brown,
        minimumSize: const Size(48, 48),
        shape: const StadiumBorder(),
        textStyle: textTheme.labelLarge,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: PinpinsColors.deepLeaf,
        minimumSize: const Size(48, 48),
        shape: const CircleBorder(),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: PinpinsColors.paper,
      elevation: 8,
      height: 72,
      indicatorColor: PinpinsColors.leaf.withValues(alpha: .18),
      indicatorShape: const StadiumBorder(),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? PinpinsColors.deepLeaf
              : PinpinsColors.ink,
        ),
      ),
      labelTextStyle: WidgetStatePropertyAll(textTheme.labelMedium),
    ),
    searchBarTheme: SearchBarThemeData(
      backgroundColor: const WidgetStatePropertyAll(PinpinsColors.paper),
      surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      elevation: const WidgetStatePropertyAll(0),
      side: const WidgetStatePropertyAll(
        BorderSide(color: PinpinsColors.border, width: 2),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      textStyle: WidgetStatePropertyAll(textTheme.bodyMedium),
      hintStyle: WidgetStatePropertyAll(
        body.copyWith(color: PinpinsColors.ink.withValues(alpha: .62)),
      ),
      constraints: const BoxConstraints(minHeight: 52),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: PinpinsColors.paper,
      selectedColor: PinpinsColors.deepLeaf,
      disabledColor: PinpinsColors.border,
      side: const BorderSide(color: PinpinsColors.border),
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      labelStyle: textTheme.labelMedium,
      secondaryLabelStyle: textTheme.labelMedium?.copyWith(
        color: PinpinsColors.cream,
      ),
      iconTheme: const IconThemeData(color: PinpinsColors.deepLeaf, size: 18),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: PinpinsColors.paper,
      surfaceTintColor: Colors.transparent,
      elevation: 12,
      shadowColor: scheme.shadow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titleTextStyle: textTheme.headlineSmall,
      contentTextStyle: textTheme.bodyMedium,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: PinpinsColors.paper,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: PinpinsColors.paper,
      showDragHandle: true,
      dragHandleColor: PinpinsColors.leaf,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: PinpinsColors.paper,
      surfaceTintColor: Colors.transparent,
      headerBackgroundColor: PinpinsColors.deepLeaf,
      headerForegroundColor: PinpinsColors.cream,
      headerHeadlineStyle: heading.copyWith(
        color: PinpinsColors.cream,
        fontSize: 26,
      ),
      headerHelpStyle: textTheme.labelMedium?.copyWith(
        color: PinpinsColors.cream,
      ),
      weekdayStyle: textTheme.labelMedium,
      dayStyle: textTheme.bodyMedium,
      yearStyle: textTheme.bodyMedium,
      dayForegroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? PinpinsColors.cream
            : PinpinsColors.ink,
      ),
      dayBackgroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? PinpinsColors.deepLeaf
            : Colors.transparent,
      ),
      todayForegroundColor: const WidgetStatePropertyAll(PinpinsColors.brown),
      todayBorder: const BorderSide(color: PinpinsColors.gold, width: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      cancelButtonStyle: TextButton.styleFrom(
        foregroundColor: PinpinsColors.brown,
        textStyle: textTheme.labelLarge,
      ),
      confirmButtonStyle: TextButton.styleFrom(
        foregroundColor: PinpinsColors.deepLeaf,
        textStyle: textTheme.labelLarge,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: PinpinsColors.deepLeaf,
      actionTextColor: PinpinsColors.gold,
      disabledActionTextColor: PinpinsColors.cream.withValues(alpha: .5),
      contentTextStyle: body.copyWith(
        color: PinpinsColors.cream,
        fontWeight: FontWeight.w700,
      ),
      behavior: SnackBarBehavior.floating,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      insetPadding: const EdgeInsets.all(14),
      showCloseIcon: true,
      closeIconColor: PinpinsColors.cream,
    ),
    listTileTheme: ListTileThemeData(
      iconColor: PinpinsColors.deepLeaf,
      textColor: PinpinsColors.ink,
      titleTextStyle: textTheme.titleMedium,
      subtitleTextStyle: textTheme.bodySmall,
      minTileHeight: 56,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    expansionTileTheme: const ExpansionTileThemeData(
      iconColor: PinpinsColors.deepLeaf,
      collapsedIconColor: PinpinsColors.deepLeaf,
      textColor: PinpinsColors.brown,
      collapsedTextColor: PinpinsColors.brown,
      tilePadding: EdgeInsets.symmetric(horizontal: 14),
      childrenPadding: EdgeInsets.fromLTRB(14, 0, 14, 14),
      shape: Border(bottom: BorderSide(color: PinpinsColors.border)),
      collapsedShape: Border(bottom: BorderSide(color: PinpinsColors.border)),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: PinpinsColors.paper,
      surfaceTintColor: Colors.transparent,
      textStyle: textTheme.bodyMedium,
      labelTextStyle: WidgetStatePropertyAll(textTheme.bodyMedium),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 8,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: PinpinsColors.deepLeaf,
      linearTrackColor: PinpinsColors.toastedCream,
      circularTrackColor: PinpinsColors.toastedCream,
    ),
    badgeTheme: BadgeThemeData(
      backgroundColor: PinpinsColors.gold,
      textColor: PinpinsColors.ink,
      textStyle: textTheme.labelSmall,
      padding: const EdgeInsets.symmetric(horizontal: 6),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: PinpinsColors.deepLeaf,
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: textTheme.labelSmall?.copyWith(color: PinpinsColors.cream),
      waitDuration: const Duration(milliseconds: 500),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: PinpinsColors.deepLeaf,
      selectionColor: PinpinsColors.leaf.withValues(alpha: .28),
      selectionHandleColor: PinpinsColors.deepLeaf,
    ),
  );
}

class LeafMark extends StatelessWidget {
  const LeafMark({this.size = 34, super.key});
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Pinpins Kakanin',
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _LeafPainter()),
    ),
  );
}

class _LeafPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = PinpinsColors.deepLeaf;
    final path = Path()
      ..moveTo(size.width * .12, size.height * .78)
      ..quadraticBezierTo(
        size.width * .24,
        size.height * .08,
        size.width * .9,
        size.height * .12,
      )
      ..quadraticBezierTo(
        size.width * .82,
        size.height * .78,
        size.width * .12,
        size.height * .78,
      );
    canvas.drawPath(path, paint);
    canvas.drawLine(
      Offset(size.width * .16, size.height * .75),
      Offset(size.width * .78, size.height * .25),
      Paint()
        ..color = PinpinsColors.cream
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class PaperCard extends StatelessWidget {
  const PaperCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    super.key,
  });
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(padding: padding, child: child),
  );
}

class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {this.icon, super.key});
  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (icon != null) ...[
        Icon(icon, size: 16, color: PinpinsColors.deepLeaf),
        const SizedBox(width: 6),
      ] else ...[
        Container(width: 28, height: 2, color: PinpinsColors.gold),
        const SizedBox(width: 8),
      ],
      Flexible(
        child: Text(
          text.toUpperCase(),
          style: const TextStyle(
            color: PinpinsColors.deepLeaf,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.6,
          ),
        ),
      ),
    ],
  );
}

class StateSurface extends StatelessWidget {
  const StateSurface({
    required this.message,
    this.icon = Icons.info_outline,
    this.action,
    super.key,
  });
  final String message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: PaperCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: PinpinsColors.leaf),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 12), action!],
          ],
        ),
      ),
    ),
  );
}
