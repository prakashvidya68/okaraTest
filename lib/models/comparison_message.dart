import 'package:okara/models/ai_provider.dart';

class ProviderResponse {
  final AIProvider provider;
  final String content;
  final bool isStreaming;

  ProviderResponse({
    required this.provider,
    required this.content,
    this.isStreaming = false,
  });

  ProviderResponse copyWith({String? content, bool? isStreaming}) {
    return ProviderResponse(
      provider: provider,
      content: content ?? this.content,
      isStreaming: isStreaming ?? this.isStreaming,
    );
  }
}

class ComparisonMessage {
  final String id;
  final String userQuery;
  final List<ProviderResponse> responses;
  final DateTime timestamp;

  ComparisonMessage({
    required this.id,
    required this.userQuery,
    required this.responses,
    required this.timestamp,
  });
}
