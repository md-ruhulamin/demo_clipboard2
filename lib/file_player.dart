import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:clipboard/audio_controller.dart';
import 'package:clipboard/position_data.dart';
import 'package:clipboard/premium.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:rxdart/rxdart.dart';

class MP3PlayerScreen extends StatefulWidget {
  final ConcatenatingAudioSource playlist;

  const MP3PlayerScreen({super.key, required this.playlist});
  @override
  State<MP3PlayerScreen> createState() => _MP3PlayerScreenState();
}

class _MP3PlayerScreenState extends State<MP3PlayerScreen> {
  final AudioController audioController = AudioController();

  Stream<PositionData> get _positionDataStream =>
      Rx.combineLatest3<Duration, Duration, Duration?, PositionData>(
        audioController.player.positionStream,
        audioController.player.bufferedPositionStream,
        audioController.player.durationStream,
        (position, bufferedPosition, duration) =>
            PositionData(position, bufferedPosition, duration ?? Duration.zero),
      );

  @override
  void initState() {
    super.initState();

    _init();
  }

  Future<void> _init() async {
    await audioController.player.setLoopMode(LoopMode.all);
    await audioController.player.setAudioSource(widget.playlist);
  }

  Future<void> _pickAndPlayMP3() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3'], // only allow .mp3
    );

    if (result != null && result.files.single.path != null) {
      final filePath = result.files.single.path!;
      final fileExtension = filePath.split('.').last.toLowerCase();

      String fileName = result.files.single.name;
      print("Print FIle PAth: " + filePath);
      if (fileExtension != 'mp3') {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Only MP3 files are allowed')));
        return;
      }

      final mediaItem = MediaItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: fileName,
        artist: '1',
        artUri: Uri.parse(
          'https://images.unsplash.com/photo-1519874179391-3ebc752241dd?q=80&w=2070&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
        ),
      );
      final source = AudioSource.uri(Uri.file(filePath), tag: mediaItem);
      setState(() {
        widget.playlist.add(source);
        print("PlayList Length: " + widget.playlist.length.toString());
      });
    } else {
      // User canceled
      print('No file selected');
    }
  }

  @override
  void dispose() {
    audioController.player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print(widget.playlist.length);
    return Scaffold(
      backgroundColor: Colors.blueGrey,
      appBar: AppBar(
        title: Text('MP3 Player'),
        actions: [
          ElevatedButton(onPressed: _pickAndPlayMP3, child: Text('Pick MP3')),
          IconButton(
            icon: Icon(CupertinoIcons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => PremiumUpgradeScreen()),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(height: 20),

            Text(
              widget.playlist.length.toString(),
              style: TextStyle(fontSize: 40, color: Colors.white),
            ),

            StreamBuilder<SequenceState?>(
              stream: audioController.player.sequenceStateStream,

              builder: (context, snapshot) {
                final state = snapshot.data;
                if (state?.sequence.isEmpty ?? true) {
                  return SizedBox();
                }

                final metadata = state!.currentSource!.tag as MediaItem;
                return MediaMetadata(
                  imageUrl: metadata.artUri.toString(),
                  title: metadata.title,
                  artist: metadata.artist ?? '',
                );
              },
            ),

            SizedBox(height: 20),
            StreamBuilder<PositionData>(
              stream: _positionDataStream,
              builder: (context, snapshot) {
                final positionData = snapshot.data;
                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: ProgressBar(
                    progress: positionData?.position ?? Duration.zero,
                    total: positionData?.duration ?? Duration.zero,
                    buffered: positionData?.bufferedPosition ?? Duration.zero,
                    onSeek: audioController.player.seek,
                    barHeight: 5,
                    thumbRadius: 10,
                    baseBarColor: Colors.grey,
                    bufferedBarColor: Colors.white,
                    progressBarColor: Colors.redAccent,
                    thumbColor: Colors.redAccent,
                    timeLabelTextStyle: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              },
            ),

            Controls(),
          ],
        ),
      ),
    );
  }
}

class MediaMetadata extends StatelessWidget {
  final String imageUrl;
  final String title;
  final String artist;
  const MediaMetadata({
    super.key,
    required this.imageUrl,
    required this.title,
    required this.artist,
  });
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            image: DecorationImage(
              image: NetworkImage(imageUrl),
              fit: BoxFit.cover,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              width: 300,
              height: 300,
              fit: BoxFit.cover,
            ),
          ),
        ),
        SizedBox(height: 10),
        Text(
          "${title} ",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        SizedBox(height: 5),
        Text(artist, style: TextStyle(fontSize: 18, color: Colors.white70)),
      ],
    );
  }
}

class Controls extends StatelessWidget {
  Controls({super.key});

  final AudioController audioController = AudioController();
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: () async {
            await audioController.player.seekToPrevious();
          },
          icon: Icon(Icons.skip_previous_rounded, size: 30),
        ),
        StreamBuilder<PlayerState>(
          stream: audioController.player.playerStateStream,
          builder: (BuildContext context, AsyncSnapshot<PlayerState> snapshot) {
            final playerState = snapshot.data;
            final processingState = playerState?.processingState;
            final playing = playerState?.playing;
            if (!(playing ?? false)) {
              return IconButton(
                onPressed: audioController.player.play,
                icon: Icon(Icons.play_arrow_rounded, size: 30),
              );
            } else if (processingState != ProcessingState.completed) {
              return IconButton(
                onPressed: audioController.player.pause,
                icon: Icon(Icons.pause_rounded, size: 30),
              );
            } else {
              return Icon(Icons.replay_rounded);
            }
          },
        ),
        IconButton(
          onPressed: audioController.player.seekToNext,
          icon: Icon(Icons.skip_next_rounded, size: 30),
        ),
      ],
    );
  }
}
