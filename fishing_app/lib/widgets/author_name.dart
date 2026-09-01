import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';

/// 글쓴이 이름 — 누르면 공개 프로필로 간다 (계약서 3-10).
///
/// ⚠️ **링크를 안 거는 경우가 둘이다.**
/// - `authorId` 가 없는 글 — 시드 글처럼 주인이 없다
/// - 탈퇴한 사람 — 이름이 이미 `탈퇴한 사용자 a3f9` 로 가려져 있다. 눌러 봐야 옛 글
///   목록뿐이고, 떠난 사람의 활동을 굳이 모아 보여 줄 이유가 없다
///
/// 둘 다 **누를 수 있는 것처럼 보이지 않아야** 한다 — 눌리는 것과 안 눌리는 것이
/// 같아 보이면 사용자는 앱이 반응을 안 한다고 읽는다.
class AuthorName extends StatelessWidget {
  const AuthorName({
    super.key,
    required this.nickname,
    required this.authorId,
    required this.style,
  });

  final String nickname;
  final int? authorId;
  final TextStyle style;

  bool get _linkable =>
      authorId != null && !nickname.startsWith(PublicProfile.withdrawnPrefix);

  @override
  Widget build(BuildContext context) {
    if (!_linkable) {
      return Text(nickname, style: style, maxLines: 1,
          overflow: TextOverflow.ellipsis);
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => context.push('/users/$authorId'),
      child: Text(
        nickname,
        style: style.copyWith(
          color: AppColors.accentDark,
          fontWeight: FontWeight.w700,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
