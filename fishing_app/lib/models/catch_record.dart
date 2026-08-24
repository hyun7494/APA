import 'package:flutter/material.dart';

import '../services/photo_picker.dart';

/// 조과 기록 — `fishing_user_catches` (기획서 3-3).
///
/// 한 어종을 여러 번 등록할 수 있고, 도감 획득 여부는 해당 `speciesId`
/// 레코드가 1건이라도 있는지로 판단한다.
///
/// 어종과 길이는 전부 사용자 자기신고다. 자동 판별을 쓰지 않기로 했으므로
/// 앱은 이 값을 검증하지 않는다 (Rev 2 결정).
/// GPS 좌표는 저장하지 않는다 — 장소는 [spotName] 자유 텍스트로 충분하다.
@immutable
class CatchRecord {
  const CatchRecord({
    required this.id,
    required this.speciesId,
    required this.speciesName,
    this.photoUrls = const [],
    this.lengthCm,
    required this.caughtAt,
    this.weightG,
    this.regionGroupId,
    this.spotName = '',
    this.memo = '',
  });

  final int id;
  final int speciesId;

  /// 목록에 바로 뿌리기 위해 서버가 함께 내려주는 어종명
  final String speciesName;

  /// 인증샷. **여러 장이고 순서가 있다** (V11, 시안 `PHOTOS · 1 / 5`).
  /// 첫 장이 표지다. 사진 없이 등록할 수 있어 빈 목록이 정상이다.
  final List<String> photoUrls;

  /// 도감 칸·목록 썸네일이 쓰는 한 장. 사진이 없으면 null 이다.
  String? get coverPhotoUrl => photoUrls.isEmpty ? null : photoUrls.first;

  /// 화면에 쓸 길이 표기. 길이는 선택이라 **"기록 안 함"이 정상 상태**다 —
  /// 0cm 로 떨어뜨리면 실제로 0을 잰 것처럼 읽힌다.
  String get lengthLabel =>
      lengthCm == null ? '기록 안 함' : '${lengthCm!.toStringAsFixed(1)}cm';

  /// 사용자가 자로 재서 직접 입력한 길이. **선택이다** (V11) —
  /// 놓아준 물고기나 사진만 남기고 싶은 기록이 있다.
  final double? lengthCm;

  /// 선택
  final int? weightG;

  final DateTime caughtAt;

  /// 선택 — 등록 포인트가 아닐 수 있어 자유 입력을 함께 둔다
  final int? regionGroupId;

  /// "기장 학리"
  final String spotName;

  final String memo;

  factory CatchRecord.fromJson(Map<String, dynamic> json) => CatchRecord(
    id: (json['id'] as num).toInt(),
    speciesId: (json['speciesId'] as num).toInt(),
    speciesName: json['speciesName'] as String? ?? '',
    photoUrls:
        (json['photoUrls'] as List?)?.map((e) => e as String).toList() ??
        const [],
    lengthCm: (json['lengthCm'] as num?)?.toDouble(),
    weightG: (json['weightG'] as num?)?.toInt(),
    caughtAt: DateTime.tryParse(json['caughtAt'] as String? ?? '') ?? DateTime.now(),
    regionGroupId: (json['regionGroupId'] as num?)?.toInt(),
    spotName: json['spotName'] as String? ?? '',
    memo: json['memo'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'speciesId': speciesId,
    'speciesName': speciesName,
    'photoUrls': photoUrls,
    'lengthCm': lengthCm,
    'weightG': weightG,
    'caughtAt': caughtAt.toIso8601String(),
    'regionGroupId': regionGroupId,
    'spotName': spotName,
    'memo': memo,
  };
}

/// 조과 등록 요청 — `POST /fishing/me/catches`
@immutable
class CatchDraft {
  const CatchDraft({
    required this.speciesId,
    required this.caughtAt,
    this.lengthCm,
    this.photos = const [],
    this.spotName = '',
    this.memo = '',
  });

  final int speciesId;

  /// 선택 (V11). null 이면 서버가 길이 없이 기록한다.
  final double? lengthCm;

  final DateTime caughtAt;

  /// 올릴 사진들. 경로가 아니라 바이트다 — 웹에는 `dart:io` 파일이 없다.
  /// 최대 5장이고 순서가 그대로 서버에 간다.
  final List<PickedPhoto> photos;

  final String spotName;
  final String memo;
}

/// 조과 등록 응답.
///
/// `firstCatch`가 true면 도감 칸이 새로 채워진 것이라 획득 연출로 넘어간다.
@immutable
class CatchResult {
  const CatchResult({
    required this.record,
    required this.firstCatch,
    required this.ownedCount,
    required this.totalCount,
  });

  final CatchRecord record;

  /// 이 어종을 처음 등록했는지
  final bool firstCatch;

  /// 등록 직후의 도감 진행도
  final int ownedCount;
  final int totalCount;

  factory CatchResult.fromJson(Map<String, dynamic> json) => CatchResult(
    record: CatchRecord.fromJson(json['record'] as Map<String, dynamic>),
    firstCatch: json['firstCatch'] as bool? ?? false,
    ownedCount: (json['ownedCount'] as num?)?.toInt() ?? 0,
    totalCount: (json['totalCount'] as num?)?.toInt() ?? 0,
  );
}
