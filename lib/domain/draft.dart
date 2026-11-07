import 'brief.dart';
import 'video_request.dart';
import '../data/storage_service.dart';

/// チャットで入力中の依頼内容。
class RequestDraft {
  RequestDraft({required this.requestId});

  /// 送信の重複防止用。画面で1回だけ採番し、再試行でも同じ値を使う。
  final String requestId;
  Brief brief = const Brief();
  DateTime? dueDate;
  List<UploadFile> videos = [];
  List<UploadFile> references = [];

  /// 要確認からの再送信時: 元の依頼（添付は変更しない）。
  VideoRequest? original;

  int get videoCount => original != null
      ? original!.attachments.where((a) => a.kind == 'video').length
      : videos.length;

  Map<String, String> validate(DateTime now) => BriefValidation.validate(
      brief: brief, dueDate: dueDate, videoCount: videoCount, now: now);
}
