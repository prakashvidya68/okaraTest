import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:okara/models/ai_provider.dart';
import 'package:okara/models/ai_response.dart';
import 'package:okara/models/analytics.dart';
import 'package:okara/services/database_service.dart';

final analyticsProvider = NotifierProvider<AnalyticsNotifier, SessionAnalytics>(
  AnalyticsNotifier.new,
);

class AnalyticsNotifier extends Notifier<SessionAnalytics> {
  final _db = DatabaseService.instance;

  @override
  SessionAnalytics build() {
    // Load analytics from database on initialization
    loadFromDatabase();
    return SessionAnalytics.empty();
  }

  Future<void> loadFromDatabase() async {
    final stats = await _db.getAllMessagesStats();
    final providers = stats['providers'] as List<Map<String, dynamic>>;

    if (providers.isEmpty) {
      state = SessionAnalytics.empty();
      return;
    }

    final Map<AIProvider, ProviderAnalytics> providerMap = {};
    int totalRequests = 0;
    int totalTokens = 0;
    double totalCost = 0.0;
    Duration totalTime = Duration.zero;

    for (final providerData in providers) {
      final providerName = providerData['provider'] as String;
      AIProvider? provider;

      try {
        provider = AIProvider.values.firstWhere((e) => e.name == providerName);
      } catch (e) {
        continue; // Skip unknown providers
      }

      final requests = providerData['totalRequests'] as int;
      final tokens = (providerData['totalTokens'] as int?) ?? 0;
      final cost = (providerData['totalCost'] as double?) ?? 0.0;
      final responseTimeMs = (providerData['totalResponseTimeMs'] as int?) ?? 0;
      final totalResponseTime = Duration(milliseconds: responseTimeMs);

      providerMap[provider] = ProviderAnalytics(
        provider: provider,
        totalRequests: requests,
        totalTokens: tokens,
        totalCost: cost,
        totalResponseTime: totalResponseTime,
        averageResponseTime: requests > 0
            ? Duration(milliseconds: responseTimeMs ~/ requests)
            : Duration.zero,
      );

      totalRequests += requests;
      totalTokens += tokens;
      totalCost += cost;
      totalTime += totalResponseTime;
    }

    state = SessionAnalytics(
      totalRequests: totalRequests,
      totalTokens: totalTokens,
      totalCost: totalCost,
      totalTime: totalTime,
      byProvider: providerMap,
    );
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
