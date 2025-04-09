class AudioCard {
  final String title;
  final String date;
  final String duration;
  final String? transcript;
  final String? size;

  AudioCard({
    required this.title,
    required this.date,
    required this.duration,
    required this.size,
    this.transcript,
  });

  factory AudioCard.fromMap(Map<String, dynamic> map) {
    return AudioCard(
      title: map['title'] ?? '',
      date: map['date'] ?? '',
      size: map['size'] ?? '',
      duration: map['duration'] ?? '',
      transcript: map['transcript'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'size': size,
      'title': title,
      'date': date,
      'duration': duration,
      'transcript': transcript,
    };
  }

  @override
  String toString() {
    return 'AudioCard(title: $title, date: $date, duration: $duration,size:$size transcript: $transcript)';
  }
}
