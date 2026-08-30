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
    this.photoUrl,
    this.regionName,
    this.regionGroupId,
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

  /// 붙인 사진. 없으면 null 이고 카드는 사진 자리를 만들지 않는다.
  /// **공개 경로**(`/fishing/board/photos/...`)라 비로그인도 볼 수 있다.
  final String? photoUrl;

  /// "부산 기장" — 카드 메타에 태그와 함께 노출
  final String? regionName;

  /// 어느 권역 게시판인가. null 이면 전체다.
  final int? regionGroupId;

  /// board-lib board_key — 지역그룹명 또는 'ALL'
  final String boardKey;

  final bool likedByMe;

  /// "2시간 전", "어제" 같은 상대 시간.
  ///
  /// 게시판 카드와 홈의 최근 조황이 같은 표기를 써야 한다 — 한쪽만 고치면
  /// 같은 글이 화면에 따라 다른 시각으로 보인다.
  String get relativeTime {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return '방금';
    if (diff.inHours < 1) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    if (diff.inDays == 1) return '어제';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return '${createdAt.month}월 ${createdAt.day}일';
  }

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
    photoUrl: json['photoUrl'] as String?,
    regionName: json['regionName'] as String?,
    regionGroupId: (json['regionGroupId'] as num?)?.toInt(),
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
    'photoUrl': photoUrl,
    'regionName': regionName,
    'regionGroupId': regionGroupId,
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
    regionGroupId: regionGroupId,
    boardKey: boardKey,
    likedByMe: likedByMe ?? this.likedByMe,
  );
}
