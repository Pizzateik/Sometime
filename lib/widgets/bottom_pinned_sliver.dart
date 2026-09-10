import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

class BottomPinnedSliver extends SingleChildRenderObjectWidget {
  const BottomPinnedSliver({
    required this.bottomInset,
    this.overlapBefore = false,
    required super.child,
    super.key,
  });
  final double bottomInset;
  final bool overlapBefore;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderBottomPinned(bottomInset, overlapBefore);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderBottomPinned renderObject,
  ) {
    renderObject
      ..bottomInset = bottomInset
      ..overlapBefore = overlapBefore;
  }
}

class RenderBottomPinned extends RenderSliverSingleBoxAdapter {
  RenderBottomPinned(this._bottomInset, this._overlapBefore);
  double _bottomInset;
  bool _overlapBefore;
  double _childOffset = 0;
  double _lastHeight = 0;
  bool _wasPinned = false;

  set bottomInset(double value) {
    if (_bottomInset == value) return;
    _bottomInset = value;
    markNeedsLayout();
  }

  set overlapBefore(bool value) {
    if (_overlapBefore == value) return;
    _overlapBefore = value;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    child!.layout(constraints.asBoxConstraints(), parentUsesSize: true);
    final height = child!.size.height;
    final room = constraints.remainingPaintExtent;
    final shortage = height + _bottomInset - room;
    if (!_overlapBefore &&
        _wasPinned &&
        height > _lastHeight &&
        shortage > 0.01) {
      _lastHeight = height;
      // Move preceding tasks up as the completed section opens upward.
      geometry = SliverGeometry(scrollOffsetCorrection: shortage);
      return;
    }
    _lastHeight = height;
    _wasPinned = room >= height + _bottomInset - 0.01;
    final pinnedOffset = room - _bottomInset - height;
    _childOffset = _overlapBefore
        ? pinnedOffset
        : math.max(-constraints.scrollOffset, pinnedOffset);
    final viewport = constraints.viewportMainAxisExtent;
    final contentFits =
        constraints.precedingScrollExtent + height + _bottomInset <= viewport;
    final extent = _overlapBefore
        ? math.max(
            math.max(0.0, viewport - constraints.precedingScrollExtent),
            height + _bottomInset,
          )
        : contentFits
        ? viewport - constraints.precedingScrollExtent
        : height + _bottomInset;
    final paintOrigin = _overlapBefore ? math.min(0.0, _childOffset) : 0.0;
    final paintEnd = _childOffset + height;
    final paintExtent = (paintEnd - paintOrigin).clamp(0.0, room - paintOrigin);
    final layoutExtent = paintEnd.clamp(0.0, room);
    geometry = SliverGeometry(
      scrollExtent: extent,
      paintOrigin: paintOrigin,
      paintExtent: paintExtent,
      layoutExtent: math.min(layoutExtent, paintExtent),
      maxPaintExtent: math.max(viewport, extent),
      hasVisualOverflow: true,
    );
    (child!.parentData! as SliverPhysicalParentData).paintOffset = Offset(
      0,
      _childOffset - paintOrigin,
    );
  }

  @override
  double childMainAxisPosition(RenderBox child) =>
      _childOffset - (geometry?.paintOrigin ?? 0);
}
