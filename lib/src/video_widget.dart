part of native_video_view;

/// Callback that indicates the progression of the media being played.
typedef ProgressionDurationCallback = void Function(
    Duration position, Duration duration);

/// Widget that displays a video player.
/// This widget calls an underlying player in the
/// respective platform, [VideoView] in Android and
/// [AVPlayer] in iOS.
class NativeVideoView extends StatefulWidget {
  /// Current video file loaded in the player.
  /// The [info] attribute is loaded when the player reaches
  /// the prepared state.
  final VideoViewController videoViewController;

  /// Forces the use of ExoPlayer instead of the native VideoView.
  ///
  /// Only in Android.
  final bool useExoPlayer;

  /// Instance of [ProgressionDurationCallback] to notify
  /// when the time progresses while playing.
  final ProgressionDurationCallback onProgress;

  /// Constructor of the widget.
  const NativeVideoView({
    Key key,
    @required this.videoViewController,
    this.useExoPlayer,
    this.onProgress,
  })  : assert(videoViewController != null),
        super(key: key);

  @override
  _NativeVideoViewState createState() => _NativeVideoViewState();
}

/// State of the video widget.
class _NativeVideoViewState extends State<NativeVideoView> {
  _NativeVideoViewState() {
    _listener = () {
      final double newAspectRatio =
          widget.videoViewController.value.aspectRatio;
      final Duration newPosition = widget.videoViewController.value.position;

      if (newAspectRatio != _aspectRatio) {
        setState(() {
          _aspectRatio = newAspectRatio;
        });
      }

      if (newPosition != _position) {
        _position = newPosition;
        if (widget.onProgress != null) {
          widget.onProgress(
              _position, widget.videoViewController.value.duration);
        }
      }
    };
  }

  VoidCallback _listener;

  /// Value of the aspect ratio. Changes depending of the
  /// loaded file.
  double _aspectRatio = 4 / 3;
  Duration _position;

  @override
  void initState() {
    super.initState();
    widget.videoViewController.addListener(_listener);
  }

  @override
  void didUpdateWidget(NativeVideoView oldWidget) {
    super.didUpdateWidget(oldWidget);
    oldWidget.videoViewController.removeListener(_listener);
    widget.videoViewController.addListener(_listener);
  }

  @override
  void deactivate() {
    super.deactivate();
    widget.videoViewController.removeListener(_listener);
  }

  /// Builds the view based on the platform that runs the app.
  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> creationParams = <String, dynamic>{
      'useExoPlayer': widget.useExoPlayer ?? false,
    };
    if (defaultTargetPlatform == TargetPlatform.android) {
      return _buildVideoView(
          child: AndroidView(
        viewType: 'native_video_view',
        onPlatformViewCreated: onPlatformViewCreated,
        creationParams: creationParams,
        creationParamsCodec: const StandardMessageCodec(),
      ));
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      return _buildVideoView(
        child: UiKitView(
          viewType: 'native_video_view',
          onPlatformViewCreated: onPlatformViewCreated,
          creationParams: creationParams,
          creationParamsCodec: const StandardMessageCodec(),
        ),
      );
    }
    return Text('$defaultTargetPlatform is not yet supported by this plugin.');
  }

  /// Builds the video view depending of the configuration.
  Widget _buildVideoView({Widget child}) {
    Widget videoView = AspectRatio(
      child: child,
      aspectRatio: _aspectRatio,
    );

    return videoView;
  }

  /// Callback that is called when the view is created in the platform.
  Future<void> onPlatformViewCreated(int id) {
    widget.videoViewController.setChannel(id);
    widget.videoViewController.startBuffering();
  }
}
