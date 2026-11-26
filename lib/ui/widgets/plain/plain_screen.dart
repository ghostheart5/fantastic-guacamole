import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:flutter/material.dart';

/// Page frame modelled on Today: background, safe area and a scrollable body.
/// No back control unless [leading] is passed.
///
/// The page colour is Today's [AppColors.background] under the dark theme and
/// the theme's own page colour under the light theme, so text that follows the
/// theme stays readable in both.
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
    final ThemeData theme = Theme.of(context);
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
      backgroundColor: theme.brightness == Brightness.dark
          ? AppColors.background
          : theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: onRefresh == null
            ? list
            : RefreshIndicator(onRefresh: onRefresh!, child: list),
      ),
    );
  }
}
