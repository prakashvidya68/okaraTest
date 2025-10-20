import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:okara/models/ai_provider.dart';
import 'package:okara/models/ai_response.dart';
import 'package:okara/models/analytics.dart';

final analyticsProvider = NotifierProvider<AnalyticsNotifier, SessionAnalytics>(
  AnalyticsNotifier.new,
);

class AnalyticsNotifier extends Notifier<SessionAnalytics> {
  @override
  SessionAnalytics build() {
    return SessionAnalytics.empty();
  }

  void recordResponse(AIResponse response) {
    final provider = response.provider;
    final currentProviderStats =
        state.byProvider[provider] ?? ProviderAnalytics.empty(provider);

    final newTotalRequests = currentProviderStats.totalRequests + 1;
    final newTotalTokens =
        currentProviderStats.totalTokens + response.usage.totalTokens;
    final newTotalCost =
        currentProviderStats.totalCost + response.usage.estimatedCost;
    final newTotalResponseTime =
        currentProviderStats.totalResponseTime + response.responseTime;

    final updatedProviderStats = ProviderAnalytics(
      provider: provider,
      totalRequests: newTotalRequests,
      totalTokens: newTotalTokens,
      totalCost: newTotalCost,
      totalResponseTime: newTotalResponseTime,
      averageResponseTime: Duration(
        milliseconds: newTotalResponseTime.inMilliseconds ~/ newTotalRequests,
      ),
    );

    final updatedByProvider = Map<AIProvider, ProviderAnalytics>.from(
      state.byProvider,
    );
    updatedByProvider[provider] = updatedProviderStats;

    state = SessionAnalytics(
      totalRequests: state.totalRequests + 1,
      totalTokens: state.totalTokens + response.usage.totalTokens,
      totalCost: state.totalCost + response.usage.estimatedCost,
      totalTime: state.totalTime + response.responseTime,
      byProvider: updatedByProvider,
    );
  }

  void reset() {
    state = SessionAnalytics.empty();
  }
}
