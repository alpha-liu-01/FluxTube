// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'newpipe_comments_resp.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

NewPipeCommentsResp _$NewPipeCommentsRespFromJson(Map<String, dynamic> json) =>
    NewPipeCommentsResp(
      comments: (json['comments'] as List<dynamic>?)
          ?.map((e) => NewPipeComment.fromJson(e as Map<String, dynamic>))
          .toList(),
      nextPage: json['nextPage'] as String?,
      commentCount: (json['commentCount'] as num?)?.toInt(),
      isDisabled: json['isDisabled'] as bool?,
    );

Map<String, dynamic> _$NewPipeCommentsRespToJson(
        NewPipeCommentsResp instance) =>
    <String, dynamic>{
      'comments': instance.comments,
      'nextPage': instance.nextPage,
      'commentCount': instance.commentCount,
      'isDisabled': instance.isDisabled,
    };

NewPipeComment _$NewPipeCommentFromJson(Map<String, dynamic> json) =>
    NewPipeComment(
      id: json['id'] as String?,
      text: json['text'] as String?,
      authorName: json['authorName'] as String?,
      authorUrl: json['authorUrl'] as String?,
      authorAvatarUrl: json['authorAvatarUrl'] as String?,
      authorVerified: json['authorVerified'] as bool?,
      likeCount: (json['likeCount'] as num?)?.toInt(),
      replyCount: (json['replyCount'] as num?)?.toInt(),
      isPinned: json['isPinned'] as bool?,
      isHearted: json['isHearted'] as bool?,
      isEdited: json['isEdited'] as bool?,
      uploadDate: json['uploadDate'] as String?,
      repliesPage: json['repliesPage'] as String?,
    );

Map<String, dynamic> _$NewPipeCommentToJson(NewPipeComment instance) =>
    <String, dynamic>{
      'id': instance.id,
      'text': instance.text,
      'authorName': instance.authorName,
      'authorUrl': instance.authorUrl,
      'authorAvatarUrl': instance.authorAvatarUrl,
      'authorVerified': instance.authorVerified,
      'likeCount': instance.likeCount,
      'replyCount': instance.replyCount,
      'isPinned': instance.isPinned,
      'isHearted': instance.isHearted,
      'isEdited': instance.isEdited,
      'uploadDate': instance.uploadDate,
      'repliesPage': instance.repliesPage,
    };
