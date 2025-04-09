import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const Mp3InboxApp(),
    );
  }
}

class Mp3InboxApp extends StatefulWidget {
  const Mp3InboxApp({super.key});

  @override
  State<Mp3InboxApp> createState() => _Mp3InboxAppState();
}

class _Mp3InboxAppState extends State<Mp3InboxApp> {
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

  Future<void> _initFolder() async {
    // Request storage permission
    if (await Permission.storage.request().isGranted) {
      final dir = await getApplicationDocumentsDirectory();
      final mp3Dir = Directory('${dir.path}/mp3_inbox');
      if (!await mp3Dir.exists()) {
        await mp3Dir.create(recursive: true);
      }
      _savedDirPath = mp3Dir.path;
      _loadMp3Files();
    }
  }

  Future<bool> _requestStoragePermission() async {
    final status = await Permission.storage.request();
    return status.isGranted;
  }

  void _loadMp3Files() async {
    final dir = Directory(_savedDirPath!);
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
    return Scaffold(
      appBar: AppBar(title: const Text('MP3 Inbox')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'Paste .mp3 file path here...',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.paste),
                  onPressed: () async {
                    final clipboard = await Clipboard.getData(
                      Clipboard.kTextPlain,
                    );
                    _controller.text = clipboard?.text ?? '';

                    setState(() {});
                  },
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: _isValidMp3Path ? _pasteAndSend : null,
              icon: const Icon(Icons.send),
              label: const Text('Send to Inbox'),
            ),
            const Divider(height: 30),
            const Text(
              '📥 Saved MP3s:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: _mp3Files.length,
                itemBuilder: (context, index) {
                  final file = _mp3Files[index];
                  final name = file.path.split('/').last;
                  return ListTile(
                    leading: const Icon(Icons.music_note),
                    title: Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            isPlaying ? Icons.pause : Icons.play_arrow,
                          ),
                          onPressed: () async {
                            if (!isPlaying) {
                              await _audioPlayer.play(
                                DeviceFileSource(file.path),
                              );
                            } else {
                              await _audioPlayer.pause();
                            }
                            setState(() {
                              isPlaying = !isPlaying;
                            });
                          },
                        ),
                        Text(name, maxLines: 3,overflow: TextOverflow.ellipsis,),
                      ],
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
