import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';

class FullPhoto extends StatelessWidget {
  final String url;

  const FullPhoto({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Full photo',
        ),
        centerTitle: true,
      ),
      body: FullPhotoScreen(url: url),
    );
  }
}

class FullPhotoScreen extends StatefulWidget {
  final String url;

  const FullPhotoScreen({super.key, required this.url});

  @override
  FullPhotoScreenState createState() {
    return FullPhotoScreenState();
  }
}

class FullPhotoScreenState extends State<FullPhotoScreen> {
  FullPhotoScreenState();

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return PhotoView(imageProvider: NetworkImage(widget.url));
  }
}
