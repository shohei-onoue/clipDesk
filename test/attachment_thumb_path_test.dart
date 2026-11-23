import 'package:flutter_test/flutter_test.dart';

import 'package:clipdesk/domain/video_request.dart';

void main() {
  test('添付のサムネイルのパスは、保存して読み戻せる。無い（これまでの依頼）ときは null のまま', () {
    const a = Attachment(
        name: 'a.mp4',
        path: 'uploads/u/r/video_0-a.mp4',
        size: 1,
        kind: 'video',
        thumbPath: 'uploads/u/r/thumb_0.jpg');
    expect(Attachment.fromMap(a.toMap()).thumbPath, 'uploads/u/r/thumb_0.jpg');
    const old = Attachment(name: 'a.mp4', path: 'p', size: 1, kind: 'video');
    expect(old.toMap().containsKey('thumbPath'), isFalse);
    expect(Attachment.fromMap(old.toMap()).thumbPath, isNull);
  });

  test('提出動画のサムネイルのパスを読む', () {
    final s = Submission.fromMap(const {
      'version': 2,
      'name': 'v.mp4',
      'path': 'videos/r/v2/v.mp4',
      'size': 3,
      'thumbPath': 'videos/r/v2/thumb.jpg',
    });
    expect(s.thumbPath, 'videos/r/v2/thumb.jpg');
    expect(Submission.fromMap(const {'version': 1}).thumbPath, isNull);
  });
}
