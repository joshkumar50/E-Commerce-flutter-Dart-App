import 'package:flutter/material.dart';
import 'package:opem/core/design_tokens.dart';

/// Modal motion, in one place.
///
/// Material exposes no theme-level animation style for dialogs or bottom
/// sheets in this SDK — the transition can only be supplied per call — and
/// neither surface honors the platform reduced-motion preference on its own.
/// [showAppDialog] and [showAppBottomSheet] therefore wrap the Material
/// functions and are the single source of modal motion for both apps; every
/// call site uses them, so modals stay on the same rhythm by construction.
///
/// The motion is transform/opacity based (that is what the default Material
/// transitions for both surfaces already are), and uses the app's token
/// curves: entrances decelerate ([AppMotion.decelerate]), exits accelerate
/// ([AppMotion.accelerate]). Durations differ between the two surfaces because
/// the framework does:
///
/// * Bottom sheets honor both directions, so they get the app's asymmetric
///   pair: entrance [AppMotion.normal], exit [AppMotion.fast].
/// * [DialogRoute] only reads `AnimationStyle.duration` and derives its
///   reverse transition from it (it overrides `reverseTransitionDuration`
///   nowhere), so dialogs use [AppMotion.fast] in both directions — the same
///   duration Flutter uses by default.
///
/// Under reduced motion ([appPrefersReducedMotion]) every duration collapses
/// to zero, so modals open and close instantly while all behavior (dismissal,
/// drag, returned result) is unchanged.
class AppModalMotion {
  AppModalMotion._();

  /// Bottom-sheet entrance duration (entrances decelerate).
  static const Duration sheetEnter = AppMotion.normal;

  /// Bottom-sheet exit duration (exits accelerate, quicker than entrances).
  static const Duration sheetExit = AppMotion.fast;

  /// Dialog duration for both directions — see the class docs for why dialogs
  /// cannot be asymmetric.
  static const Duration dialogDuration = AppMotion.fast;

  static const AnimationStyle _instant = AnimationStyle(
    duration: Duration.zero,
    reverseDuration: Duration.zero,
    curve: AppMotion.decelerate,
    reverseCurve: AppMotion.accelerate,
  );

  /// Motion style for bottom sheets, resolved for the current context.
  static AnimationStyle bottomSheetStyle(BuildContext context) =>
      appPrefersReducedMotion(context)
          ? _instant
          : const AnimationStyle(
              duration: sheetEnter,
              reverseDuration: sheetExit,
              curve: AppMotion.decelerate,
              reverseCurve: AppMotion.accelerate,
            );

  /// Motion style for dialogs, resolved for the current context.
  static AnimationStyle dialogStyle(BuildContext context) =>
      appPrefersReducedMotion(context)
          ? _instant
          : const AnimationStyle(
              duration: dialogDuration,
              reverseDuration: dialogDuration,
              curve: AppMotion.decelerate,
              reverseCurve: AppMotion.accelerate,
            );
}

/// [showDialog] with the app's modal motion. Behavior is otherwise identical:
/// the same barrier/dismissal semantics and the same returned result.
Future<T?> showAppDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color? barrierColor,
  String? barrierLabel,
  bool useSafeArea = true,
  bool useRootNavigator = true,
  RouteSettings? routeSettings,
  Offset? anchorPoint,
  TraversalEdgeBehavior? traversalEdgeBehavior,
  bool fullscreenDialog = false,
  bool? requestFocus,
}) {
  return showDialog<T>(
    context: context,
    builder: builder,
    barrierDismissible: barrierDismissible,
    barrierColor: barrierColor,
    barrierLabel: barrierLabel,
    useSafeArea: useSafeArea,
    useRootNavigator: useRootNavigator,
    routeSettings: routeSettings,
    anchorPoint: anchorPoint,
    traversalEdgeBehavior: traversalEdgeBehavior,
    fullscreenDialog: fullscreenDialog,
    requestFocus: requestFocus,
    animationStyle: AppModalMotion.dialogStyle(context),
  );
}

/// [showModalBottomSheet] with the app's modal motion. Behavior is otherwise
/// identical: the same dismissal/drag semantics and the same returned result.
Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  Color? backgroundColor,
  String? barrierLabel,
  double? elevation,
  ShapeBorder? shape,
  Clip? clipBehavior,
  BoxConstraints? constraints,
  Color? barrierColor,
  bool isScrollControlled = false,
  double scrollControlDisabledMaxHeightRatio = 9.0 / 16.0,
  bool useRootNavigator = false,
  bool isDismissible = true,
  bool enableDrag = true,
  bool? showDragHandle,
  bool useSafeArea = false,
  RouteSettings? routeSettings,
  AnimationController? transitionAnimationController,
  Offset? anchorPoint,
  bool? requestFocus,
}) {
  return showModalBottomSheet<T>(
    context: context,
    builder: builder,
    backgroundColor: backgroundColor,
    barrierLabel: barrierLabel,
    elevation: elevation,
    shape: shape,
    clipBehavior: clipBehavior,
    constraints: constraints,
    barrierColor: barrierColor,
    isScrollControlled: isScrollControlled,
    scrollControlDisabledMaxHeightRatio: scrollControlDisabledMaxHeightRatio,
    useRootNavigator: useRootNavigator,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    showDragHandle: showDragHandle,
    useSafeArea: useSafeArea,
    routeSettings: routeSettings,
    transitionAnimationController: transitionAnimationController,
    anchorPoint: anchorPoint,
    requestFocus: requestFocus,
    sheetAnimationStyle: AppModalMotion.bottomSheetStyle(context),
  );
}
