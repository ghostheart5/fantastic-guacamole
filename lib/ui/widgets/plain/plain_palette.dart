import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:flutter/material.dart';

/// The colours the plain widgets use, resolved for the surface they sit on.
///
/// [PlainScreen] supplies the page palette (light on Today's dark page, in both
/// themes) and [PlainCard] supplies the card palette (the theme's on-surface
/// colours on the theme's card colour). A widget asks [PlainPalette.of] and so
/// gets the right colours wherever it is placed. Without either ancestor the
/// card palette is used.
@immutable
class PlainPalette {
  const PlainPalette({
    required this.primary,
    required this.secondary,
    required this.line,
    required this.accent,
    required this.fill,
    required this.selectedFill,
  });

  /// Titles, values and other main text and icons.
  final Color primary;

  /// Labels, captions and descriptions: visibly lighter than [primary].
  final Color secondary;

  /// Faint outline for unselected controls.
  final Color line;

  /// Outline and highlight for selected controls and cards.
  final Color accent;

  /// Resting fill of controls (opaque).
  final Color fill;

  /// Fill of selected controls (opaque).
  final Color selectedFill;

  static PlainPalette _from(Color on, Color base, Color accent) {
    return PlainPalette(
      primary: on,
      secondary: Color.alphaBlend(on.withValues(alpha: 0.72), base),
      line: Color.alphaBlend(on.withValues(alpha: 0.28), base),
      accent: accent,
      fill: Color.alphaBlend(on.withValues(alpha: 0.06), base),
      selectedFill: Color.alphaBlend(accent.withValues(alpha: 0.28), base),
    );
  }

  /// Light-on-dark colours for the dark page.
  static final PlainPalette page = _from(
    Colors.white,
    AppColors.background,
    AppColors.primary,
  );

  /// The theme's on-surface colours on its card colour.
  static PlainPalette card(ThemeData theme) {
    final Color cardColor = Color.alphaBlend(
      theme.cardTheme.color ?? theme.colorScheme.surface,
      AppColors.background,
    );
    return _from(
      theme.colorScheme.onSurface,
      cardColor,
      theme.colorScheme.primary,
    );
  }

  static PlainPalette of(BuildContext context) {
    final _PlainPaletteScope? scope = context
        .dependOnInheritedWidgetOfExactType<_PlainPaletteScope>();
    return scope?.palette ?? card(Theme.of(context));
  }

  @override
  bool operator ==(Object other) =>
      other is PlainPalette &&
      other.primary == primary &&
      other.secondary == secondary &&
      other.line == line &&
      other.accent == accent &&
      other.fill == fill &&
      other.selectedFill == selectedFill;

  @override
  int get hashCode =>
      Object.hash(primary, secondary, line, accent, fill, selectedFill);
}

/// Provides [palette] to everything below it, including plain default text
/// and icon colours.
class PlainPaletteScope extends StatelessWidget {
  const PlainPaletteScope({
    required this.palette,
    required this.child,
    super.key,
  });

  final PlainPalette palette;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return _PlainPaletteScope(
      palette: palette,
      child: DefaultTextStyle.merge(
        style: TextStyle(color: palette.primary),
        child: IconTheme.merge(
          data: IconThemeData(color: palette.primary),
          child: child,
        ),
      ),
    );
  }
}

class _PlainPaletteScope extends InheritedWidget {
  const _PlainPaletteScope({required this.palette, required super.child});

  final PlainPalette palette;

  @override
  bool updateShouldNotify(_PlainPaletteScope oldWidget) =>
      palette != oldWidget.palette;
}
