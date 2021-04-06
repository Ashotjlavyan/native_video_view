import 'package:flutter/material.dart';
import 'package:native_video_view/native_video_view.dart';

void main() => runApp(MaterialApp(home: MyApp()));

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Plugin example app'),
      ),
      body: _buildVideoPlayerWidget(),
    );
  }

  Widget _buildVideoPlayerWidget() {
    VideoViewController _vvv = VideoViewController(
        source: 'assets/example.mp4', sourceType: VideoSourceType.asset);

    _vvv.setLooping(true);

    return Container(
      alignment: Alignment.center,
      child: NativeVideoView(
        videoViewController: _vvv,
      ),
    );
  }
}
