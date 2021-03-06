import 'dart:ffi';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:lychee_player/lychee_player.dart';

// ignore: implementation_imports
import 'package:lychee_player/src/ffi_player.dart';
import 'package:overlay_support/overlay_support.dart';
import 'package:permission_handler/permission_handler.dart';

import 'full_screen_player.dart';
import 'stores.dart';
import 'widgets/player_components.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final urls = await UrlStores.instance.getUrls();
  urls.addAll({
    'http://music.163.com/song/media/outer/url?id=1451998397.mp3': PlayType.url,
    'http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4':
        PlayType.url,
    'tracks/rise.mp3': PlayType.asset,
    'https://storage.googleapis.com/exoplayer-test-media-0/play.mp3':
        PlayType.url,
  });
  runApp(OverlaySupport.global(child: MyApp(urls)));
}

enum PlayType { file, url, asset }

class MyApp extends StatefulWidget {
  final Map<String, PlayType> urls;

  MyApp(this.urls, {Key? key}) : super(key: key);

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  AudioPlayer? player;
  String? url;

  Map<String, PlayType> urls = <String, PlayType>{};

  @override
  void initState() {
    super.initState();
    urls.addAll(widget.urls);
    _newPlayer(urls.keys.first);
  }

  void _newPlayer(String? uri) {
    if (this.url == uri) {
      return;
    }
    if (player != null) {
      player!.dispose();
    }
    final type = urls[uri!]!;
    switch (type) {
      case PlayType.file:
        player = AudioPlayer.file(uri);
        break;
      case PlayType.url:
        player = AudioPlayer.url(uri);
        break;
      case PlayType.asset:
        player = AudioPlayer.asset(uri);
        break;
    }
    this.url = uri;
    player!.onStateChanged.addListener(() {
      debugPrint(
          'state change: ${player!.status} playing: ${player!.isPlaying}');
    });
    player!.playWhenReady = true;
    player!.volume = 20;
  }

  @override
  void dispose() {
    super.dispose();
    player?.dispose();
  }

  Widget buildListTile(BuildContext context, String item) {
    return RadioListTile(
      value: item,
      groupValue: url,
      title: Text(item),
      secondary: IconButton(
          icon: Icon(Icons.delete_outline),
          onPressed: () {
            setState(() {
              urls.remove(item);
              UrlStores.instance.remove(item);
            });
          }),
      onChanged: (dynamic newValue) {
        setState(() {
          _newPlayer(newValue);
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        home: Scaffold(
          appBar: HomeAppBar(add: (added) {
            setState(() {
              urls.addEntries([added]);
              UrlStores.instance.put(added.key, added.value);
            });
          }),
          body: Column(
            children: [
              SmallVideo(player: player),
              _PlayerUi(player: player, url: this.url),
              Expanded(
                  child: ListView(
                children: [
                  for (var item in urls.keys) buildListTile(context, item)
                ],
              )),
            ],
          ),
        ),
      );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty<AudioPlayer?>('player', player))
      ..add(StringProperty('url', url))
      ..add(DiagnosticsProperty<Map<String, PlayType>>('urls', urls));
  }
}

class HomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Function(MapEntry<String, PlayType>) add;

  const HomeAppBar({Key? key, required this.add}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: const Text('Plugin example app'),
      actions: [
        IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              ffplayer_init(NativeApi.initializeApiDLData);
            }),
        IconButton(
            icon: Icon(Icons.add),
            tooltip: 'Add custom video/audio uri',
            onPressed: () async {
              final MapEntry<String, PlayType>? result = await showDialog(
                  context: context,
                  builder: (context) {
                    return PathInputDialog();
                  });
              if (result == null) {
                return;
              }
              var url = result.key.trim();
              if (url.isEmpty) {
                return;
              }
              if (url.startsWith('"')) {
                url = url.substring(1);
              }
              if (url.endsWith('"')) {
                url = url.substring(0, url.length - 1);
              }
              add(MapEntry(url, result.value));
            }),
        IconButton(
            icon: Icon(Icons.more_vert),
            onPressed: () {
              toast('more clicked');
            })
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class PathInputDialog extends StatefulWidget {
  const PathInputDialog({Key? key}) : super(key: key);

  @override
  _PathInputDialogState createState() => _PathInputDialogState();
}

class _PathInputDialogState extends State<PathInputDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      title: Text('input url or file path'),
      children: [
        TextField(controller: _controller),
        TextButton(
            child: Text('FILE'),
            onPressed: () async {
              if (Platform.isAndroid) {
                if (!(await Permission.storage.isGranted)) {
                  Permission.storage.request();
                }
              }
              Navigator.of(context)
                  .pop(MapEntry(_controller.text, PlayType.file));
            }),
        TextButton(
            child: Text('URL'),
            onPressed: () {
              Navigator.of(context)
                  .pop(MapEntry(_controller.text, PlayType.url));
            }),
        TextButton(
            child: Text('Cancel'),
            onPressed: () {
              Navigator.of(context).pop();
            }),
      ],
    );
  }
}

class SmallVideo extends StatelessWidget {
  const SmallVideo({
    Key? key,
    required this.player,
  }) : super(key: key);

  final AudioPlayer? player;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => FullScreenPage(player: player!)));
      },
      child:
          SizedBox(height: 200, width: 200, child: VideoView(player: player!)),
    );
  }
}

class _PlayerUi extends StatelessWidget {
  const _PlayerUi({
    Key? key,
    required this.player,
    required this.url,
  }) : super(key: key);

  final AudioPlayer? player;
  final String? url;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'playing: $url',
            softWrap: false,
            overflow: TextOverflow.fade,
          ),
          PlaybackStatefulButton(player: player),
          TickedPlayerState(player: player!),
          ForwardRewindButton(player: player)
        ],
      ),
    );
  }
}

class TickedPlayerState extends StatefulWidget {
  final AudioPlayer player;

  const TickedPlayerState({Key? key, required this.player}) : super(key: key);

  @override
  _TickedPlayerStateState createState() => _TickedPlayerStateState();
}

class _TickedPlayerStateState extends State<TickedPlayerState>
    with SingleTickerProviderStateMixin {
  late Ticker _ticker;

  @override
  void initState() {
    _ticker = createTicker((elapsed) {
      setState(() {});
    });
    _ticker.start();
    super.initState();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  Widget _buildProgress() {
    double? progress;
    if (widget.player.duration > Duration.zero) {
      progress = widget.player.currentTime.inMilliseconds /
          widget.player.duration.inMilliseconds;
    }
    return LinearProgressIndicator(
      value: progress,
    );
  }

  Widget _buildBufferedProgress() {
    double? progress;
    if (widget.player.duration > Duration.zero) {
      Duration bufferPosition = widget.player.buffered.value.max;
      if (bufferPosition <= Duration.zero) {
        progress = null;
      } else {
        progress = bufferPosition.inMilliseconds /
            widget.player.duration.inMilliseconds;
      }
    }
    return LinearProgressIndicator(
      value: progress,
    );
  }

  Widget _buildProgressText() {
    return Text(
        ' ${(widget.player.currentTime.inMilliseconds / 1000.0).toStringAsFixed(2)}'
        '/${(widget.player.duration.inMilliseconds / 1000.0).toStringAsFixed(2)}'
        ' - ${(widget.player.buffered.value.max.inMilliseconds / 1000).toStringAsFixed(2)}');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildProgress(),
        SizedBox(height: 16),
        _buildBufferedProgress(),
        SizedBox(height: 16),
        Align(
            alignment: AlignmentDirectional.centerEnd,
            child: _buildProgressText()),
      ],
    );
  }
}
