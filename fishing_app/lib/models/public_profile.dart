import 'post.dart';

/// 공개 프로필 — 게시판에서 작성자를 눌렀을 때 보이는 남의 활동 (계약서 3-10).
///
/// ★ **게시판 활동만 담는다.** 조과 기록·도감·인증샷은 여기 없다 — 약관 10조 2항이
/// "게시판에 따로 공개하지 않는 한 다른 회원에게 노출되지 않는다" 고 알린다.
/// 남의 개인 기록을 프로필이라는 이름으로 흘리면 그 약속을 어기는 것이다.
///
/// 마이페이지([Profile])와 다른 모델인 이유가 그것이다 — 내 것과 남의 것은 보여 줄
/// 범위가 다르다. 한 모델로 합치면 언젠가 남의 화면에 내 것만 보이던 값이 샌다.
class PublicProfile {
  const PublicProfile({
    required this.userId,
    required this.nickname,
    required this.postCount,
    required this.commentCount,
    required this.likesReceived,
    required this.recentPosts,
    this.firstPostAt,
  });

  final int userId;

  /// 그 사람 글에 박힌 이름. 닉네임은 유일하고 회수되지 않아 스냅샷이 곧 현재 이름이다.
  final String nickname;

  final int postCount;
  final int commentCount;
  final int likesReceived;

  /// 첫 글 작성 시각. "언제부터 활동했나" 가 신뢰의 단서다.
  final DateTime? firstPostAt;

  /// 최신순. 전부가 아니라 잘라서 온다 — 프로필은 목록 화면이 아니다.
  final List<Post> recentPosts;

  factory PublicProfile.fromJson(Map<String, dynamic> json) => PublicProfile(
    userId: (json['userId'] as num?)?.toInt() ?? 0,
    nickname: json['nickname'] as String? ?? '익명',
    postCount: (json['postCount'] as num?)?.toInt() ?? 0,
    commentCount: (json['commentCount'] as num?)?.toInt() ?? 0,
    likesReceived: (json['likesReceived'] as num?)?.toInt() ?? 0,
    firstPostAt: DateTime.tryParse(json['firstPostAt'] as String? ?? ''),
    recentPosts:
        (json['recentPosts'] as List?)
            ?.map((e) => Post.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [],
  );

  /// 탈퇴한 사람인가. 서버가 글쓴이를 `탈퇴한 사용자 a3f9` 로 바꿔 두므로 그걸 읽는다.
  ///
  /// ⚠️ app-fishing 은 auth 를 부르지 않아 **계정 상태를 직접 알 수 없다.**
  /// 이름으로 판정하는 것이 어설퍼 보이지만, 그 이름을 만든 것도 서버라 어긋나지 않는다.
  /// 서비스 경계를 지키는 값이 이 어설픔보다 크다.
  static const withdrawnPrefix = '탈퇴한 사용자';

  bool get isWithdrawn => nickname.startsWith(withdrawnPrefix);
}
