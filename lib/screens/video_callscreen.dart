import 'dart:async';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';

class VideoCallScreen extends StatefulWidget {
  final String channelId;
  
  const VideoCallScreen({
    super.key,
    required this.channelId,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> with WidgetsBindingObserver {
  late RtcEngine _engine;
  int? _remoteUid;
  bool _localUserJoined = false;
  bool _previewStarted = false;
  bool _muted = false;
  bool _videoDisabled = false;
  bool _screenSharing = false;
  
  bool _engineInitialized = false;
  Timer? _joinTimeoutTimer;
  // Event log for debugging - shown on screen
  final List<String> _eventLogs = [];
  bool _showEventLog = false;
  // Position state for draggable PIP
  double _pipLeft = 20;
  double _pipTop = 100;
  bool _isDragging = false;

  static const String appId = "580ccf6b13074496b23734e407ae3ab1";
  // Temporary token provided for testing. Channel must match exactly 'TestingApp'.
  static const String token = "007eJxTYJifHWn2NdZg43VGvZan3fybXAzfptzi3Bm+4P+H73XlP3MUGEwtDJKT08ySDI0NzE1MLM2SjIzNjU1STQzME1ONE5MMp2QzZzYEMjLMLp3EyMgAgSA+F0NIanFJZl66Y0EBAwMAWxkidQ==";
  
  String get channel => widget.channelId;
  // Status string shown on-screen for debugging/visibility
  String _status = 'Initializing...';

  @override
  void initState() {
    super.initState();
    // Ensure permissions are granted before initializing Agora to avoid
    WidgetsBinding.instance.addObserver(this);
    // calling camera/audio APIs too early which can throw native errors.
    setState(() => _status = 'Starting...');
    _initializeEverything();
  }


  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Handle camera lifecycle to avoid dangling native sessions when app
    // is backgrounded or resumed.
    if (!_engineInitialized) return;

    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      // Try to stop preview when app is not active.
      _safeStopPreview();
    } else if (state == AppLifecycleState.resumed) {
      // Try to restart preview when returning to app.
      _safeStartPreview();
    }
  }
  Future<void> _initializeEverything() async {
    setState(() => _status = 'Requesting permissions...');
    final granted = await _requestPermissions();
    if (!granted) {
      setState(() => _status = 'Permissions denied');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Camera or microphone permission denied')),
        );
      }
      return;
    }

    setState(() => _status = 'Initializing engine...');
    await _initAgora();
  }

  /// Requests camera & microphone permissions. Returns true if both granted.
  Future<bool> _requestPermissions() async {
    final statuses = await [Permission.camera, Permission.microphone].request();
    final cameraGranted = statuses[Permission.camera]?.isGranted ?? false;
    final micGranted = statuses[Permission.microphone]?.isGranted ?? false;
    return cameraGranted && micGranted;
  }

  Future<void> _initAgora() async {
    try {
      _engine = createAgoraRtcEngine();

      setState(() => _status = 'Creating engine...');

      await _engine.initialize(
        RtcEngineContext(
          appId: appId,
          channelProfile: ChannelProfileType.channelProfileCommunication,
        ),
      );

      setState(() => _status = 'Enabling video...');
      await _engine.enableVideo();

      setState(() => _status = 'Starting local preview...');
      await _engine.startPreview();
      // Mark that the local preview is running so we can show the PIP even
      // before fully joining the channel.
      setState(() => _previewStarted = true);
      // mark engine fully initialized
      _engineInitialized = true;
    } on AgoraRtcException catch (e) {
      debugPrint('Agora init error: ${e.code}, ${e.message}');
      if (mounted) {
        setState(() => _status = 'Init error: ${e.code}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to initialize video: ${e.code}')),
        );
      }
      return;
    } catch (e) {
      debugPrint('Unexpected error initializing Agora: $e');
      if (mounted) setState(() => _status = 'Init exception: $e');
      return;
    }

    _engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          debugPrint('Joined channel: $channel');
          _joinTimeoutTimer?.cancel();
          _addLog('onJoinChannelSuccess: channel=$channel elapsed=$elapsed');
          setState(() {
            _localUserJoined = true;
            _status = 'Joined channel: $channel';
          });
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          debugPrint('Remote user joined: $remoteUid');
          _joinTimeoutTimer?.cancel();
          _addLog('onUserJoined: uid=$remoteUid elapsed=$elapsed');
          setState(() {
            _remoteUid = remoteUid;
            _status = 'Remote user joined';
          });
        },
        onUserOffline: (
          RtcConnection connection,
          int remoteUid,
          UserOfflineReasonType reason,
        ) {
          debugPrint('Remote user left');
          setState(() {
            _remoteUid = null;
            _status = 'Remote user left';
          });
        },
        onLeaveChannel: (connection, stats) {
          debugPrint('◀️ Left channel');
          _addLog('onLeaveChannel');
          setState(() {
            _localUserJoined = false;
            _status = 'Left channel';
          });
        },
        onError: (ErrorCodeType err, String msg) {
          debugPrint('Agora engine error: $err, $msg');
          _addLog('onError: $err msg=$msg');
          if (mounted) setState(() => _status = 'Agora error: $err');
        },
        onConnectionStateChanged: (RtcConnection connection, ConnectionStateType state, ConnectionChangedReasonType reason) {
          debugPrint('Connection state changed: $state ($reason)');
          _addLog('onConnectionStateChanged: ${state.name}');
          if (mounted) setState(() => _status = 'Conn: ${state.name}');
        },
        onConnectionLost: (RtcConnection connection) {
          debugPrint('Connection lost');
          _addLog('onConnectionLost');
          if (mounted) setState(() => _status = 'Connection lost');
        },
        onTokenPrivilegeWillExpire: (RtcConnection connection, String token) {
          debugPrint('Token will expire soon');
          _addLog('onTokenPrivilegeWillExpire tokenLen=${token.length}');
          if (mounted) setState(() => _status = 'Token expiring');
        },
      ),
    );

    try {
      setState(() => _status = 'Joining channel...');
      // start a timeout to surface join failures (e.g., auth/network)
      _joinTimeoutTimer?.cancel();
      _joinTimeoutTimer = Timer(const Duration(seconds: 20), () {
        if (mounted && !_localUserJoined) {
          setState(() => _status = 'Join timeout (no response)');
        }
      });
      await _engine.joinChannel(
        token: token,
        channelId: channel,
        uid: 0,
        options: const ChannelMediaOptions(),
      );
    } catch (e) {
      debugPrint('Join channel failed: $e');
      if (mounted) {
        setState(() => _status = 'Join failed: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to join channel: $e')),);
      }
      _joinTimeoutTimer?.cancel();
      return;
    }
  }

  // Safely stop preview (catch native errors)
  void _safeStopPreview() {
    try {
      _engine.stopPreview();
      setState(() => _previewStarted = false);
    } catch (e) {
      debugPrint('safeStopPreview error: $e');
    }
  }

  // Safely start preview if engine initialized
  Future<void> _safeStartPreview() async {
    if (!_engineInitialized) return;
    try {
      await _engine.startPreview();
      setState(() => _previewStarted = true);
    } catch (e) {
      debugPrint('safeStartPreview error: $e');
    }
  }

  // Append a timestamped event to the in-memory log and print to console.
  void _addLog(String entry) {
    final ts = DateTime.now().toIso8601String();
    final text = '[$ts] $entry';
    try {
      setState(() {
        _eventLogs.insert(0, text);
        if (_eventLogs.length > 200) _eventLogs.removeLast();
      });
    } catch (_) {}
    debugPrint('EVENT: $text');
  }

  Future<void> _toggleScreenShare() async {
    try {
      if (_screenSharing) {
        await _engine.stopScreenCapture();
        setState(() => _screenSharing = false);
        debugPrint('Screen share stopped');
      } else {
        // ✅ Updated for Agora SDK 6.3.x: provide flags and params separately
        final screenParams = ScreenCaptureParameters2(
          captureVideo: true,
          captureAudio: true,
          videoParams: const ScreenVideoParameters(
            dimensions: VideoDimensions(width: 1280, height: 720),
            frameRate: 15,
            bitrate: 2000,
          ),
          audioParams: const ScreenAudioParameters(sampleRate: 44100, channels: 1),
        );

  // `startScreenCapture` takes the params as a positional argument in
  // some versions of the SDK.
  await _engine.startScreenCapture(screenParams);

        setState(() => _screenSharing = true);
        debugPrint('📱 Screen share started');
      }
    } catch (e) {
      debugPrint('Screen share error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Screen share failed: $e')),
        );
      }
    }
  }

  void _toggleMute() {
    setState(() => _muted = !_muted);
    _engine.muteLocalAudioStream(_muted);
  }

  void _toggleVideo() {
    setState(() => _videoDisabled = !_videoDisabled);
    _engine.muteLocalVideoStream(_videoDisabled);
  }

  @override
  void dispose() {
    // remove lifecycle observer
    try {
      WidgetsBinding.instance.removeObserver(this);
    } catch (_) {}
    try {
      // stop local preview if running
      _engine.stopPreview();
    } catch (e) {
      debugPrint('stopPreview error: $e');
    }

    try {
      _engine.leaveChannel();
    } catch (e) {
      debugPrint('leaveChannel error: $e');
    }

    try {
      _engine.disableVideo();
    } catch (e) {
      debugPrint('disableVideo error: $e');
    }

    try {
      _engine.release();
    } catch (e) {
      debugPrint('release error: $e');
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Video Call - $channel'),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          // Remote video view
          if (_remoteUid != null)
            AgoraVideoView(
              controller: VideoViewController.remote(
                rtcEngine: _engine,
                canvas: VideoCanvas(uid: _remoteUid!),
                connection: RtcConnection(channelId: channel),
              ),
            )
          else
            Container(
              color: Colors.black,
              child: Center(
                child: Text(
                  'Waiting for other user...\nChannel: $channel',
                  style: const TextStyle(color: Colors.white70, fontSize: 18),
                  textAlign: TextAlign.center,
                ),
              ),
            ),

          // Status overlay (top-left)
          Positioned(
            left: 12,
            top: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _status,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),

          // Local video (PIP) - Draggable
          if ((_localUserJoined || _previewStarted) && !_videoDisabled)
            Positioned(
              left: _pipLeft,
              top: _pipTop,
              child: GestureDetector(
                onPanUpdate: (details) {
                  setState(() {
                    _pipLeft = (_pipLeft + details.delta.dx).clamp(
                      0,
                      MediaQuery.of(context).size.width - 120,
                    );
                    _pipTop = (_pipTop + details.delta.dy).clamp(
                      0,
                      MediaQuery.of(context).size.height - 200,
                    );
                    _isDragging = true;
                  });
                },
                onPanEnd: (details) {
                  setState(() => _isDragging = false);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 120,
                  height: 160,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _isDragging ? Colors.blue : Colors.white,
                      width: _isDragging ? 4 : 3,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: _isDragging
                        ? [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: AgoraVideoView(
                      controller: VideoViewController(
                        rtcEngine: _engine,
                        canvas: const VideoCanvas(uid: 0),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          // Event log toggle button
          Positioned(
            right: 12,
            bottom: 120,
            child: FloatingActionButton.small(
              backgroundColor: Colors.black54,
              onPressed: () => setState(() => _showEventLog = !_showEventLog),
              child: Icon(_showEventLog ? Icons.list : Icons.bug_report, size: 20),
            ),
          ),

          // Event log panel
          if (_showEventLog)
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              height: 180,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Event log', style: TextStyle(color: Colors.white)),
                        Text('${_eventLogs.length}', style: const TextStyle(color: Colors.white54)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Scrollbar(
                        child: ListView.builder(
                          itemCount: _eventLogs.length,
                          reverse: false,
                          itemBuilder: (context, idx) {
                            final entry = _eventLogs[idx];
                            return Text(entry, style: const TextStyle(color: Colors.white70, fontSize: 12));
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),

      // Control buttons
      bottomNavigationBar: Container(
        color: Colors.black87,
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildControlButton(
              icon: Icons.mic,
              activeIcon: Icons.mic_off,
              onPressed: _toggleMute,
              color: Colors.red,
              isActive: _muted,
            ),
            _buildControlButton(
              icon: Icons.videocam,
              activeIcon: Icons.videocam_off,
              onPressed: _toggleVideo,
              color: Colors.orange,
              isActive: _videoDisabled,
            ),
            _buildControlButton(
              icon: Icons.screen_share,
              activeIcon: Icons.stop_screen_share,
              onPressed: _toggleScreenShare,
              color: Colors.blue,
              isActive: _screenSharing,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required IconData activeIcon,
    required VoidCallback onPressed,
    required Color color,
    required bool isActive,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Icon(
          isActive ? activeIcon : icon,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }
}
