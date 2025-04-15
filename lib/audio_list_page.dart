// ignore_for_file: prefer_interpolation_to_compose_strings, use_build_context_synchronously, unused_field, sort_child_properties_last
import 'dart:async';
import 'dart:io';
import 'package:clipboard/audio_controller.dart';
import 'package:clipboard/mini_player.dart';
import 'package:clipboard/premium.dart';
import 'package:clipboard/print_helper.dart';
import 'package:clipboard/theme_controller.dart';
import 'package:file_picker/file_picker.dart'
    show FilePicker, FilePickerResult, FileType;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get/get_state_manager/get_state_manager.dart';
import 'package:google_speech/google_speech.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:stack_trace/stack_trace.dart';
import 'package:path/path.dart' as p;

class AudioListPage extends StatefulWidget {
  const AudioListPage({super.key});

  @override
  State<AudioListPage> createState() => _AudioListPageState();
}

class _AudioListPageState extends State<AudioListPage>
    with WidgetsBindingObserver {
  late AudioController audioController;

  int titleEditIndex = 1;
  bool isEditing = false;

  Duration? _duration;
  Duration? _position;

  final TextEditingController _controller = TextEditingController();
  final ThemeController themeController = Get.find();
  bool isPlaying = false;

  List<FileSystemEntity> _mp3Files = [];

  final _playlist = ConcatenatingAudioSource(children: [  ], );
  String? _savedDirPath;
  String clipboardContent = '';
  String message = '';
  final Set<int> selectedIndices = {};

  // Lifecycle & Initialization

  @override
  void initState() {
    super.initState();
    audioController = Get.put(AudioController());
    _initFolder();
    loadPlaylist();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _initFolder() async {
    if (await Permission.storage.request().isGranted) {
      final dir = await getApplicationDocumentsDirectory();
      final mp3Dir = Directory('${dir.path}/democlipboard');

      if (!await mp3Dir.exists()) {
        await mp3Dir.create(recursive: true);
      }
      String _savedDirPath = mp3Dir.path;
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Storage permission denied")));
    }
  }

  void loadPlaylist() async {
    _playlist.clear();
    final audioSources = await convertToAudioSources();
    _playlist.addAll(audioSources);
    PrintHelper.debugPrintWithLocation(
      "PlayList Length  " + _playlist.length.toString(),
    );
    setState(() {});
  }

  Future<void> _pickAndPlayMP3() async {
    showLoadingDialog(context);

    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['mp3'],
    );

    if (result != null && result.files.isNotEmpty) {
      for (var file in result.files) {
        PrintHelper.debugPrintWithLocation(file.path.toString());
        final filePath = file.path;
        if (filePath == null) continue;

        final fileExtension = filePath.split('.').last.toLowerCase();
        if (fileExtension != 'mp3') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Please select only valid MP3 files')),
          );
          continue;
        }

        String fileName = file.name;
        debugPrintWithLocation("Picked File Path: $filePath");
        await copyToAppFolder(filePath, fileName);
      }
      loadPlaylist();
    } else {
      debugPrintWithLocation('No files selected');
    }

    hideLoadingDialog(context);
  }

  Future<void> copyToAppFolder(String sourcePath, String fileName) async {
    final directory = await getExternalStorageDirectory(); // app-specific
    final newPath = '${directory!.path}/$fileName';
    final sourceFile = File(sourcePath);
    await sourceFile.copy(newPath);
    print("Saved to: $newPath");
  }

  Future<List<File>> getAllMP3Files() async {
    final directory = await getExternalStorageDirectory(); // App-specific dir
    final files = directory!.listSync();

    return files.whereType<File>().where((file) {
      final ext = p.extension(file.path).toLowerCase();
      return ext == '.mp3';
    }).toList();
  }

  Future<List<AudioSource>> convertToAudioSources() async {
    final mp3Files = await getAllMP3Files();

    return mp3Files.map((file) {
      final fileName = p.basename(file.path);
      final uri = Uri.file(file.path);
      final mediaItem = MediaItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: fileName,
        artist: "Unknown Artist",
        artUri: Uri.parse(
          'https://images.unsplash.com/photo-1519874179391-3ebc752241dd?q=80&w=2070&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D', // You can replace this with actual album art URL
        ),
      );
      return AudioSource.uri(uri, tag: mediaItem);
    }).toList();
  }

  Future<void> renameFileInAppFolder(
    String oldFileName,
    String newFileName,
  ) async {
    final directory = await getExternalStorageDirectory(); // app-specific dir
    final oldPath = '${directory!.path}/$oldFileName';
    final newPath = '${directory.path}/$newFileName';

    final oldFile = File(oldPath);

    if (await oldFile.exists()) {
      final renamedFile = await oldFile.rename(newPath);
      print("Renamed to: ${renamedFile.path}");
    } else {
      print("File not found: $oldPath");
    }
  }

  File? _pickedFile;

  bool get _isValidMp3Path {
    final path = clipboardContent;
    return path.endsWith('.mp3') && File(path).existsSync();
  }

  void _toggleSelection(int index) {
    setState(() {
      if (selectedIndices.contains(index)) {
        selectedIndices.remove(index);
      } else {
        selectedIndices.add(index);
      }
    });
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

  void _clearSelection() {
    setState(() => selectedIndices.clear());
  }

  void _shareSelectedItems() {
    if (selectedIndices.isEmpty) return;

    final selectedSources = selectedIndices.map(
      (i) => _playlist.children[i] as UriAudioSource,
    );
    final filePaths =
        selectedSources
            .map((source) => File(source.uri.toFilePath()))
            .where((file) => file.existsSync())
            .map((file) => file.path)
            .toList();

    Share.shareXFiles(
      filePaths.map((path) => XFile(path)).toList(),
      text: 'Check out these MP3s!',
    );
    selectedIndices.clear();
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

  void showLoadingDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent closing by tapping outside
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Center(child: CircularProgressIndicator()),
        );
      },
    );
  }

  void hideLoadingDialog(BuildContext context) {
    Navigator.of(context, rootNavigator: true).pop(); // Closes the dialog
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _clearSelection,
      child: Scaffold(
        appBar: AppBar(
          //          backgroundColor: Colors.white,
          actions: [
            Obx(
              () => Switch(
                value: themeController.isDarkMode,
                onChanged: themeController.toggleTheme,
              ),
            ),
          ],
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
                      icon: Icon(Icons.share, color: Colors.amber),
                      onPressed: _shareSelectedItems,
                    ),
                  IconButton(
                    icon: Icon(Icons.upload_rounded, color: Colors.amber),
                    onPressed: () {
                      _pickAndPlayMP3();
                    },
                  ),
                  if (_isValidMp3Path)
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.paste, color: Colors.amber),
                    ),
                  IconButton(
                    icon: Icon(CupertinoIcons.settings, color: Colors.amber),
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
        body:
            _playlist.children.isEmpty
                ? Center(
                  child: SizedBox(
                    child: Text(
                      "No Audio Found",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 30,
                      ),
                    ),
                  ),
                )
                : Column(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: ListView.builder(
                          itemCount: _playlist.children.length,
                          itemBuilder: (context, index) {
                            final source =
                                _playlist.children[index] as UriAudioSource;
                            final mediaItem = source.tag as MediaItem;
                            final sourcePath = source.uri.toString();
                            final isSelected = selectedIndices.contains(index);
                            return GestureDetector(
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 20),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color:
                                        isSelected && themeController.isDarkMode
                                            ? Colors.yellow
                                            : isSelected &&
                                                !themeController.isDarkMode
                                            ? Colors.yellow
                                            : Colors.grey.shade900,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: SizedBox(
                                            child: GestureDetector(
                                              onDoubleTap: () {
                                                setState(() {
                                                  isEditing = !isEditing;
                                                  titleEditIndex =
                                                      isEditing ? index : -1;

                                                  _controller.text = mediaItem
                                                      .title
                                                      .replaceAll(".mp3", "");
                                                });
                                              },
                                              child:
                                                  isEditing &&
                                                          titleEditIndex ==
                                                              index
                                                      ? TextField(
                                                        controller: _controller,
                                                        autofocus: true,
                                                        onSubmitted: (
                                                          data,
                                                        ) async {
                                                          setState(() {
                                                            isEditing = false;
                                                            titleEditIndex = -1;
                                                          });

                                                          // Step 1: Decode percent-encoded path and remove 'file://'
                                                          String rawOldPath =
                                                              Uri.decodeFull(
                                                                sourcePath,
                                                              ).replaceFirst(
                                                                'file://',
                                                                '',
                                                              );
                                                          String newFileName =
                                                              '$data.mp3';
                                                          String rawNewPath =
                                                              rawOldPath
                                                                  .replaceFirst(
                                                                    mediaItem
                                                                        .title,
                                                                    newFileName,
                                                                  );

                                                          final oldFile = File(
                                                            rawOldPath,
                                                          );

                                                          if (await oldFile
                                                              .exists()) {
                                                            await oldFile
                                                                .rename(
                                                                  rawNewPath,
                                                                );
                                                            print(
                                                              "Renamed to: $rawNewPath",
                                                            );
                                                            loadPlaylist(); // refresh UI
                                                          } else {
                                                            print(
                                                              "File does not exist: $rawOldPath",
                                                            );
                                                          }
                                                        },
                                                      )
                                                      : Text(
                                                        mediaItem.title
                                                            .replaceAll(
                                                              '.mp3',
                                                              '',
                                                            ),
                                                        maxLines: 1,
                                                        overflow:
                                                            TextOverflow
                                                                .ellipsis,
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 19,
                                                        ),
                                                      ),
                                            ),
                                          ),
                                        ),

                                        StreamBuilder<PlayerState>(
                                          stream:
                                              audioController
                                                  .player
                                                  .playerStateStream,
                                          builder: (context, snapshot) {
                                            final playerState = snapshot.data;
                                            final playing =
                                                playerState?.playing ?? false;

                                            if (audioController
                                                        .currentIndex
                                                        .value ==
                                                    index &&
                                                playing) {
                                              return ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                  padding: EdgeInsets.zero,
                                                  backgroundColor: Colors.white,
                                                  foregroundColor: Colors.black,
                                                  elevation: 1,
                                                ),
                                                child: Row(
                                                  children: [
                                                    const Icon(Icons.pause),
                                                    Text("Play"),
                                                  ],
                                                ),
                                                onPressed:
                                                    audioController
                                                        .player
                                                        .pause,
                                              );
                                            } else if (audioController
                                                        .currentIndex
                                                        .value ==
                                                    index &&
                                                !playing) {
                                              return ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                  padding: EdgeInsets.zero,
                                                  backgroundColor: Colors.white,
                                                  foregroundColor: Colors.black,
                                                  elevation: 1,
                                                ),
                                                child: Row(
                                                  children: [
                                                    const Icon(
                                                      Icons.play_arrow,
                                                    ),
                                                    Text("Play"),
                                                  ],
                                                ),
                                                onPressed: () {
                                                  audioController.player.play();
                                                },
                                              );
                                            } else {
                                              return ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                  padding: EdgeInsets.zero,
                                                  backgroundColor: Colors.white,
                                                  foregroundColor: Colors.black,
                                                  elevation: 1,
                                                ),
                                                child: Row(
                                                  children: [
                                                    const Icon(
                                                      Icons.play_arrow,
                                                    ),
                                                    Text("Play"),
                                                  ],
                                                ),
                                                onPressed: () {
                                                  audioController
                                                      .currentIndex
                                                      .value = index;
                                                  audioController
                                                      .currentUriAudioSource
                                                      .value = source;
                                                  audioController.player
                                                      .setAudioSource(
                                                        audioController
                                                            .currentUriAudioSource
                                                            .value!,
                                                      );
                                                  audioController.player.play();
                                                  setState(() {});
                                                },
                                              );
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                    Text(sourcePath, maxLines: 1),
                                  ],
                                ),
                              ),

                              onLongPress: () => _toggleSelection(index),
                            );
                          },
                        ),
                      ),
                    ),
                    MiniPlayer(),
                  ],
                ),
      ),
    );
  }

  static void debugPrintWithLocation(String message) {
    final frames = Trace.current().frames;
    if (frames.length > 1) {
      final callerFrame = frames[1];
      print(
        '[${callerFrame.uri.pathSegments.last}:${callerFrame.line}]\n $message',
      );
    } else {
      print(message);
    }
  }
}
