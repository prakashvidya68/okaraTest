import 'package:okara/models/ai_provider.dart';

class ProviderAnalytics {
  final AIProvider provider;
  final int totalRequests;
  final int totalTokens;
  final double totalCost;
  final Duration averageResponseTime;
  final Duration totalResponseTime;

  ProviderAnalytics({
    required this.provider,
    required this.totalRequests,
    required this.totalTokens,
    required this.totalCost,
    required this.averageResponseTime,
    required this.totalResponseTime,
  });

  factory ProviderAnalytics.empty(AIProvider provider) {
    return ProviderAnalytics(
      provider: provider,
      totalRequests: 0,
      totalTokens: 0,
      totalCost: 0.0,
      averageResponseTime: Duration.zero,
      totalResponseTime: Duration.zero,
    );
  }
}

class SessionAnalytics {
  final int totalRequests;
  final int totalTokens;
  final double totalCost;
  final Duration totalTime;
  final Map<AIProvider, ProviderAnalytics> byProvider;

  SessionAnalytics({
    required this.totalRequests,
    required this.totalTokens,
    required this.totalCost,
    required this.totalTime,
    required this.byProvider,
  });

  factory SessionAnalytics.empty() {
    return SessionAnalytics(
      totalRequests: 0,
      totalTokens: 0,
      totalCost: 0.0,
      totalTime: Duration.zero,
      byProvider: {},
    );
  }
}
