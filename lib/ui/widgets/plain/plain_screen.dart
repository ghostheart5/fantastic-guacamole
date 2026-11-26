import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:fantastic_guacamole/ui/widgets/plain/plain_palette.dart';
import 'package:flutter/material.dart';

/// Page frame modelled on Today: background, safe area and a scrollable body.
/// No back control unless [leading] is passed.
///
/// The page is Today's [AppColors.background] under both themes (Today, My plan
/// and Settings are dark pages under the light theme too). The screen supplies
/// the light-on-dark [PlainPalette.page] colours to everything on it, and a
/// [PlainCard] switches to the theme's card colours inside the card.
class PlainScreen extends StatelessWidget {
  const PlainScreen({
    required this.children,
    this.leading,
    this.onRefresh,
    this.controller,
    this.listKey,
    super.key,
  });

  final List<Widget> children;

  /// Optional control (such as a back button) shown above the content.
  final Widget? leading;

  /// When set, the body supports pull to refresh.
  final Future<void> Function()? onRefresh;

  /// Scroll controller for the body, for screens that restore or read scroll.
  final ScrollController? controller;

  /// Key for the scrolling list (for example a PageStorageKey).
  final Key? listKey;

  static const EdgeInsets padding = EdgeInsets.fromLTRB(20, 16, 20, 28);

  @override
  Widget build(BuildContext context) {
    final Widget list = ListView(
      key: listKey,
      controller: controller,
      physics: onRefresh == null ? null : const AlwaysScrollableScrollPhysics(),
      padding: padding,
      children: <Widget>[
        if (leading != null)
          Align(alignment: AlignmentDirectional.centerStart, child: leading),
        ...children,
      ],
    );
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: PlainPaletteScope(
          palette: PlainPalette.page,
          child: onRefresh == null
              ? list
              : RefreshIndicator(onRefresh: onRefresh!, child: list),
        ),
      ),
    );
  }
}
