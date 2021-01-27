import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';

import 'audio_player_common.dart';
import 'audio_player_io.dart';

const int _FFP_MSG_FLUSH = 0;
const int _FFP_MSG_ERROR = 100; /* arg1 = error */
const int _FFP_MSG_PREPARED = 200;
const int _FFP_MSG_COMPLETED = 300;
const int _FFP_MSG_VIDEO_SIZE_CHANGED = 400; /* arg1 = width, arg2 = height */
const int _FFP_MSG_SAR_CHANGED = 401; /* arg1 = sar.num, arg2 = sar.den */
const int _FFP_MSG_VIDEO_RENDERING_START = 402;
const int _FFP_MSG_AUDIO_RENDERING_START = 403;
const int _FFP_MSG_VIDEO_ROTATION_CHANGED = 404; /* arg1 = degree */
const int _FFP_MSG_AUDIO_DECODED_START = 405;
const int _FFP_MSG_VIDEO_DECODED_START = 406;
const int _FFP_MSG_OPEN_INPUT = 407;
const int _FFP_MSG_FIND_STREAM_INFO = 408;
const int _FFP_MSG_COMPONENT_OPEN = 409;
const int _FFP_MSG_VIDEO_SEEK_RENDERING_START = 410;
const int _FFP_MSG_AUDIO_SEEK_RENDERING_START = 411;
const int _FFP_MSG_VIDEO_FRAME_LOADED =
    412; /* arg1 = display width, arg2 = display height */

const int _FFP_MSG_BUFFERING_START = 500;
const int _FFP_MSG_BUFFERING_END = 501;
const int _FFP_MSG_BUFFERING_UPDATE =
    502; /* arg1 = buffering head position in time, arg2 = minimum percent in time or bytes */
const int _FFP_MSG_BUFFERING_BYTES_UPDATE =
    503; /* arg1 = cached data in bytes,            arg2 = high water mark */
const int _FFP_MSG_BUFFERING_TIME_UPDATE =
    504; /* arg1 = cached duration in milliseconds, arg2 = high water mark */
const int _FFP_MSG_SEEK_COMPLETE =
    600; /* arg1 = seek position,                   arg2 = error */
const int _FFP_MSG_PLAYBACK_STATE_CHANGED = 700;
const int _FFP_MSG_TIMED_TEXT = 800;
const int _FFP_MSG_ACCURATE_SEEK_COMPLETE = 900; /* arg1 = current position*/
const int _FFP_MSG_GET_IMG_STATE =
    1000; /* arg1 = timestamp, arg2 = result code, obj = file name*/

const int _FFP_MSG_VIDEO_DECODER_OPEN = 10001;

const int _FFP_REQ_START = 20001;
const int _FFP_REQ_PAUSE = 20002;
const int _FFP_REQ_SEEK = 20003;

const int _FFP_PROP_FLOAT_VIDEO_DECODE_FRAMES_PER_SECOND = 10001;
const int _FFP_PROP_FLOAT_VIDEO_OUTPUT_FRAMES_PER_SECOND = 10002;
const int _FFP_PROP_FLOAT_PLAYBACK_RATE = 10003;
const int _FFP_PROP_FLOAT_PLAYBACK_VOLUME = 10006;
const int _FFP_PROP_FLOAT_AVDELAY = 10004;
const int _FFP_PROP_FLOAT_AVDIFF = 10005;
const int _FFP_PROP_FLOAT_DROP_FRAME_RATE = 10007;

const int _FFP_PROP_INT64_SELECTED_VIDEO_STREAM = 20001;
const int _FFP_PROP_INT64_SELECTED_AUDIO_STREAM = 20002;
const int _FFP_PROP_INT64_SELECTED_TIMEDTEXT_STREAM = 20011;
const int _FFP_PROP_INT64_VIDEO_DECODER = 20003;
const int _FFP_PROP_INT64_AUDIO_DECODER = 20004;
const int _FFP_PROPV_DECODER_UNKNOWN = 0;
const int _FFP_PROPV_DECODER_AVCODEC = 1;
const int _FFP_PROPV_DECODER_MEDIACODEC = 2;
const int _FFP_PROPV_DECODER_VIDEOTOOLBOX = 3;
const int _FFP_PROP_INT64_VIDEO_CACHED_DURATION = 20005;
const int _FFP_PROP_INT64_AUDIO_CACHED_DURATION = 20006;
const int _FFP_PROP_INT64_VIDEO_CACHED_BYTES = 20007;
const int _FFP_PROP_INT64_AUDIO_CACHED_BYTES = 20008;
const int _FFP_PROP_INT64_VIDEO_CACHED_PACKETS = 20009;
const int _FFP_PROP_INT64_AUDIO_CACHED_PACKETS = 20010;

const int _FFP_PROP_INT64_BIT_RATE = 20100;

const int _FFP_PROP_INT64_TCP_SPEED = 20200;

const int _FFP_PROP_INT64_ASYNC_STATISTIC_BUF_BACKWARDS = 20201;
const int _FFP_PROP_INT64_ASYNC_STATISTIC_BUF_FORWARDS = 20202;
const int _FFP_PROP_INT64_ASYNC_STATISTIC_BUF_CAPACITY = 20203;
const int _FFP_PROP_INT64_TRAFFIC_STATISTIC_BYTE_COUNT = 20204;

const int _FFP_PROP_INT64_LATEST_SEEK_LOAD_DURATION = 20300;

const int _FFP_PROP_INT64_CACHE_STATISTIC_PHYSICAL_POS = 20205;

const int _FFP_PROP_INT64_CACHE_STATISTIC_FILE_FORWARDS = 20206;

const int _FFP_PROP_INT64_CACHE_STATISTIC_FILE_POS = 20207;

const int _FFP_PROP_INT64_CACHE_STATISTIC_COUNT_BYTES = 20208;

const int _FFP_PROP_INT64_LOGICAL_FILE_SIZE = 20209;
const int _FFP_PROP_INT64_SHARE_CACHE_DATA = 20210;
const int _FFP_PROP_INT64_IMMEDIATE_RECONNECT = 20211;

const _FFP_STATE_IDLE = 0;
const _FFP_STATE_READY = 1;
const _FFP_STATE_BUFFERING = 2;
const _FFP_STATE_END = 3;

DynamicLibrary _openLibrary() {
  if (Platform.isLinux) {
    return DynamicLibrary.open("libffplayer.so");
  }
  if (Platform.isWindows) {
    return DynamicLibrary.open("ffplayer.dll");
  }
  throw UnimplementedError(
      "can not load for this library: ${Platform.localeName}");
}

final _library = _openLibrary();

final ffplayer_alloc_player =
    _library.lookupFunction<Pointer Function(), Pointer Function()>(
        "ffplayer_alloc_player");

final ffplayer_open_file = _library.lookupFunction<
    IntPtr Function(Pointer, Pointer<Utf8>),
    int Function(Pointer, Pointer<Utf8>)>("ffplayer_open_file");

final ffplayer_init = _library.lookupFunction<Void Function(Pointer<Void>),
    void Function(Pointer<Void>)>("ffplayer_global_init");

final ffplayer_free_player =
    _library.lookupFunction<Void Function(Pointer), void Function(Pointer)>(
        "ffplayer_free_player");

final ffplayer_get_current_position =
    _library.lookupFunction<Double Function(Pointer), double Function(Pointer)>(
        "ffplayer_get_current_position");

final ffplayer_get_duration =
    _library.lookupFunction<Double Function(Pointer), double Function(Pointer)>(
        "ffplayer_get_duration");

final ffplayer_seek_to_position = _library.lookupFunction<
    Void Function(Pointer, Double),
    void Function(Pointer, double)>("ffplayer_seek_to_position");

final ffp_set_message_callback = _library.lookupFunction<
    Void Function(Pointer, Int64),
    void Function(Pointer, int)>("ffp_set_message_callback_dart");

final ffplayer_is_paused =
    _library.lookupFunction<Int8 Function(Pointer), int Function(Pointer)>(
        "ffplayer_is_paused");

final ffplayer_toggle_pause =
    _library.lookupFunction<Void Function(Pointer), void Function(Pointer)>(
        "ffplayer_toggle_pause");

var _inited = false;

void _ensureFfplayerGlobalInited() {
  if (_inited) {
    return;
  }
  _inited = true;
  ffplayer_init(NativeApi.initializeApiDLData);
}

class FfiAudioPlayer implements AudioPlayer {
  final ValueNotifier<PlayerStatus> _status = ValueNotifier(PlayerStatus.Idle);
  final _buffred = ValueNotifier<List<DurationRange>>(const []);
  final _error = ValueNotifier(null);

  late Pointer player;

  late ReceivePort cppInteractPort;

  FfiAudioPlayer(String uri, DataSourceType type) {
    _ensureFfplayerGlobalInited();
    player = ffplayer_alloc_player();
    if (player == nullptr) {
      throw Exception("memory not enough");
    }

    cppInteractPort = ReceivePort("ffp: $uri")
      ..listen((message) {
        assert(message is Uint8List);
        final values = Int64List.view(message.buffer);
        _onMessage(values[0], values[1], values[2]);
      });
    ffp_set_message_callback(player, cppInteractPort.sendPort.nativePort);
    ffplayer_open_file(player, Utf8.toUtf8(uri));

    debugPrint("player ${player}");
  }

  void _onMessage(int what, int arg1, int arg2) {
    switch (what) {
      case _FFP_MSG_BUFFERING_TIME_UPDATE:
        final buffered = DurationRange.mills(0, arg1);
        _buffred.value = [buffered];
        break;
      case _FFP_MSG_PLAYBACK_STATE_CHANGED:
        assert(() {
          assert(arg1 == _FFP_STATE_BUFFERING ||
              arg1 == _FFP_STATE_IDLE ||
              arg1 == _FFP_STATE_READY ||
              arg1 == _FFP_STATE_END);
          return true;
        }());
        const statesMap = {
          _FFP_STATE_END: PlayerStatus.End,
          _FFP_STATE_BUFFERING: PlayerStatus.Buffering,
          _FFP_STATE_IDLE: PlayerStatus.Idle,
          _FFP_STATE_READY: PlayerStatus.Ready,
        };
        _status.value = statesMap[arg1]!;
        break;
    }
  }

  final _playWhenReady = ValueNotifier<bool>(false);

  @override
  bool get playWhenReady => _playWhenReady.value;

  @override
  set playWhenReady(bool value) {
    if (_playWhenReady.value == value) {
      return;
    }
    if (player == nullptr) {
      return;
    }
    _playWhenReady.value = value;
    ffplayer_toggle_pause(player);
  }

  @override
  ValueListenable<List<DurationRange>> get buffered => _buffred;

  @override
  Duration get currentTime {
    if (player == nullptr) {
      return const Duration(microseconds: 0);
    }
    return Duration(
      milliseconds: (ffplayer_get_current_position(player) * 1000).ceil(),
    );
  }

  bool _disposed = false;

  @override
  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    final player = this.player;
    if (player != nullptr) {
      this.player = nullptr;
      ffplayer_free_player(player);
    }
    cppInteractPort.close();
  }

  @override
  Duration get duration {
    if (player == nullptr) {
      return const Duration(microseconds: -1);
    }
    return Duration(
      milliseconds: (ffplayer_get_duration(player) * 1000).ceil(),
    );
  }

  @override
  ValueListenable get error => _error;

  @override
  bool get hasError => _error.value != null;

  @override
  bool get isPlaying => playWhenReady && _status.value == PlayerStatus.Ready;

  Listenable? _onStateChanged;

  @override
  Listenable get onStateChanged {
    if (_onStateChanged == null) {
      _onStateChanged = Listenable.merge([_status, _playWhenReady]);
    }
    return _onStateChanged!;
  }

  @override
  ValueListenable<PlayerStatus> get onStatusChanged => _status;

  @override
  void seek(Duration duration) {
    if (player == nullptr) {
      return;
    }
    ffplayer_seek_to_position(player, duration.inMilliseconds / 1000);
  }

  @override
  PlayerStatus get status => _status.value;
}
