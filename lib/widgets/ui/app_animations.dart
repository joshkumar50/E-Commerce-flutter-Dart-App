import 'package:flutter/material.dart';
import 'package:opem/core/design_tokens.dart';

/// Session-level record of which entrances have already played.
///
/// [SliverGrid]/[GridView] lazily dispose children scrolled off-screen and
/// inflate fresh elements when they return. If the played-state lived inside
/// the item's State it would die with the element and the entrance would
/// replay on every scroll-back; owning the record here — outside the
/// disposable item widget — makes each item's entrance play exactly once per
/// app session.
///
/// Items are identified by `(scope, index)`: [StaggeredEntrance.scope]
/// namespaces each surface, so e.g. the home grid and search results never
/// collide. Call [reset] from tests only.
class AppEntranceRegistry {
  AppEntranceRegistry._();

  static final Set<(String, int)> _played = <(String, int)>{};

  static bool hasPlayed(String scope, int index) =>
      _played.contains((scope, index));

  static void markPlayed(String scope, int index) =>
      _played.add((scope, index));

  /// Test-only: clears all recorded entrances.
  static void reset() => _played.clear();
}

/// Fades and rises [child] into place the first time it appears — the modern
/// "content entrance" pattern used across lists, grids and section headers.
///
/// - Plays exactly once per `(scope, index)` per session: when a lazily
///   rebuilt grid item comes back after scrolling, it renders settled instead
///   of replaying (played-state lives in [AppEntranceRegistry], outside this
///   disposable widget).
/// - Staggered by list position (capped by [AppMotion.staggerWindow]) so
///   first screens settle in a wave; later items animate immediately.
/// - Runs on a single ticker, transform/opacity only.
/// - Honors the platform reduced-motion preference (fade only, no rise).
class StaggeredEntrance extends StatefulWidget {
  final Widget child;
  final int index;

  /// Namespace of the owning surface (e.g. 'home-products'). Entrances are
  /// recorded per `(scope, index)` so surfaces animate independently.
  final String scope;

  const StaggeredEntrance({
    super.key,
    required this.child,
    required this.index,
    required this.scope,
  });

  @override
  State<StaggeredEntrance> createState() => _StaggeredEntranceState();
}

class _StaggeredEntranceState extends State<StaggeredEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _rise;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppMotion.slow,
      value: 0,
    );

    // Only the first batch of items gets the staggered wave; later items
    // (scrolled into view) animate immediately so they never lag behind.
    final int step = widget.index < AppMotion.staggerWindow ? widget.index : 0;
    final Duration delay = AppMotion.staggerStep * step;

    final CurvedAnimation curved = CurvedAnimation(
      parent: _controller,
      curve: Interval(
        delay.inMilliseconds / AppMotion.slow.inMilliseconds,
        1.0,
        curve: AppMotion.decelerate,
      ),
    );

    _fade = curved;
    _rise = Tween<double>(begin: AppMotion.riseOffset, end: 0).animate(curved);

    if (AppEntranceRegistry.hasPlayed(widget.scope, widget.index)) {
      // This item already entered once this session (e.g. a lazily rebuilt
      // grid cell scrolled back into view): render settled, never replay.
      _controller.value = 1;
      return;
    }
    AppEntranceRegistry.markPlayed(widget.scope, widget.index);

    if (delay == Duration.zero) {
      _controller.forward();
    } else {
      Future<void>.delayed(delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool reducedMotion = appPrefersReducedMotion(context);

    if (reducedMotion) {
      return FadeTransition(opacity: _controller, child: widget.child);
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _fade.value,
          child: Transform.translate(
            offset: Offset(0, _rise.value),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// Cross-fades between the pages of ONE persistent child set.
///
/// Replaces the old AnimatedSwitcher-per-index approach, which mounted a
/// fresh subtree for every switch and disposed the previous one — resetting
/// scroll positions and re-running every initState/stream subscription.
/// Here each child lives in its own permanently-mounted [_TabLayer]; the
/// wrapper structure never changes shape across frames, so elements are only
/// ever updated in place, never re-inflated.
///
/// Settled behavior matches [IndexedStack] (with its defaults) on every axis:
/// * children stay mounted and laid out for their whole lifetime, preserving
///   State, scroll offsets and stream subscriptions;
/// * only the selected child is painted, hit-testable and exposed to
///   semantics — `RenderIndexedStack` restricts paint, hit-testing and
///   semantics to the displayed child, and the layers do the same by being
///   offstage, ignoring pointers and excluding semantics while hidden;
/// * children are laid out with loose constraints aligned top-start, exactly
///   the constraints/alignment [IndexedStack] applies by default.
///
/// The one deliberate divergence: while an index change animates, both the
/// outgoing and the incoming child are painted for the length of the
/// cross-fade ([IndexedStack] would paint a single child). During that window
/// the outgoing child ignores pointers and is excluded from semantics.
/// Honors reduced motion ([appPrefersReducedMotion]): the switch is instant,
/// children still stay alive.
class TabCrossFade extends StatelessWidget {
  final int index;
  final List<Widget> children;
  final Duration duration;

  const TabCrossFade({
    super.key,
    required this.index,
    required this.children,
    this.duration = AppMotion.normal,
  });

  @override
  Widget build(BuildContext context) {
    assert(
      index >= 0 && index < children.length,
      'TabCrossFade index $index is out of range (${children.length} children)',
    );

    final bool reducedMotion = appPrefersReducedMotion(context);

    // Loose sizing + top-start alignment mirror [IndexedStack]'s defaults;
    // layers are non-positioned children, so each sizes itself (the real tabs
    // are full-screen Scafolds) and offstage layers report zero size without
    // affecting the stack.
    return Stack(
      alignment: AlignmentDirectional.topStart,
      children: [
        for (int i = 0; i < children.length; i++)
          _TabLayer(
            // Stable per-slot identity: an index change must never change
            // the element structure, only the layers' `visible` flags.
            key: ValueKey<int>(i),
            visible: i == index,
            reducedMotion: reducedMotion,
            duration: duration,
            child: children[i],
          ),
      ],
    );
  }
}

/// One permanently-mounted tab page. Owns its own opacity/rise animation and
/// rebuilds its wrappers in place — the child subtree below it is passed
/// through untouched, so its State survives every switch.
class _TabLayer extends StatefulWidget {
  final bool visible;
  final bool reducedMotion;
  final Duration duration;
  final Widget child;

  const _TabLayer({
    super.key,
    required this.visible,
    required this.reducedMotion,
    required this.duration,
    required this.child,
  });

  @override
  State<_TabLayer> createState() => _TabLayerState();
}

class _TabLayerState extends State<_TabLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      // Exits finish a touch faster than entrances (modern asymmetric feel).
      reverseDuration: AppMotion.fast,
      // The initially selected tab starts settled; hidden tabs start clear.
      value: widget.visible ? 1.0 : 0.0,
    );
  }

  @override
  void didUpdateWidget(covariant _TabLayer oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.reducedMotion) {
      // Instant swap: no animation frames at all.
      _controller.value = widget.visible ? 1.0 : 0.0;
      return;
    }

    if (widget.visible != oldWidget.visible) {
      if (widget.visible) {
        // Continue from the current value so rapid tab flips stay smooth.
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final double t = widget.reducedMotion
            ? (widget.visible ? 1.0 : 0.0)
            : AppMotion.decelerate.transform(_controller.value);
        final bool hidden = !widget.visible && t == 0.0;

        return Offstage(
          offstage: hidden,
          child: IgnorePointer(
            ignoring: !widget.visible,
            child: ExcludeSemantics(
              excluding: !widget.visible,
              child: Opacity(
                opacity: t,
                child: Transform.translate(
                  offset: Offset(
                    0,
                    widget.visible ? AppMotion.riseOffset * (1.0 - t) : 0.0,
                  ),
                  child: child,
                ),
              ),
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}
