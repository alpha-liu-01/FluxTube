import 'dart:convert';

class LocalPlaylist {
  final String id;
  final String name;
  final String description;
  final List<String> videoIds;
  final List<String> videoTitles;
  final List<String> thumbnailUrls;
  final List<String> channelNames;
  final List<String> channelIds;
  final DateTime createdAt;

  LocalPlaylist({
    required this.id,
    required this.name,
    this.description = '',
    List<String>? videoIds,
    List<String>? videoTitles,
    List<String>? thumbnailUrls,
    List<String>? channelNames,
    List<String>? channelIds,
    DateTime? createdAt,
  })  : videoIds = videoIds ?? [],
        videoTitles = videoTitles ?? [],
        thumbnailUrls = thumbnailUrls ?? [],
        channelNames = channelNames ?? [],
        channelIds = channelIds ?? [],
        createdAt = createdAt ?? DateTime.now();

  LocalPlaylist copyWith({
    String? name,
    String? description,
    List<String>? videoIds,
    List<String>? videoTitles,
    List<String>? thumbnailUrls,
    List<String>? channelNames,
    List<String>? channelIds,
  }) {
    return LocalPlaylist(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      videoIds: videoIds ?? this.videoIds,
      videoTitles: videoTitles ?? this.videoTitles,
      thumbnailUrls: thumbnailUrls ?? this.thumbnailUrls,
      channelNames: channelNames ?? this.channelNames,
      channelIds: channelIds ?? this.channelIds,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'description': description,
        'videoIds': jsonEncode(videoIds),
        'videoTitles': jsonEncode(videoTitles),
        'thumbnailUrls': jsonEncode(thumbnailUrls),
        'channelNames': jsonEncode(channelNames),
        'channelIds': jsonEncode(channelIds),
        'createdAt': createdAt.toIso8601String(),
      };

  factory LocalPlaylist.fromMap(Map<String, dynamic> map) {
    List<String> asList(dynamic value) {
      try {
        if (value is String) {
          if (value.isEmpty) return [];
          return (jsonDecode(value) as List).cast<String>();
        }
        return (value as List?)?.cast<String>() ?? [];
      } catch (_) {
        return [];
      }
    }

    final videoIds = asList(map['videoIds']);

    // Playlists saved by older builds may not carry every metadata list, and a
    // short list would otherwise shift metadata onto the wrong videos. Pad to
    // match videoIds so all the lists stay index-aligned.
    List<String> aligned(dynamic value) {
      final list = asList(value);
      if (list.length == videoIds.length) return list;
      if (list.length > videoIds.length) return list.sublist(0, videoIds.length);
      return [...list, ...List.filled(videoIds.length - list.length, '')];
    }

    return LocalPlaylist(
      id: map['id'] as String,
      name: map['name'] as String,
      description: (map['description'] as String?) ?? '',
      videoIds: videoIds,
      videoTitles: aligned(map['videoTitles']),
      thumbnailUrls: aligned(map['thumbnailUrls']),
      channelNames: aligned(map['channelNames']),
      channelIds: aligned(map['channelIds']),
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
