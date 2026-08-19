/// 기능 플래그 (기획서 5-2).
///
/// 운세는 Rev 2에서 화면·라우트를 아예 만들지 않는다. 제거한 자리마다
/// 플래그 분기를 남기면 코드가 지저분해지므로, 나머지 코드는 운세가
/// 존재하지 않는 것처럼 짜여 있다.
///
/// 되살릴 때는 기획서 Rev 1 사양(2-2 오늘의 운세, 3-4 Fortune)을 참조한다.
abstract final class FeatureFlags {
  /// Rev 2: 운세 미노출. 백엔드 스키마와 배치는 유지하되 프론트는 호출하지 않는다.
  static const enableFortune = false;

  /// 조과 사진 업로드. `image_picker` 연동 전까지는 더미 플레이스홀더를 쓴다.
  static const enablePhotoPicker = false;
}
