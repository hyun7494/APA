import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

/// 사진을 가져올 곳.
enum PhotoSource {
  camera('촬영하기'),
  gallery('갤러리에서 선택');

  const PhotoSource(this.label);

  final String label;
}

/// 고른 사진 한 장.
///
/// 경로가 아니라 **바이트로 들고 다닌다.** 웹에는 `dart:io` 파일이 없어서
/// 경로만 넘기면 `flutter run -d chrome` 개발 흐름이 통째로 깨진다.
@immutable
class PickedPhoto {
  const PickedPhoto({
    required this.bytes,
    required this.name,
    required this.mimeType,
  });

  final Uint8List bytes;
  final String name;

  /// `image/jpeg` 또는 `image/png`.
  ///
  /// 서버가 **선언된 Content-Type 으로 판정**하므로 (PhotoStorageService)
  /// 추측이 틀리면 사진이 멀쩡해도 400 이 온다.
  final String mimeType;

  int get sizeBytes => bytes.length;
}

/// HEIC 처럼 서버가 못 받는 형식을 골랐을 때.
class UnsupportedPhotoException implements Exception {
  const UnsupportedPhotoException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 사진 선택기.
///
/// 인터페이스로 둔 이유는 테스트다. 위젯 테스트에서 진짜 플랫폼 채널을
/// 부르면 응답이 없어 등록 플로우 전체를 검증할 수 없다.
abstract interface class PhotoPicker {
  /// 사용자가 취소하면 null.
  Future<PickedPhoto?> pick(PhotoSource source);
}

/// `image_picker` 구현.
class ImagePickerPhotoPicker implements PhotoPicker {
  ImagePickerPhotoPicker([ImagePicker? picker])
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  /// 서버가 어차피 긴 변 1280으로 다시 굽는다. 원본을 그대로 올리면
  /// 8MB 짜리가 왕복하며 느려지기만 하므로 여기서 한 번 줄여 보낸다.
  /// 1280이 아니라 1920인 것은 서버 리사이즈에 여유를 남기기 위해서다.
  static const _maxEdge = 1920.0;

  /// **iOS 에서 이 값이 HEIC 을 막는다.** 크기·품질 옵션이 하나라도 있으면
  /// image_picker 가 JPEG 으로 다시 인코딩해서 넘긴다. 옵션을 다 빼면
  /// 아이폰 기본 설정에서 HEIC 이 그대로 올라가 서버가 400 을 낸다.
  static const _quality = 90;

  @override
  Future<PickedPhoto?> pick(PhotoSource source) async {
    final file = await _picker.pickImage(
      source: source == PhotoSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      maxWidth: _maxEdge,
      maxHeight: _maxEdge,
      imageQuality: _quality,
    );
    if (file == null) return null;

    final mime = _mimeOf(file);
    return PickedPhoto(
      bytes: await file.readAsBytes(),
      name: file.name.isEmpty ? 'catch.jpg' : file.name,
      mimeType: mime,
    );
  }

  /// 확장자로 형식을 정한다.
  ///
  /// `XFile.mimeType` 은 안드로이드 갤러리에서 비어 오는 경우가 있어
  /// 단독으로 믿을 수 없다. 둘 다 없으면 JPEG 으로 본다 — 위 옵션 때문에
  /// 플랫폼이 다시 인코딩한 결과가 JPEG 이다.
  static String _mimeOf(XFile file) {
    final declared = file.mimeType?.toLowerCase() ?? '';
    final name = file.name.toLowerCase();

    if (declared.contains('heic') ||
        declared.contains('heif') ||
        name.endsWith('.heic') ||
        name.endsWith('.heif')) {
      throw const UnsupportedPhotoException(
        'HEIC 사진은 아직 올릴 수 없어요. JPEG 으로 저장한 뒤 다시 시도해 주세요',
      );
    }
    if (declared.contains('png') || name.endsWith('.png')) return 'image/png';
    if (declared.contains('jpeg') ||
        declared.contains('jpg') ||
        name.endsWith('.jpg') ||
        name.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    if (declared.startsWith('image/')) {
      throw UnsupportedPhotoException(
        '${declared.split('/').last.toUpperCase()} 사진은 올릴 수 없어요. JPEG 또는 PNG 로 저장해 주세요',
      );
    }
    return 'image/jpeg';
  }
}

final photoPickerProvider = Provider<PhotoPicker>(
  (ref) => ImagePickerPhotoPicker(),
);
