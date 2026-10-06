import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Horizontal pages inside the vertical feed.
///
/// A sideways drag wins as soon as it is clearly horizontal, so it does not
/// get stolen by the feed. A vertical drag is left for the feed.
class SocialMediaPager extends StatefulWidget {
  final PageController controller;
  final int itemCount;
  final ValueChanged<int> onPageChanged;
  final IndexedWidgetBuilder itemBuilder;

  const SocialMediaPager({
    super.key,
    required this.controller,
    required this.itemCount,
    required this.onPageChanged,
    required this.itemBuilder,
  });

  @override
  State<SocialMediaPager> createState() => _SocialMediaPagerState();
}

class _SocialMediaPagerState extends State<SocialMediaPager> {
  void _onDelta(double dx) {
    if (!widget.controller.hasClients) return;
    final position = widget.controller.position;
    final next = (position.pixels - dx).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (next != position.pixels) {
      position.jumpTo(next);
    }
  }

  void _onEnd(Velocity velocity) {
    if (!widget.controller.hasClients) return;
    final page = widget.controller.page ?? 0;
    final vx = velocity.pixelsPerSecond.dx;
    final int target;
    if (vx <= -700) {
      target = page.floor() + 1;
    } else if (vx >= 700) {
      target = page.ceil() - 1;
    } else {
      target = page.round();
    }
    widget.controller.animateToPage(
      target.clamp(0, widget.itemCount - 1),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.itemCount <= 1) {
      return widget.itemBuilder(context, 0);
    }
    final pager = PageView.builder(
      controller: widget.controller,
      scrollDirection: Axis.horizontal,
      physics: const _GalleryPhysics(),
      itemCount: widget.itemCount,
      onPageChanged: widget.onPageChanged,
      itemBuilder: widget.itemBuilder,
    );
    return RawGestureDetector(
      behavior: HitTestBehavior.translucent,
      gestures: <Type, GestureRecognizerFactory>{
        _CarouselDragRecognizer:
            GestureRecognizerFactoryWithHandlers<_CarouselDragRecognizer>(
          () => _CarouselDragRecognizer(),
          (_CarouselDragRecognizer instance) {
            instance.onDelta = _onDelta;
            instance.onEnd = _onEnd;
          },
        ),
      },
      child: pager,
    );
  }
}

/// Keeps the gallery from fighting the feed, while still building the
/// next photo so a sideways swipe does not flash empty.
class _GalleryPhysics extends NeverScrollableScrollPhysics {
  const _GalleryPhysics({super.parent});

  @override
  bool get allowImplicitScrolling => true;

  @override
  _GalleryPhysics applyTo(ScrollPhysics? ancestor) {
    return _GalleryPhysics(parent: buildParent(ancestor));
  }
}

class _CarouselDragRecognizer extends OneSequenceGestureRecognizer {
  void Function(double dx)? onDelta;
  void Function(Velocity velocity)? onEnd;

  int? _pointer;
  double _dx = 0;
  double _dy = 0;
  bool _accepted = false;
  bool _settled = false;
  VelocityTracker? _tracker;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    if (_pointer != null) return;
    _pointer = event.pointer;
    _dx = 0;
    _dy = 0;
    _accepted = false;
    _settled = false;
    _tracker = VelocityTracker.withKind(event.kind);
    _tracker!.addPosition(event.timeStamp, event.position);
    startTrackingPointer(event.pointer, event.transform);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event.pointer != _pointer) return;
    if (event is PointerDownEvent) return;
    if (event is PointerMoveEvent) {
      _tracker?.addPosition(event.timeStamp, event.position);
      if (_accepted) {
        onDelta?.call(event.delta.dx);
        return;
      }
      _dx += event.delta.dx;
      _dy += event.delta.dy;
      if (_dx.abs() > 14 && _dx.abs() > _dy.abs() * 1.15) {
        _accept();
        onDelta?.call(_dx);
      } else if (_dy.abs() > 16 && _dy.abs() >= _dx.abs()) {
        _reject();
      }
      return;
    }
    if (event is PointerUpEvent || event is PointerCancelEvent) {
      if (_accepted) {
        final velocity = event is PointerUpEvent
            ? (_tracker?.getVelocity() ?? Velocity.zero)
            : Velocity.zero;
        onEnd?.call(velocity);
        stopTrackingPointer(event.pointer);
      } else {
        _reject();
      }
    }
  }

  void _accept() {
    if (_settled) return;
    _settled = true;
    _accepted = true;
    resolve(GestureDisposition.accepted);
  }

  void _reject() {
    if (_settled) return;
    _settled = true;
    _accepted = false;
    resolve(GestureDisposition.rejected);
  }

  @override
  void acceptGesture(int pointer) {
    _accepted = true;
    _settled = true;
  }

  @override
  void rejectGesture(int pointer) {
    _accepted = false;
    _settled = true;
    stopTrackingPointer(pointer);
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    _pointer = null;
    _tracker = null;
  }

  @override
  String get debugDescription => 'carousel drag';
}
