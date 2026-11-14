/// 場面別指示。
class Scene {
  const Scene({required this.title, required this.instruction});
  final String title;
  final String instruction;

  Map<String, Object?> toMap() => {'title': title, 'instruction': instruction};
  factory Scene.fromMap(Map<String, Object?> m) => Scene(
      title: (m['title'] as String?) ?? '',
      instruction: (m['instruction'] as String?) ?? '');
}

/// 指示書（目的・構成・納品条件・場面別指示）。
class Brief {
  const Brief({
    this.title = '',
    this.videoType = '',
    this.platform = '',
    this.audience = '',
    this.purpose = '',
    this.structure = '',
    this.deliveryTerms = '',
    this.scenes = const [],
  });

  final String title;
  final String videoType;
  final String platform;
  final String audience;
  final String purpose;
  final String structure;
  final String deliveryTerms;
  final List<Scene> scenes;

  Brief copyWith({
    String? title,
    String? videoType,
    String? platform,
    String? audience,
    String? purpose,
    String? structure,
    String? deliveryTerms,
    List<Scene>? scenes,
  }) =>
      Brief(
        title: title ?? this.title,
        videoType: videoType ?? this.videoType,
        platform: platform ?? this.platform,
        audience: audience ?? this.audience,
        purpose: purpose ?? this.purpose,
        structure: structure ?? this.structure,
        deliveryTerms: deliveryTerms ?? this.deliveryTerms,
        scenes: scenes ?? this.scenes,
      );

  Map<String, Object?> toMap() => {
        'videoType': videoType,
        'platform': platform,
        'audience': audience,
        'purpose': purpose,
        'structure': structure,
        'deliveryTerms': deliveryTerms,
        'scenes': [for (final s in scenes) s.toMap()],
      };

  factory Brief.fromMap(String title, Map<String, Object?> m) => Brief(
        title: title,
        videoType: (m['videoType'] as String?) ?? '',
        platform: (m['platform'] as String?) ?? '',
        audience: (m['audience'] as String?) ?? '',
        purpose: (m['purpose'] as String?) ?? '',
        structure: (m['structure'] as String?) ?? '',
        deliveryTerms: (m['deliveryTerms'] as String?) ?? '',
        scenes: [
          for (final s in (m['scenes'] as List?) ?? const [])
            Scene.fromMap(Map<String, Object?>.from(s as Map)),
        ],
      );
}

/// 必須項目・納期の検証。
/// 具体的な必須項目と納期の制約はFigJamで未確定。暫定: 依頼名・目的・構成・
/// 納品条件が必須、添付1件以上（動画・画像・BGM・資料のどれでも可）、納期は今日以降。
class BriefValidation {
  static Map<String, String> validate({
    required Brief brief,
    required DateTime? dueDate,
    required int attachmentCount,
    required DateTime now,
  }) {
    final errors = <String, String>{};
    if (brief.title.trim().isEmpty) errors['title'] = '依頼名を入力してください';
    if (brief.purpose.trim().isEmpty) errors['purpose'] = '目的を入力してください';
    if (brief.deliveryTerms.trim().isEmpty) {
      errors['deliveryTerms'] = '納品条件を入力してください';
    }
    if (attachmentCount < 1) errors['video'] = '動画・画像・資料のいずれかを添付してください';
    if (dueDate == null) {
      errors['dueDate'] = '納期を選択してください';
    } else {
      final today = DateTime(now.year, now.month, now.day);
      final d = DateTime(dueDate.year, dueDate.month, dueDate.day);
      if (d.isBefore(today)) errors['dueDate'] = '納期は今日以降を指定してください';
    }
    return errors;
  }
}
