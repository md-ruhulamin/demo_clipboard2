import 'package:clipboard/audio_controller.dart';
import 'package:clipboard/file_player.dart';
import 'package:clipboard/position_data.dart';
import 'package:clipboard/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get_state_manager/get_state_manager.dart';
import 'package:get/get_state_manager/src/simple/get_state.dart';

import 'package:get/instance_manager.dart';
import 'package:get/route_manager.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';

class MiniPlayer extends StatefulWidget {

  MiniPlayer({ super.key});

  @override
  State<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer> {
  late AudioController audioController;
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
    audioController = Get.put(AudioController());
    super.initState();
   // _init();
  }
  final ThemeController themeController = Get.find();
  // Future<void> _init() async {
  //   await audioController.player.setLoopMode(LoopMode.all);

  //   setState(() {});
  // }

  @override
  Widget build(BuildContext context) {
    final mediaItem = audioController.player.sequenceState?.currentSource?.tag;

    if (mediaItem == null) return const SizedBox();

    return Obx(()=>
       Container(
        height: 140,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
         color:themeController.isDarkMode? Colors.black:Colors.white,
          boxShadow: [BoxShadow(blurRadius: 6, color: Colors.black12)
          
          ],
          borderRadius: BorderRadius.circular(8),
          border: Border(
            top: BorderSide(
              color:themeController.isDarkMode? Colors.grey.shade700:Colors.white,
              width: 1,
            ),
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.audiotrack, size: 60),
                const SizedBox(width: 5),
      
                /// Title & Artist
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      StreamBuilder<PositionData>(
                        stream: _positionDataStream,
                        builder: (context, snapshot) {
                          final positionData = snapshot.data;
      
                          if (positionData == null) {
                            return const LinearProgressIndicator();
                          }
      
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              Text(
                                audioController
                                    .player
                                    .sequenceState
                                    ?.currentSource
                                    ?.tag
                                    .title,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Slider(
                                activeColor: Colors.deepPurple,
                                inactiveColor: Colors.grey[300],
                                min: 0.0,
                                max:
                                    positionData.duration.inMilliseconds
                                        .toDouble(),
                                value:
                                    positionData.position.inMilliseconds
                                        .clamp(
                                          0,
                                          positionData.duration.inMilliseconds,
                                        )
                                        .toDouble(),
                                onChanged: (value) {
                                  audioController.player.seek(
                                    Duration(milliseconds: value.toInt()),
                                  );
                                },
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    formatDurationHHMMSS(positionData.position),
                                  ),
                                  Row(
                                    children: [
                                      /// Rewind 10 seconds
                                      IconButton(
                                        icon: const Icon(Icons.replay_10),
                                        onPressed: () async {
                                          final currentPosition =
                                              await audioController
                                                  .player
                                                  .position;
                                          final newPosition =
                                              currentPosition -
                                              const Duration(seconds: 10);
                                          audioController.player.seek(
                                            newPosition >= Duration.zero
                                                ? newPosition
                                                : Duration.zero,
                                          );
                                        },
                                      ),
      
                                      /// Play / Pause Button
                                      StreamBuilder<PlayerState>(
                                        stream:
                                            audioController
                                                .player
                                                .playerStateStream,
                                        builder: (context, snapshot) {
                                          final playerState = snapshot.data;
                                          final playing =
                                              playerState?.playing ?? false;
      
                                          if (playing) {
                                            return IconButton(
                                              icon: const Icon(Icons.pause),
                                              onPressed:
                                                  audioController.player.pause,
                                            );
                                          } else {
                                            return IconButton(
                                              icon: const Icon(Icons.play_arrow),
                                              onPressed:
                                                  audioController.player.play,
                                            );
                                          }
                                        },
                                      ),
      
                                      /// Forward 10 seconds
                                      IconButton(
                                        icon: const Icon(Icons.forward_10),
                                        onPressed: () async {
                                          final currentPosition =
                                              await audioController
                                                  .player
                                                  .position;
                                          final duration =
                                              await audioController
                                                  .player
                                                  .duration ??
                                              Duration.zero;
                                          final newPosition =
                                              currentPosition +
                                              const Duration(seconds: 10);
                                          audioController.player.seek(
                                            newPosition <= duration
                                                ? newPosition
                                                : duration,
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                  Text(
                                    formatDurationHHMMSS(positionData.duration),
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String formatDurationHHMMSS(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$hours:$minutes:$seconds";
  }
}
