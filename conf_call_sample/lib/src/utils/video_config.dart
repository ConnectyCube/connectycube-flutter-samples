class VideoQuality {
  final int width;
  final int height;

  const VideoQuality(this.width, this.height);
}

const hdVideo = VideoQuality(1280, 720);
const vgaVideo = VideoQuality(640, 480);
const qVgaVideo = VideoQuality(320, 240);
