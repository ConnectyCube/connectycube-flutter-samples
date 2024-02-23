import 'dart:ui';

Size getWidgetSize(double aspectRatio, int maxWidth, int maxHeight) {
  bool isVertical() {
    return aspectRatio < 1;
  }

  var widgetWidth;
  var widgetHeight;

  if (isVertical()) {
    widgetHeight = maxHeight;
    widgetWidth = widgetHeight * aspectRatio;
  } else {
    widgetWidth = maxWidth;
    widgetHeight = widgetWidth ~/ aspectRatio;
  }

  return Size(widgetWidth.toDouble(), widgetHeight.toDouble());
}
