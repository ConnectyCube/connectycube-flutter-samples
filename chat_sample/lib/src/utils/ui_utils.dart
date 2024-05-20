import 'dart:ui';

Size getWidgetSize(double aspectRatio, int maxWidth, int maxHeight) {
  bool isVertical() {
    return aspectRatio < 1;
  }

  double widgetWidth;
  double widgetHeight;

  if (isVertical()) {
    widgetHeight = maxHeight.toDouble();
    widgetWidth = widgetHeight * aspectRatio;
  } else {
    widgetWidth = maxWidth.toDouble();
    widgetHeight = (widgetWidth ~/ aspectRatio).toDouble();
  }

  return Size(widgetWidth, widgetHeight);
}
