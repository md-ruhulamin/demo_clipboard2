// ignore_for_file: prefer_interpolation_to_compose_strings, use_build_context_synchronously, unused_field
import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:clipboard/premium.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_speech/google_speech.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

class AudioNotesPage extends StatefulWidget {
  const AudioNotesPage({super.key});

  @override
  State<AudioNotesPage> createState() => _AudioNotesPageState();
}

class _AudioNotesPageState extends State<AudioNotesPage>
    with WidgetsBindingObserver {
//Variables & Controllers


bool isPasted = false;
int playindex = -1;
int titleEditIndex = 1;
bool isEditing = false;

Duration? _duration;
Duration? _position;
PlayerState? _playerState;

final TextEditingController _controller = TextEditingController();
 AudioPlayer _audioPlayer = AudioPlayer();
AudioPlayer get player => _audioPlayer;

bool isPlaying = false;
List<FileSystemEntity> _mp3Files = [];
final Map<String, String> _durations = {};
String? _savedDirPath;
String clipboardContent = '';
String message = '';
final Set<int> selectedIndices = {};



// Lifecycle & Initialization


@override
void initState() {
  super.initState();
  _audioPlayer = AudioPlayer();
  _initStreams();
  player.setReleaseMode(ReleaseMode.stop);

  WidgetsBinding.instance.addPostFrameCallback((_) async {
    await player.setSource(AssetSource('ambient_c_motion.mp3'));
    await player.resume();
  });

  _initFolder();
  pasteFromClipboard();
  WidgetsBinding.instance.addObserver(this);
}

@override
void didChangeAppLifecycleState(AppLifecycleState state) {
  if (state == AppLifecycleState.paused) {
    print("App paused");
  } else if (state == AppLifecycleState.resumed) {
    pasteFromClipboard();
    isPasted = false;
    print("App resumed");
  } else if (state == AppLifecycleState.inactive) {
    print("App inactive");
  } else if (state == AppLifecycleState.detached) {
    print("App detached");
  }
}

@override
void dispose() {
  player.dispose();
  super.dispose();
}


//Audio Player Logic


void handlePlayPause(int index, String filePath) async {
  if (!isPlaying) {
    await _audioPlayer.play(DeviceFileSource(filePath));
    playindex = index;
    isPlaying = true;
  } else if (playindex == index) {
    await _audioPlayer.pause();
    isPlaying = false;
  } else {
    await _audioPlayer.stop();
    await _audioPlayer.play(DeviceFileSource(filePath));
    playindex = index;
    isPlaying = true;
  }

  print("Playing: $filePath");
  setState(() {});
}

void _rewind10() {
  final current = _position ?? Duration.zero;
  player.seek(current - const Duration(seconds: 10));
}

void _forward10() async {
  final currentPosition = await player.getCurrentPosition();
  final duration = await player.getDuration();
  final newPosition = currentPosition! + Duration(seconds: 10);
  await player.seek(newPosition < duration! ? newPosition : duration);
}

 //Stream Listeners
 StreamSubscription? _durationSubscription;
StreamSubscription? _positionSubscription;
StreamSubscription? _playerCompleteSubscription;
StreamSubscription? _playerStateChangeSubscription;

void _initStreams() {
  _durationSubscription = player.onDurationChanged.listen((duration) {
    setState(() => _duration = duration);
  });

  _positionSubscription = player.onPositionChanged.listen((p) {
    setState(() => _position = p);
  });

  _playerCompleteSubscription = player.onPlayerComplete.listen((event) {
    setState(() {
      _playerState = PlayerState.stopped;
      _position = Duration.zero;
    });
  });

  _playerStateChangeSubscription = player.onPlayerStateChanged.listen((state) {
    setState(() {
      _playerState = state;
    });
  });
}
//MP3 File Handling
Future<void> _initFolder() async {
  if (await Permission.storage.request().isGranted) {
    final dir = await getApplicationDocumentsDirectory();
    final mp3Dir = Directory('${dir.path}/mp3_inbox');

    if (!await mp3Dir.exists()) {
      await mp3Dir.create(recursive: true);
    }
    _savedDirPath = mp3Dir.path;
    _loadMp3Files();
  } else {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Storage permission denied")));
  }
}

void _loadMp3Files() async {
  if (_savedDirPath == null) return;
  final dir = Directory(_savedDirPath!);
  final files = dir.listSync().where((file) => file.path.toLowerCase().endsWith('.mp3')).toList();

  setState(() => _mp3Files = files);
  List<String> filePaths = files.map((file) => file.path).toList();
  loadDurations(filePaths);
  printMp3Info(files);
}

void printMp3Info(List<FileSystemEntity> mp3Files) async {
  for (var file in mp3Files) {
    File mp3 = File(file.path);
    String name = mp3.uri.pathSegments.last;
    int sizeInBytes = await mp3.length();
    double sizeInKB = sizeInBytes / 1024;

    print("🎵 File: $name");
    print("DUration: ${await getAudioDuration(mp3.path)}");
    print("📏 Size: ${sizeInKB.toStringAsFixed(2)} KB");
    print("📅 Date: ${mp3.statSync().modified}");
    print("📂 Path: ${file.path}");
    print("------------------------------------------------");
  }
}

Future<Duration?> getAudioDuration(String filePath) async {
  final player = AudioPlayer();
  Completer<Duration?> completer = Completer();
  StreamSubscription? durationSub;

  durationSub = player.onDurationChanged.listen((duration) async {
    await player.dispose();
    durationSub?.cancel();
    completer.complete(duration);
  });

  try {
    await player.setSourceDeviceFile(filePath);
  } catch (e) {
    await player.dispose();
    durationSub.cancel();
    completer.complete(null);
  }

  return completer.future;
}

void loadDurations(List<String> filePaths) async {
  for (var path in filePaths) {
    final duration = await getAudioDuration(path);
    if (duration != null) {
      _durations[path] = formatDurationHHMMSS(duration);
    }
  }
  setState(() {});
}
//Clipboard Integration
void pasteFromClipboard() async {
  final data = await Clipboard.getData('text/plain');
  final content = data?.text ?? '';

  setState(() {
    clipboardContent = content;
    message = _isValidMp3Path ? 'Valid MP3 content' : 'Not an MP3 link/content';
  });
}

bool get _isValidMp3Path {
  final path = clipboardContent;
  return path.endsWith('.mp3') && File(path).existsSync();
}

Future<void> _pasteAndSend() async {
  if (!await Permission.storage.request().isGranted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Storage permission denied")));
    return;
  }

  final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
  final path = clipboardData?.text;

  if (path == null || !path.endsWith(".mp3") || !File(path).existsSync()) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Invalid or non-existent MP3 path")));
    return;
  }

  final filename = path.split("/").last;
  final destination = File('${_savedDirPath!}/$filename');

  await File(path).copy(destination.path);

  setState(() {
    _mp3Files.add(destination);
isPasted = true;
  });

  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("MP3 file added to inbox")));
}
//Speech to Text
final speechToText = SpeechToText.viaToken('Bearer', '<token-here>');
final config = RecognitionConfig(
  encoding: AudioEncoding.LINEAR16,
  model: RecognitionModel.basic,
  enableAutomaticPunctuation: true,
  sampleRateHertz: 16000,
  languageCode: 'en-US',
);

Future<List<int>> _getAudioContent(String name) async {
  final directory = await getApplicationDocumentsDirectory();
  final path = directory.path + '/$name';
  return File(path).readAsBytesSync().toList();
}

void generateTRanscript(String filePath) async {
  final audio = await _getAudioContent(filePath);
  final response = await speechToText.recognize(config, audio);
  print(response);
}
//UI Helpers
void _toggleSelection(int index) {
  setState(() {
    if (selectedIndices.contains(index)) {
      selectedIndices.remove(index);
    } else {
      selectedIndices.add(index);
    }
  });
}

void _clearSelection() {
  setState(() => selectedIndices.clear());
}

void _shareSelectedItems() {
  if (selectedIndices.isEmpty) return;
  final selectedTexts = selectedIndices.map((i) => _mp3Files[i]).join('\n');
  Share.share(selectedTexts);
}

String formatDuration(Duration duration) {
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return "$minutes:$seconds";
}

String formatDurationHHMMSS(Duration duration) {
  final hours = duration.inHours.toString().padLeft(2, '0');
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return "$hours:$minutes:$seconds";
}

String get _durationText => _duration?.toString().split('.').first ?? '0s';
String get _positionText => _position?.toString().split('.').first ?? '0s';

  @override
  Widget build(BuildContext context) {
    //fetchDuration(_mp3Files[0].path);
    print(_mp3Files.length);
    return GestureDetector(
      onTap: _clearSelection,
      child: Scaffold(
        //   backgroundColor: Color(0xFFD7F3FD), // light blue background
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          systemOverlayStyle: SystemUiOverlayStyle.dark,
          //   preferredSize: Size.fromHeight(60),
          title: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                children: [
                  Row(
                    children: [
                      Text(
                        'All iCloud',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  Spacer(),

                  if (selectedIndices.isNotEmpty)
                    IconButton(
                      icon: Icon(Icons.share),
                      onPressed: _shareSelectedItems,
                    ),
                  //   IconButton(icon: Icon(Icons.pending), onPressed: () {}),
                  if (_isValidMp3Path && !isPasted)
                    IconButton(
                      onPressed: () {

                        _pasteAndSend();

                      },
                      icon: const Icon(Icons.paste),
                    ),
                  IconButton(
                    icon: Icon(CupertinoIcons.settings),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PremiumUpgradeScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(15),
                itemCount: _mp3Files.length,
                itemBuilder: (context, index) {
                  final file = _mp3Files[index];
                  final isSelected = selectedIndices.contains(index);
                  return GestureDetector(
                    onLongPress: () => _toggleSelection(index),
                    onTap: () {
                      if (selectedIndices.isNotEmpty) {
                        _toggleSelection(index);
                      }
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isSelected ?Color(0xFFD7F3FD): Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              /// Text section
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    GestureDetector(
                                      onDoubleTap: () {
                                        setState(() {
                                          isEditing = !isEditing;
                                          titleEditIndex =
                                              isEditing ? index : -1;

                                          final fileName =
                                              file.path.split('/').last;
                                          _controller.text = fileName
                                              .replaceAll('.mp3', '');
                                        });
                                      },
                                      child:
                                          isEditing && titleEditIndex == index
                                              ? TextField(
                                                controller: _controller,
                                                autofocus: true,
                                                onSubmitted: (data) {
                                                  setState(() {
                                                    isEditing = false;
                                                    titleEditIndex = -1;

                                                    // Rename the file with .mp3 extension
                                                    file.renameSync(
                                                      '${_savedDirPath!}/$data.mp3',
                                                    );
                                                    _loadMp3Files();
                                                  });
                                                },
                                              )
                                              : Text(
                                                file.path
                                                    .split('/')
                                                    .last
                                                    .replaceAll('.mp3', ''),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 19,
                                                ),
                                              ),
                                    ),

                                    Text(
                                      DateFormat(
                                        'MMMM d, y \'at\' h:mm a',
                                      ).format(file.statSync().modified),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 17,
                                      ),
                                    ),

                                    SizedBox(height: 4),

                                    /// Show position and duration
                                    if (playindex == index)
                                      Text(
                                        _position != null && _duration != null
                                            ? '$_positionText / ${_durations[file.path]!}'
                                            : 'Audio. $_durationText',
                                        style: const TextStyle(fontSize: 17.0),
                                      ),

                                    if (playindex != index)
                                      Text(
                                        _durations.containsKey(file.path)
                                            ? "Audio.${_durations[file.path]!}"
                                            : "Loading...",
                                        style: const TextStyle(fontSize: 17.0),
                                      ),
                                  ],
                                ),
                              ),

                              /// Controls
                              playindex == index
                                  ? Column(
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            onPressed: _rewind10,
                                            icon: const Icon(Icons.replay_10),
                                            iconSize: 30,
                                            color: Colors.cyan,
                                          ),
                                          IconButton(
                                            onPressed:
                                                () => handlePlayPause(
                                                  index,
                                                  file.path,
                                                ),
                                            icon:
                                                isPlaying
                                                    ? Icon(Icons.pause)
                                                    : Icon(Icons.play_arrow),
                                            iconSize: 30,
                                            color: Colors.cyan,
                                          ),
                                          IconButton(
                                            onPressed: _forward10,
                                            icon: const Icon(Icons.forward_10),
                                            iconSize: 30,
                                            color: Colors.cyan,
                                          ),
                                        ],
                                      ),
                                    ],
                                  )
                                  : SizedBox(
                                    height: 35,
                                    width: 70,
                                    child: ElevatedButton(
                                      onPressed: () {
                                        handlePlayPause(index, file.path);
                                      },
                                      style: ElevatedButton.styleFrom(
                                        padding: EdgeInsets.zero,
                                        backgroundColor: Colors.white,
                                        foregroundColor: Colors.black,
                                        elevation: 1,
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.play_arrow, size: 20),
                                          SizedBox(width: 5),
                                          Text('Play'),
                                        ],
                                      ),
                                    ),
                                  ),
                            ],
                          ),
                          if (playindex == index)
                            const Divider(height: 20, color: Colors.grey),
                          if (playindex == index)
                            Text(
                              'Transcript ...',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.cyan,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

}
