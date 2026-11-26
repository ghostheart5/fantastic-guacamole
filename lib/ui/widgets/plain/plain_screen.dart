import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:flutter/material.dart';

/// Page frame modelled on Today: dark background, safe area and a scrollable
/// body. No back control unless [leading] is passed.
class PlainScreen extends StatelessWidget {
  const PlainScreen({
    required this.children,
    this.leading,
    this.onRefresh,
    super.key,
  });

  final List<Widget> children;

  /// Optional control (such as a back button) shown above the content.
  final Widget? leading;

  /// When set, the body supports pull to refresh.
  final Future<void> Function()? onRefresh;

  static const EdgeInsets padding = EdgeInsets.fromLTRB(20, 16, 20, 28);

  @override
  Widget build(BuildContext context) {
    final Widget list = ListView(
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
        child: onRefresh == null
            ? list
            : RefreshIndicator(onRefresh: onRefresh!, child: list),
      ),
    );
  }
}
