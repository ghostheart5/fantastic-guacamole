import 'package:flutter/material.dart';

/// Reserves space for a startup notice instead of covering routed controls.
/// Dismissal hides only the notice, not the underlying startup failure/gates.
class StartupNoticeLayout extends StatefulWidget {
  const StartupNoticeLayout({
    super.key,
    required this.message,
    required this.child,
  });

  final String message;
  final Widget child;

  @override
  State<StartupNoticeLayout> createState() => _StartupNoticeLayoutState();
}

class _StartupNoticeLayoutState extends State<StartupNoticeLayout> {
  bool _dismissed = false;

  @override
  void didUpdateWidget(StartupNoticeLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.message != oldWidget.message) {
      _dismissed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool visible = !_dismissed && widget.message.trim().isNotEmpty;
    // Keep the routed child's element position stable when the notice closes.
    return LayoutBuilder(
      builder: (context, constraints) => Column(
        children: <Widget>[
          Expanded(child: widget.child),
          if (visible)
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: constraints.maxHeight * 0.3,
              ),
              child: Material(
                color: Theme.of(context).colorScheme.errorContainer,
                child: SafeArea(
                  top: false,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(12),
                          child: Semantics(
                            liveRegion: true,
                            child: Text(
                              widget.message,
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onErrorContainer,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        key: const Key('dismiss-startup-notice'),
                        tooltip: MaterialLocalizations.of(
                          context,
                        ).closeButtonTooltip,
                        color: Theme.of(context).colorScheme.onErrorContainer,
                        onPressed: () => setState(() => _dismissed = true),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
