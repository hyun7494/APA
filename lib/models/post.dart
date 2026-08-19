import 'package:flutter/material.dart';

/// 게시글 태그 — board-lib의 category 컬럼.
///
/// 색은 [Rating]과 같은 규칙으로 종이 톤 배경에서 읽히도록 명도를 낮췄다.
enum PostCategory {
  catchReport('CATCH', '조황', Color(0xFF0A7D57)),
  free('FREE', '자유', Color(0xFF245BAD)),
  question('QUESTION', '질문', Color(0xFFA5741F));

  const PostCategory(this.code, this.label, this.color);

  final String code;
  final String label;
  final Color color;

  static PostCategory fromCode(String? code) => PostCategory.values.firstWhere(
    (c) => c.code == code,
    orElse: () => PostCategory.free,
  );
}

/// 게시글 — board-lib의 Post 재사용 (기획서 3-3).
///
/// GET /fishing/board?tag=&regionGroupId=
class Post {
  const Post({
    required this.id,
    required this.category,
    required this.title,
    required this.summary,
    required this.authorNickname,
    required this.createdAt,
    required this.likeCount,
    required this.commentCount,
    required this.hasImage,
    this.regionName,
    this.boardKey = 'ALL',
    this.likedByMe = false,
  });

  final int id;
  final PostCategory category;
  final String title;

  /// 카드 목록에 노출할 본문 요약
  final String summary;

  final String authorNickname;
  final DateTime createdAt;
  final int likeCount;
  final int commentCount;

  /// 사진 첨부 여부 — 카드에 📷 표시
  final bool hasImage;

  /// "부산 기장" — 카드 메타에 태그와 함께 노출
  final String? regionName;

  /// board-lib board_key — 지역그룹명 또는 'ALL'
  final String boardKey;

  final bool likedByMe;

  factory Post.fromJson(Map<String, dynamic> json) => Post(
    id: (json['id'] as num).toInt(),
    category: PostCategory.fromCode(json['category'] as String?),
    title: json['title'] as String? ?? '',
    summary: json['summary'] as String? ?? json['content'] as String? ?? '',
    authorNickname: json['authorNickname'] as String? ?? '익명',
    createdAt:
        DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
    commentCount: (json['commentCount'] as num?)?.toInt() ?? 0,
    hasImage: json['hasImage'] as bool? ?? false,
    regionName: json['regionName'] as String?,
    boardKey: json['boardKey'] as String? ?? 'ALL',
    likedByMe: json['likedByMe'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'category': category.code,
    'title': title,
    'summary': summary,
    'authorNickname': authorNickname,
    'createdAt': createdAt.toIso8601String(),
    'likeCount': likeCount,
    'commentCount': commentCount,
    'hasImage': hasImage,
    'regionName': regionName,
    'boardKey': boardKey,
    'likedByMe': likedByMe,
  };

  Post copyWith({int? likeCount, bool? likedByMe}) => Post(
    id: id,
    category: category,
    title: title,
    summary: summary,
    authorNickname: authorNickname,
    createdAt: createdAt,
    likeCount: likeCount ?? this.likeCount,
    commentCount: commentCount,
    hasImage: hasImage,
    regionName: regionName,
    boardKey: boardKey,
    likedByMe: likedByMe ?? this.likedByMe,
  );
}
