import 'package:fantastic_guacamole/domain/strategic/si_console_intelligence_contract.dart';

class SIConsoleMessage {
  const SIConsoleMessage({
    required this.text,
    required this.isUser,
    this.emotion,
    this.createdAt,
    this.receipt,
  });

  final String text;
  final bool isUser;
  final String? emotion;
  final DateTime? createdAt;
  final SIIntelligenceReceipt? receipt;

  Map<String, dynamic> toJson({DateTime? fallbackCreatedAt}) =>
      <String, dynamic>{
        'text': text,
        'isUser': isUser,
        'emotion': emotion,
        'createdAt': (createdAt ?? fallbackCreatedAt ?? DateTime.now())
            .toUtc()
            .toIso8601String(),
        if (receipt != null) 'receipt': receipt!.toJson(),
      };

  factory SIConsoleMessage.fromJson(Map<String, dynamic> json) {
    final Object? rawReceipt = json['receipt'];
    return SIConsoleMessage(
      text: json['text']?.toString() ?? '',
      isUser: json['isUser'] == true,
      emotion: json['emotion']?.toString(),
      createdAt: DateTime.tryParse(
        json['createdAt']?.toString() ?? '',
      )?.toUtc(),
      receipt: rawReceipt is Map<Object?, Object?>
          ? SIIntelligenceReceipt.fromJson(
              Map<String, dynamic>.from(rawReceipt),
            )
          : null,
    );
  }
}
