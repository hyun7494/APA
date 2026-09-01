import 'post.dart';

/// 글 상세 — `GET /fishing/board/{id}` (계약서 3-6-1).
///
/// [Post]와 나눠 둔 이유는 **본문** 하나다. 목록은 카드용 요약(`summary`)만 받고
/// 본문 전체는 이 화면에서만 받는다 — 글 20개의 본문을 목록에 실어 보낼 이유가 없다.
class PostDetail {
  const PostDetail({
    required this.id,
    required this.category,
    required this.title,
    required this.content,
    required this.authorNickname,
    this.authorId,
    required this.createdAt,
    required this.likeCount,
    required this.commentCount,
    required this.likedByMe,
    this.photoUrl,
    this.regionName,
    this.regionGroupId,
    this.mine = false,
  });

  final int id;
  final PostCategory category;
  final String title;

  /// 요약이 아니라 본문 전체.
  final String content;

  final String authorNickname;

  /// 작성자. 프로필로 넘어가는 데 쓴다 — 이름은 표시용이고 신원은 id 다.
  /// 시드 글처럼 주인이 없는 글은 null 이라 링크를 걸지 않는다.
  final int? authorId;
  final DateTime createdAt;
  final int likeCount;
  final int commentCount;

  /// 내가 좋아요를 눌러 둔 상태인가. 비로그인이면 언제나 false 다.
  final bool likedByMe;

  /// 붙인 사진. **공개 경로**라 비로그인도 볼 수 있다.
  final String? photoUrl;

  /// null 이면 지역을 안 고르고 쓴 글이다. 카드에는 지역 라벨이 안 붙는다.
  final String? regionName;

  /// 고치기 화면이 지역 칩을 되살리는 데 쓴다. 이름으로 되찾으면 이름이 바뀌었을 때
  /// 조용히 다른 권역이 선택된다.
  final int? regionGroupId;

  /// 내가 쓴 글인가. 수정·삭제를 붙일 때 쓸 자리다.
  final bool mine;

  factory PostDetail.fromJson(Map<String, dynamic> json) => PostDetail(
    id: (json['id'] as num).toInt(),
    category: PostCategory.fromCode(json['category'] as String? ?? 'FREE'),
    title: json['title'] as String? ?? '',
    content: json['content'] as String? ?? '',
    authorNickname: json['authorNickname'] as String? ?? '익명',
    authorId: (json['authorId'] as num?)?.toInt(),
    createdAt:
        DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
    commentCount: (json['commentCount'] as num?)?.toInt() ?? 0,
    likedByMe: json['likedByMe'] as bool? ?? false,
    photoUrl: json['photoUrl'] as String?,
    regionName: json['regionName'] as String?,
    regionGroupId: (json['regionGroupId'] as num?)?.toInt(),
    mine: json['mine'] as bool? ?? false,
  );

  /// 좋아요를 누른 직후 화면을 갱신할 때 쓴다. 수와 상태 **둘 다 서버가 준 값**으로 바꾼다 —
  /// 앱에서 +1 하면 그 사이 다른 사람이 누른 것이 빠진다.
  PostDetail withLike({required int likeCount, required bool likedByMe}) =>
      PostDetail(
        id: id,
        category: category,
        title: title,
        content: content,
        authorNickname: authorNickname,
        authorId: authorId,
        createdAt: createdAt,
        likeCount: likeCount,
        commentCount: commentCount,
        likedByMe: likedByMe,
        photoUrl: photoUrl,
        regionName: regionName,
        regionGroupId: regionGroupId,
        mine: mine,
      );
}

/// 댓글 하나 — `GET /fishing/board/{id}/comments`.
class Comment {
  const Comment({
    required this.id,
    required this.authorNickname,
    required this.content,
    required this.createdAt,
    this.mine = false,
  });

  final int id;
  final String authorNickname;
  final String content;
  final DateTime createdAt;

  /// 내가 쓴 댓글인가. 삭제 버튼을 보일지 정하는 값이고, **실제 권한은 서버가 다시 본다.**
  final bool mine;

  factory Comment.fromJson(Map<String, dynamic> json) => Comment(
    id: (json['id'] as num).toInt(),
    authorNickname: json['authorNickname'] as String? ?? '익명',
    content: json['content'] as String? ?? '',
    createdAt:
        DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    mine: json['mine'] as bool? ?? false,
  );
}
