import 'package:get/get.dart';
import 'package:just_audio/just_audio.dart';

class AudioController {
  static final AudioController _instance = AudioController._internal();
  RxInt currentIndex=(0).obs;
  factory AudioController() => _instance;

  AudioController._internal();

  final AudioPlayer player = AudioPlayer();
 

Rxn<UriAudioSource> currentUriAudioSource = Rxn<UriAudioSource>();





}
