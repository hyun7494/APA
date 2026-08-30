import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/legal_documents.dart';
import '../theme/app_theme.dart';
import '../widgets/async_view.dart';
import '../widgets/reveal.dart';

/// 이용약관·개인정보 처리방침 전문.
///
/// 가입 화면의 `>` 와 고객센터가 같은 화면을 연다 — 두 곳에 따로 그리면 문서가
/// 갈라진다. **셸 밖에 둔다**: 가입 화면(로그인 관문 안쪽)에서도 열려야 하는데
/// 그쪽엔 하단 탭이 없다.
class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, required this.consentType});

  /// `TERMS_OF_SERVICE` 같은 코드. 딥링크로 들어올 수도 있어 모르는 값을 견뎌야 한다.
  final String consentType;

  LegalDocument? get _document {
    for (final doc in readableDocuments) {
      if (doc.consentType == consentType) return doc;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final doc = _document;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 18),
            BackRow(
              label: doc?.title ?? '약관',
              // push 로 열리므로 pop 이 맞다. 스택이 비어 있으면(딥링크) 홈으로 뺀다 —
              // 아무 데도 못 가는 화면이 되면 안 된다.
              onTap: () =>
                  context.canPop() ? context.pop() : context.go('/home'),
            ),
            Expanded(
              child: doc == null
                  ? Center(
                      child: Text('문서를 찾을 수 없어요', style: AppText.body),
                    )
                  : ListView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.screen,
                        20,
                        AppSpacing.screen,
                        40,
                      ),
                      children: [
                        Reveal(
                          child: Text(doc.title, style: AppText.screenTitle),
                        ),
                        const SizedBox(height: 6),
                        Reveal(
                          child: Text(
                            '${doc.version}판',
                            style: AppText.caption,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Reveal(
                          index: 1,
                          child: Text(
                            doc.body.trim(),
                            style: AppText.body.copyWith(height: 1.7),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
