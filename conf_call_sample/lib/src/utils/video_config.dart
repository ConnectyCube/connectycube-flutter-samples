class VideoQuality {
  final int width;
  final int height;

  const VideoQuality(this.width, this.height);
}

const HD_VIDEO = const VideoQuality (1280, 720);
const VGA_VIDEO = const VideoQuality (640, 480);
const QVGA_VIDEO = const VideoQuality (320, 240);