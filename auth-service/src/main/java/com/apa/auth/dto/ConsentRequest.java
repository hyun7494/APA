package com.apa.auth.dto;

/**
 * 가입 요청에 실려 오는 동의 한 건.
 *
 * @param type    {@code TERMS_OF_SERVICE} 같은 코드. 모르는 값이면 400 이다 —
 *                조용히 무시하면 오타 하나로 필수 동의가 빠진 채 가입된다
 * @param version 사용자가 <b>실제로 본 문서의 판</b>. 앱이 화면에 띄운 그 값을 그대로 보낸다.
 *                서버가 지어내면 "그때 뭐에 동의한 거냐" 에 답할 수 없다
 * @param agreed  체크했는가. 선택 항목은 false 로 와도 가입이 된다
 */
public record ConsentRequest(String type, String version, boolean agreed) {
}
