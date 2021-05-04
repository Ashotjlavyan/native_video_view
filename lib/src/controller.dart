part of native_video_view;

/// Controller used to call the functions that
/// controls the [VideoView] in Android and the [AVPlayer] in iOS.
class VideoViewController extends ValueNotifier<VideoPlayerValue> {
  /// Path of the source loaded.
  final String? source;

  /// Type of source loaded.
  final VideoSourceType? sourceType;

  /// Constructor of the class.
  VideoViewController({this.source, this.sourceType})
      : super(VideoPlayerValue(duration: null));

  /// MethodChannel to call methods from the platform.
  late MethodChannel channel;

  /// Timer to control the progression of the video being played.
  Timer? _progressionController;

  bool _isDisposed = false;

  void setChannel(int id) {
    assert(id != null);
    channel = MethodChannel('native_video_view_$id');
    channel.setMethodCallHandler(_handleMethodCall);
  }

  @override
  Future<void> dispose() {
    if (!_isDisposed) {
      _isDisposed = true;
      _stopProgressTimer();
      _cleanTempFile();
    }

    super.dispose();
  }

  /// Handle the calls from the listeners of state of the player.
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'player#onCompletion':
        _stopProgressTimer();
        value = value.copyWith(isPlaying: false);

        if (value.isLooping) {
          play();
        }
        break;
      case 'player#onError':
        int what = call.arguments['what'] ?? -1;
        int extra = call.arguments['extra'] ?? -1;
        String? message = call.arguments['message'];
        value = VideoPlayerValue.erroneous(message);
        break;
      case 'player#onPrepared':
        Map? map = call.arguments;

        if (map != null) {
          value = value.copyWith(
            duration: Duration(milliseconds: map['duration']),
            size: Size(map['width'], map['height']),
          );

          play();
        }
        break;
    }
  }

  /// Sets the video source from an asset file.
  /// The [sourceType] parameter could be [VideoSourceType.asset],
  /// [VideoSourceType.file] or [VideoSourceType.network]
  Future<void> startBuffering() async {
    assert(source != null);
    bool requestAudioFocus = value.isRequestAudioFocus ?? false;
    if (sourceType == VideoSourceType.asset) {
      File file = await _getAssetFile(source!);
      await _setVideosSource(file.path, sourceType, requestAudioFocus);
    } else {
      await _setVideosSource(source!, sourceType, requestAudioFocus);
    }
  }

  /// Load an asset file as a temporary file. File is removed when the
  /// VideoView is disposed.
  /// Returns the file path of the temporary file.
  Future<File> _getAssetFile(String asset) async {
    var tempFile = await _createTempFile();
    ByteData data = await rootBundle.load(asset);
    List<int> bytes =
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    return tempFile.writeAsBytes(bytes);
  }

  /// Creates a new empty file. If the file exists, then is recreated to
  /// ensure that the file is empty.
  Future<File> _createTempFile() async {
    var tempFile = await _getTempFile();
    if (tempFile.existsSync()) tempFile.deleteSync();
    tempFile.createSync();
    return tempFile;
  }

  /// Remove the temporary file used for playing assets.
  /// Returns true if the file was removed or file if not.
  Future<bool> _cleanTempFile() async {
    var tempFile = await _getTempFile();
    if (tempFile.existsSync()) {
      try {
        tempFile.deleteSync();
        return true;
      } catch (ex) {
        print(ex);
      }
    }
    return false;
  }

  /// Returns the temp file for this instance of the widget.
  Future<File> _getTempFile() async {
    Directory directory = await getTemporaryDirectory();
    return File("${directory.path}/temp_${channel.name}.mp4");
  }

  /// Sets the video source from a file in the device memory.
  Future<void> _setVideosSource(String videoSource, VideoSourceType? sourceType,
      bool requestAudioFocus) async {
    assert(videoSource != null);
    Map<String, dynamic> args = {
      "videoSource": videoSource,
      "sourceType": sourceType.toString(),
      "requestAudioFocus": requestAudioFocus,
    };
    try {
      await channel.invokeMethod<void>("player#setVideoSource", args);
    } catch (ex) {
      print(ex);
    }
  }

  /// Starts/resumes the playback of the video.
  Future<bool> play() async {
    if (_isDisposed) {
      return false;
    }

    try {
      await channel.invokeMethod("player#start");
      value = value.copyWith(isPlaying: true);

      _startProgressTimer();
      return true;
    } catch (ex) {
      print(ex);
    }
    return false;
  }

  /// Pauses the playback of the video. Use
  /// [play] to resume the playback at any time.
  Future<bool> pause() async {
    if (_isDisposed) {
      return false;
    }

    try {
      await channel.invokeMethod("player#pause");
      value = value.copyWith(isPlaying: false);

      _stopProgressTimer();
      return true;
    } catch (ex) {
      print(ex);
    }
    return false;
  }

  /// Stops the playback of the video.
  Future<bool> stop() async {
    if (_isDisposed) {
      return false;
    }

    try {
      await channel.invokeMethod("player#stop");
      value = value.copyWith(isPlaying: false);

      _stopProgressTimer();
      _onProgressChanged(null);
      return true;
    } catch (ex) {
      print(ex);
    }
    return false;
  }

  /// Sets the video's current timestamp to be at [moment]. The next
  /// time the video is played it will resume from the given [moment].
  ///
  /// If [moment] is outside of the video's full range it will be automatically
  /// and silently clamped.
  Future<bool> seekTo(Duration position) async {
    if (_isDisposed) {
      return false;
    }

    assert(position != null);
    try {
      Map<String, dynamic> args = {"position": position.inMilliseconds};
      await channel.invokeMethod<void>("player#seekTo", args);

      _updatePosition(position);
      return true;
    } catch (ex) {
      print(ex);
    }
    return false;
  }

  /// Changes the state of the volume between muted and not muted.
  /// Returns true if the change was successful or false if an error happened.
  Future<bool> toggleSound() async {
    if (_isDisposed) {
      return false;
    }

    try {
      await channel.invokeMethod("player#toggleSound");
      return true;
    } catch (ex) {
      print(ex);
    }
    return false;
  }

  /// Sets the audio volume of [this].
  ///
  /// [volume] indicates a value between 0.0 (silent) and 1.0 (full volume) on a
  /// linear scale.
  Future<bool> setVolume(double volume) async {
    if (_isDisposed) {
      return false;
    }

    try {
      Map<String, dynamic> args = {"volume": volume};
      await channel.invokeMethod("player#setVolume", args);
      value = value.copyWith(volume: volume.clamp(0.0, 1.0));
      return true;
    } catch (ex) {
      print(ex);
    }
    return false;
  }

  /// Sets whether or not the video should loop after playing once. See also
  /// [VideoPlayerValue.isLooping].
  Future<void> setLooping(bool looping) async {
    if (_isDisposed) {
      return;
    }

    value = value.copyWith(isLooping: looping);
  }

  /// Sets whether or not the video should loop after playing once. See also
  /// [VideoPlayerValue.isRequestAudioFocus].
  Future<void> setRequestAudioFocus(bool requestAudioFocus) async {
    if (_isDisposed) {
      return;
    }

    value = value.copyWith(isRequestAudioFocus: requestAudioFocus);
  }

  /// Gets the current position of time in seconds.
  /// Returns the current position of playback in milliseconds.
  Future<int> currentPosition() async {
    if (_isDisposed) {
      return 0;
    }

    final result = await channel.invokeMethod("player#currentPosition");
    return result['currentPosition'] ?? 0;
  }

  /// Gets the state of the player.
  /// Returns true if the player is playing or false if is stopped or paused.
  Future<bool?> isPlaying() async {
    if (_isDisposed) {
      return false;
    }

    final result = await channel.invokeMethod("player#isPlaying");
    return result['isPlaying'];
  }

  /// Starts the timer that monitor the time progression of the playback.
  void _startProgressTimer() {
    if (_progressionController == null) {
      _progressionController =
          Timer.periodic(Duration(milliseconds: 100), _onProgressChanged);
    }
  }

  /// Stops the progression timer. If [resetCount] is true the elapsed
  /// time is restarted.
  void _stopProgressTimer() {
    if (_progressionController != null) {
      _progressionController!.cancel();
      _progressionController = null;
    }
  }

  /// Callback called by the timer when an event is called.
  /// Updates the elapsed time counter and notifies the widget
  /// state.
  void _onProgressChanged(Timer? timer) async {
    if (_isDisposed) {
      return;
    }

    int milliseconds = await currentPosition();

    Duration position = Duration(milliseconds: milliseconds);

    _updatePosition(position);
  }

  void _updatePosition(Duration position) {
    if (_isDisposed) {
      return;
    }

    value = value.copyWith(position: position);
  }
}
