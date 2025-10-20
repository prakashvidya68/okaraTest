enum AIProvider {
  openai('OpenAI', 'GPT-4o'),
  anthropic('Anthropic', 'Claude 3.5 Sonnet'),
  xai('XAI', 'Grok'),
  compareAll('Compare All', 'All Models');

  const AIProvider(this.name, this.model);

  final String name;
  final String model;

  bool get isCompareMode => this == AIProvider.compareAll;

  static List<AIProvider> get standardProviders => [openai, anthropic, xai];
}
