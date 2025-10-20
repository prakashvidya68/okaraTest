class UsageStats {
  final int promptTokens;
  final int completionTokens;
  final int totalTokens;
  final double estimatedCost;

  UsageStats({
    required this.promptTokens,
    required this.completionTokens,
    required this.totalTokens,
    required this.estimatedCost,
  });

  factory UsageStats.zero() {
    return UsageStats(
      promptTokens: 0,
      completionTokens: 0,
      totalTokens: 0,
      estimatedCost: 0.0,
    );
  }
}
