import 'package:material_ui/material_ui.dart';

abstract final class PaperLantern {
  static const paper = Color(0xFFF6F0E4);
  static const ink = Color(0xFF24241E);
  static const muted = Color(0xFF655E54);
  static const red = Color(0xFF963728);
  static const rule = Color(0xFFC9BEAC);
  static const wash = Color(0xFFE9E0D0);
  static const serif = 'Baskervville';

  static const folio = TextStyle(
    fontFamily: 'monospace',
    fontFamilyFallback: ['Consolas', 'Menlo'],
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.9,
    color: muted,
  );

  static ThemeData get theme {
    final scheme = ColorScheme.fromSeed(seedColor: red).copyWith(
      primary: red,
      onPrimary: paper,
      primaryContainer: const Color(0xFFF0D9CD),
      onPrimaryContainer: const Color(0xFF62291E),
      secondary: muted,
      onSecondary: paper,
      secondaryContainer: wash,
      onSecondaryContainer: ink,
      tertiary: const Color(0xFF5D674F),
      tertiaryContainer: const Color(0xFFDFE3D2),
      onTertiaryContainer: const Color(0xFF353E2B),
      surface: paper,
      onSurface: ink,
      onSurfaceVariant: muted,
      surfaceContainerLowest: paper,
      surfaceContainerLow: const Color(0xFFF2EBDD),
      surfaceContainer: const Color(0xFFEFE7D8),
      surfaceContainerHigh: wash,
      surfaceContainerHighest: const Color(0xFFE1D7C6),
      outline: muted,
      outlineVariant: rule,
      surfaceTint: Colors.transparent,
      error: const Color(0xFF952923),
      inverseSurface: ink,
      onInverseSurface: paper,
      inversePrimary: const Color(0xFFF4AE97),
    );
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    final text = base.textTheme.apply(bodyColor: ink, displayColor: ink);
    TextStyle? headline(TextStyle? style) => style?.copyWith(
      fontFamily: serif,
      letterSpacing: -0.6,
      fontWeight: FontWeight.w600,
    );
    final type = text.copyWith(
      displayLarge: headline(text.displayLarge),
      displayMedium: headline(text.displayMedium),
      displaySmall: headline(text.displaySmall),
      headlineLarge: headline(text.headlineLarge),
      headlineMedium: headline(text.headlineMedium),
      headlineSmall: headline(text.headlineSmall),
      titleLarge: headline(text.titleLarge),
    );
    const shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(3)),
    );
    return base.copyWith(
      scaffoldBackgroundColor: paper,
      textTheme: type,
      dividerTheme: const DividerThemeData(color: rule, thickness: 1, space: 1),
      appBarTheme: AppBarThemeData(
        backgroundColor: paper,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: type.headlineMedium,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: paper,
        selectedItemColor: red,
        unselectedItemColor: muted,
        elevation: 0,
        selectedLabelStyle: TextStyle(fontWeight: FontWeight.w700),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(shape: shape),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: red,
          foregroundColor: paper,
          elevation: 0,
          shape: shape,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: shape,
          foregroundColor: ink,
          side: const BorderSide(color: muted),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(shape: shape),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: paper,
        shape: shape,
        titleTextStyle: type.headlineSmall,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: paper,
        modalBackgroundColor: paper,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        ),
      ),
      cardTheme: const CardThemeData(
        color: paper,
        elevation: 0,
        shape: RoundedRectangleBorder(side: BorderSide(color: rule)),
      ),
      inputDecorationTheme: const InputDecorationThemeData(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(3)),
          borderSide: BorderSide(color: rule),
        ),
      ),
      badgeTheme: const BadgeThemeData(backgroundColor: red, textColor: paper),
    );
  }
}

class PaperSectionHeading extends StatelessWidget {
  const PaperSectionHeading(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: PaperLantern.ink)),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: PaperLantern.ink,
                    fontFamily: PaperLantern.serif,
                    fontSize: 23,
                    fontWeight: FontWeight.w600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          ],
        ),
      ),
    );
  }
}
