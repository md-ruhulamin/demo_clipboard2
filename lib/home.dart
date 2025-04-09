// ignore_for_file: prefer_interpolation_to_compose_strings

import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:demo_clipboard/audio_card.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class AudioNotesPage extends StatefulWidget {
  @override
  State<AudioNotesPage> createState() => _AudioNotesPageState();
}

class _AudioNotesPageState extends State<AudioNotesPage> {
  final List<AudioCard> audioNotes = [];
  int playindex = -1;
  final TextEditingController _controller = TextEditingController();

  List<FileSystemEntity> _mp3Files = [];

  String? _savedDirPath;

  AudioPlayer _audioPlayer = AudioPlayer();

  bool isPlaying = false;

  @override
  void initState() {
    super.initState();
    _initFolder();
  }

  void printMp3Info(List<FileSystemEntity> mp3Files) async {
    print("IN info Function" + mp3Files.toString());
    for (var file in mp3Files) {
      File mp3 = File(file.path);
      // File name
      String name = mp3.uri.pathSegments.last;
      // File size in KB
      int sizeInBytes = await mp3.length();
      double sizeInKB = sizeInBytes / 1024;
      // Duration (requires plugin)
      print("🎵 File: $name");
      print("📏 Size: ${sizeInKB.toStringAsFixed(2)} KB");
      print("📅 Date: ${mp3.statSync().modified}");
      print("📂 Path: ${file.path}");
      print("------------------------------------------------");
    }
    File mp3 = File(mp3Files.last.path);
    int sizeInBytes = await mp3.length();
    double sizeInMB = sizeInBytes / (1024 * 1024);

    audioNotes.add(
      AudioCard(
        title: mp3.uri.pathSegments.last,
        date: "${mp3.statSync().modified}",
        size: sizeInMB.toStringAsFixed(2).toString(),
        duration: '',
        transcript: null,
      ),
    );

  }

  void handlePlayPause(int index, String filePath) async {
    if (!isPlaying) {
      // Nothing is playing — play selected audio
      await _audioPlayer.play(DeviceFileSource(filePath));
      playindex = index;
      isPlaying = true;
    } else if (playindex == index) {
      // Tapped same audio again — pause it
      await _audioPlayer.pause();
      isPlaying = false;
      playindex = -1;
    } else {
      // Another audio is playing — stop it and play new one
      await _audioPlayer.stop();
      await _audioPlayer.play(DeviceFileSource(filePath));
      playindex = index;
      isPlaying = true;
    }
    setState(() {});
  }

  Future<void> _initFolder() async {
    // Request storage permission
    if (await Permission.storage.request().isGranted) {
      final dir = await getApplicationDocumentsDirectory();
      final mp3Dir = Directory('${dir.path}/mp3_inbox');
      print(mp3Dir.path);
      // Check if the directory exists
      // If not, create it
      // If it does, do nothing
      // This is where you can add your logic to check if the directory exists
      // and create it if necessary
      // For example:
      // final dir = Directory('/path/to/directory');
      // final dir = Directory('/storage/emulated/0/Download');
      // final dir = Directory('/storage/emulated/0/Download/mp3_inbox');
 
      if (!await mp3Dir.exists()) {
        await mp3Dir.create(recursive: true);
      }
      _savedDirPath = mp3Dir.path;
      setState(() {
        _loadMp3Files();
      });
    }
  }

  Future<bool> _requestStoragePermission() async {
    final status = await Permission.storage.request();
    return status.isGranted;
  }

  void _loadMp3Files() async {
    final dir = Directory(_savedDirPath!);
    print("Line 122: "+dir.path);
    final files = dir.listSync().where((f) => f.path.endsWith('.mp3')).toList();
    setState(() => _mp3Files = files);
  }

  Future<void> _pasteAndSend() async {
    final hasPermission = await _requestStoragePermission();
    if (!hasPermission) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Storage permission denied")));
      return;
    }
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);

    if (clipboardData == null || clipboardData.text == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Clipboard is empty or doesn't contain text")),
      );
      return;
    }

    final path = clipboardData.text!;

    if (!path.endsWith(".mp3")) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Only .mp3 files are allowed")));
      return;
    }

    final sourceFile = File(path);
    if (!await sourceFile.exists()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("File does not exist at this path")),
      );
      return;
    }

    final dir =
        await getApplicationDocumentsDirectory(); // Or any other local directory
    final filename = path.split("/").last;
    final destination = File('${dir.path}/$filename');
    await sourceFile.copy(destination.path);

    setState(() {
      _mp3Files.add(File(destination.path));
    
      printMp3Info(_mp3Files);
      //  
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text("MP3 file added to inbox")));
  }

  bool get _isValidMp3Path {
    final path = _controller.text;
    return path.endsWith('.mp3') && File(path).existsSync();
  }

  @override
  Widget build(BuildContext context) {
    print(_mp3Files.length);
    print(audioNotes.length);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(60),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    // Handle back action
                  },
                  child: Row(
                    children: [
                      Icon(Icons.arrow_back_ios, size: 18),
                      Text(
                        'All iCloud',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Spacer(),
                IconButton(
                  icon: Icon(CupertinoIcons.arrow_counterclockwise_circle),
                  onPressed: () {},
                ),
                IconButton(
                  icon: Icon(CupertinoIcons.arrow_clockwise_circle),
                  onPressed: () {},
                ),
                IconButton(icon: Icon(CupertinoIcons.share), onPressed: () {}),
                IconButton(icon: Icon(Icons.pending), onPressed: () {}),
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
              itemCount: audioNotes.length,
              itemBuilder: (context, index) {
                final file = _mp3Files[index];
                final note = audioNotes[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              note.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),

                            Text(
                              '${note.date}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 13,
                              ),
                            ),
                            Text('${note.size}MB'),
                          ],
                        ),
                      ),
                      SizedBox(
                        height: 35,
                        width: 70,
                        child: ElevatedButton(
                          onPressed: () => handlePlayPause(index, file.path),

                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            elevation: 1,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isPlaying && index == playindex
                                    ? Icons.pause
                                    : Icons.play_arrow,
                              ),
                              SizedBox(width: 5),
                              Text('Play'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'Paste .mp3 file path here...',
                suffixIcon:
                    _isValidMp3Path
                        ? IconButton(
                          onPressed: () {
                            _pasteAndSend();
                            _controller.clear();
                          },
                          icon: Icon(Icons.done),
                        )
                        : IconButton(
                          icon: Icon(Icons.paste),
                          onPressed: () async {
                            final clipboard = await Clipboard.getData(
                              Clipboard.kTextPlain,
                            );
                            _controller.text = clipboard?.text ?? '';

                            setState(() {});
                          },
                        ),
              ),
              onChanged:
                  (_) => setState(() {
                    print(_isValidMp3Path);
                  }),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white,
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.menu, color: Colors.amber),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.attach_file, color: Colors.amber),
            label: 'Search',
          ),
          BottomNavigationBarItem(
            icon: Icon(
              CupertinoIcons.rectangle_expand_vertical,
              color: Colors.amber,
            ),
            label: 'Add',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.pencil_outline, color: Colors.amber),
            label: 'Settings',
          ),
        ],
        onTap: (index) {
          // Handle bottom navigation tap
        },
      ),
    );
  }
}
