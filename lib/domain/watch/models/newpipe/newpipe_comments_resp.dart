import 'package:json_annotation/json_annotation.dart';

part 'newpipe_comments_resp.g.dart';

@JsonSerializable()
class NewPipeCommentsResp {
  final List<NewPipeComment>? comments;
  final String? nextPage;
  final int? commentCount;
  final bool? isDisabled;

  NewPipeCommentsResp({
    this.comments,
    this.nextPage,
    this.commentCount,
    this.isDisabled,
  });

  factory NewPipeCommentsResp.fromJson(Map<String, dynamic> json) =>
      _$NewPipeCommentsRespFromJson(json);

  Map<String, dynamic> toJson() => _$NewPipeCommentsRespToJson(this);
}

@JsonSerializable()
class NewPipeComment {
  final String? id;
  final String? text;
  final String? authorName;
  final String? authorUrl;
  final String? authorAvatarUrl;
  final bool? authorVerified;
  final int? likeCount;
  final int? replyCount;
  final bool? isPinned;
  final bool? isHearted;
  final bool? isEdited;
  final String? uploadDate;
  final String? repliesPage;

  NewPipeComment({
    this.id,
    this.text,
    this.authorName,
    this.authorUrl,
    this.authorAvatarUrl,
    this.authorVerified,
    this.likeCount,
    this.replyCount,
    this.isPinned,
    this.isHearted,
    this.isEdited,
    this.uploadDate,
    this.repliesPage,
  });

  factory NewPipeComment.fromJson(Map<String, dynamic> json) =>
      _$NewPipeCommentFromJson(json);

  Map<String, dynamic> toJson() => _$NewPipeCommentToJson(this);
}
