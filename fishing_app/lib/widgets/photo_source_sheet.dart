import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/photo_picker.dart';
import '../theme/app_theme.dart';
import 'app_card.dart';
import 'press_scale.dart';

/// 사진을 어디서 가져올지 고르는 시트.
class PhotoSourceSheet extends StatelessWidget {
  const PhotoSourceSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(AppSpacing.screen),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final source in PhotoSource.values) ...[
              if (source != PhotoSource.values.first)
                const CardDivider(margin: EdgeInsets.symmetric(horizontal: 10)),
              PressScale(
                onTap: () => Navigator.pop(context, source),
                scale: 0.98,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 16,
                  ),
                  child: Row(
                    children: [
                      LineIcon(
                        source == PhotoSource.camera
                            ? AppIcon.camera
                            : AppIcon.book,
                        size: 19,
                        color: AppColors.accent,
                        stroke: 1.5,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(source.label, style: AppText.rowValue),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 서버가 받는 최대 크기. `PhotoProperties` 와 같은 값이다.
const maxPhotoBytes = 15 * 1024 * 1024;

/// 시트를 띄우고 사진 한 장을 받아 온다. 고르지 않았거나 실패하면 null 이다.
///
/// 조과 등록과 글쓰기가 같은 절차를 밟으므로 여기 모아 둔다 — 두 곳에 두면
/// 크기 한도나 권한 안내 문구가 한쪽에서만 바뀐다.
///
/// 실패는 [onMessage] 로 알린다. 화면마다 안내를 띄우는 방식이 달라서
/// (스낵바 위치·`ScaffoldMessenger` 소유자) 여기서 직접 띄우지 않는다.
Future<PickedPhoto?> pickPhotoFromSheet(
  BuildContext context,
  WidgetRef ref, {
  required void Function(String message) onMessage,
}) async {
  final source = await showModalBottomSheet<PhotoSource>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => const PhotoSourceSheet(),
  );
  if (source == null || !context.mounted) return null;

  try {
    final picked = await ref.read(photoPickerProvider).pick(source);
    if (picked == null) return null;

    // 서버 한도를 넘는 사진은 여기서 잘라낸다. 올려 보고 400 을 받으면
    // 업로드 시간을 통째로 날린 뒤에야 알게 된다.
    if (picked.sizeBytes > maxPhotoBytes) {
      onMessage('사진이 너무 커요 (${_mb(picked.sizeBytes)}MB). 15MB 아래로 줄여주세요');
      return null;
    }
    return picked;
  } on UnsupportedPhotoException catch (e) {
    onMessage(e.message);
    return null;
  } catch (_) {
    // 카메라·앨범 권한 거부가 여기로 온다. 플랫폼마다 예외 타입이 달라
    // 하나로 묶고, 사용자가 할 수 있는 일만 알려준다.
    onMessage('사진을 가져오지 못했어요. 설정에서 사진·카메라 권한을 확인해 주세요');
    return null;
  }
}

String _mb(int bytes) => (bytes / 1024 / 1024).toStringAsFixed(1);
