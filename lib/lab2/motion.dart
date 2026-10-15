import 'dart:async';
import 'package:flutter/material.dart';

bool campusReduceMotion(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context) ||
    MediaQuery.accessibleNavigationOf(context);

/// Animates the current child only. Replaced data leaves the tree immediately.
/// A trigger change preserves the child's State, focus and scroll controllers.
class CampusEntrance extends StatefulWidget {
  final Object? trigger;
  final Widget child;
  const CampusEntrance({super.key, this.trigger, required this.child});

  @override
  State<CampusEntrance> createState() => _CampusEntranceState();
}

class _CampusEntranceState extends State<CampusEntrance>
    with SingleTickerProviderStateMixin {
  late final controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  );
  late final opacity = CurvedAnimation(
    parent: controller,
    curve: Curves.easeOut,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (campusReduceMotion(context)) {
      controller.value = 1;
    } else if (!controller.isCompleted && !controller.isAnimating) {
      controller.forward();
    }
  }

  @override
  void didUpdateWidget(CampusEntrance oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trigger != widget.trigger) {
      if (campusReduceMotion(context)) {
        controller.value = 1;
      } else {
        controller.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    opacity.dispose();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: opacity,
    alwaysIncludeSemantics: true,
    child: widget.child,
  );
}

class CampusSize extends StatelessWidget {
  final Widget child;
  const CampusSize({super.key, required this.child});
  @override
  Widget build(BuildContext context) => AnimatedSize(
    duration: campusReduceMotion(context)
        ? Duration.zero
        : const Duration(milliseconds: 220),
    curve: Curves.easeOutCubic,
    alignment: Alignment.topCenter,
    child: child,
  );
}

/// Highlights a confirmed data change, without animating ordinary poll results.
class CampusChangeHighlight extends StatefulWidget {
  final Object value;
  final Widget child;
  const CampusChangeHighlight({
    super.key,
    required this.value,
    required this.child,
  });
  @override
  State<CampusChangeHighlight> createState() => _CampusChangeHighlightState();
}

class _CampusChangeHighlightState extends State<CampusChangeHighlight> {
  Timer? timer;
  bool highlighted = false;
  @override
  void didUpdateWidget(CampusChangeHighlight oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      timer?.cancel();
      highlighted = true;
      timer = Timer(const Duration(milliseconds: 900), () {
        if (mounted) setState(() => highlighted = false);
      });
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: campusReduceMotion(context)
        ? Duration.zero
        : const Duration(milliseconds: 220),
    decoration: BoxDecoration(
      color: highlighted
          ? Theme.of(context).colorScheme.primaryContainer
          : Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(12),
    ),
    child: widget.child,
  );
}

class CampusPageTransitions extends PageTransitionsBuilder {
  const CampusPageTransitions();
  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (campusReduceMotion(context)) return child;
    return FadeTransition(
      opacity: animation.drive(CurveTween(curve: Curves.easeOut)),
      child: child,
    );
  }
}
