import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

class BottomPinnedSliver extends SingleChildRenderObjectWidget {
  const BottomPinnedSliver({
    required this.bottomInset,
    required super.child,
    super.key,
  });
  final double bottomInset;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderBottomPinned(bottomInset);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderBottomPinned renderObject,
  ) {
    renderObject.bottomInset = bottomInset;
  }
}

class RenderBottomPinned extends RenderSliverSingleBoxAdapter {
  RenderBottomPinned(this._bottomInset);
  double _bottomInset;
  double _childOffset = 0;
  double _lastHeight = 0;
  bool _wasPinned = false;

  set bottomInset(double value) {
    if (_bottomInset == value) return;
    _bottomInset = value;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    child!.layout(constraints.asBoxConstraints(), parentUsesSize: true);
    final height = child!.size.height;
    final room = constraints.remainingPaintExtent;
    final shortage = height + _bottomInset - room;
    if (_wasPinned && height > _lastHeight && shortage > 0.01) {
      _lastHeight = height;
      // Move preceding tasks up as the completed section opens upward.
      geometry = SliverGeometry(scrollOffsetCorrection: shortage);
      return;
    }
    _lastHeight = height;
    _wasPinned = room >= height + _bottomInset - 0.01;
    _childOffset = math.max(
      -constraints.scrollOffset,
      room - _bottomInset - height,
    );
    final viewport = constraints.viewportMainAxisExtent;
    final contentFits =
        constraints.precedingScrollExtent + height + _bottomInset <= viewport;
    final extent = contentFits
        ? viewport - constraints.precedingScrollExtent
        : height + _bottomInset;
    final paintExtent = (_childOffset + height).clamp(0.0, room);
    geometry = SliverGeometry(
      scrollExtent: extent,
      paintExtent: paintExtent,
      layoutExtent: paintExtent,
      maxPaintExtent: math.max(viewport, extent),
      hasVisualOverflow: true,
    );
    (child!.parentData! as SliverPhysicalParentData).paintOffset = Offset(
      0,
      _childOffset,
    );
  }

  @override
  double childMainAxisPosition(RenderBox child) => _childOffset;
}
