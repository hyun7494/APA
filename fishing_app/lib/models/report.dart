/// 신고 사유 — `POST /fishing/board/{id}/report` (계약서 3-8).
///
/// 자유 입력이 아니라 목록으로 받는다. 나중에 운영 도구가 "이 글에 스팸 신고 5건"
/// 처럼 세고 정렬할 수 있어야 하기 때문이다. 코드는 서버 `ReportReason` 과 1:1 이다.
enum ReportReason {
  spam('SPAM', '스팸 · 광고'),
  abuse('ABUSE', '욕설 · 비방'),
  adult('ADULT', '음란물 · 부적절한 사진'),
  falseInfo('FALSE_INFO', '허위 조황 · 거짓 정보'),

  /// 이것만 설명이 필수다 — 사유 이름만으로는 무엇이 문제인지 알 수 없다.
  other('OTHER', '기타');

  const ReportReason(this.code, this.label);

  final String code;
  final String label;

  bool get needsDetail => this == ReportReason.other;
}
