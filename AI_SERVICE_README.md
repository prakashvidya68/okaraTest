# AI Service Integration

## Overview

Okara includes a comprehensive AI integration service that supports multiple AI providers with streaming responses, token tracking, cost estimation, and analytics.

## Architecture

```
lib/
├── services/
│   ├── ai_service.dart              # Abstract interface
│   ├── openai_service.dart          # OpenAI GPT-4o implementation
│   ├── anthropic_service.dart       # Anthropic Claude implementation
│   ├── xai_service.dart             # XAI Grok implementation
│   └── ai_service_factory.dart      # Service factory
├── models/
│   ├── ai_request.dart              # Request model
│   ├── ai_response.dart             # Response model with usage stats
│   ├── usage_stats.dart             # Token and cost tracking
│   └── analytics.dart               # Session analytics
└── providers/
    ├── chat_provider.dart           # Chat state management
    └── analytics_provider.dart      # Analytics tracking
```

## Features

### 1. **Multi-Provider Support**

- OpenAI (GPT-4o)
- Anthropic (Claude 3.5 Sonnet)
- XAI (Grok)

### 2. **Streaming Responses**

- Real-time token-by-token streaming
- Visual typing indicators
- Smooth UI updates

### 3. **Token & Cost Tracking**

- Accurate token counting
- Real-time cost estimation
- Per-request usage stats
- Session-level analytics

### 4. **Analytics Dashboard**

- Total requests, tokens, and costs
- Per-provider breakdowns
- Average response times
- Cost comparisons

## Usage

### Basic Single Provider Chat

```dart
// Get a service instance
final service = AIServiceFactory.getService(AIProvider.openai);

// Create a request
final request = AIRequest(
  prompt: 'Your question here',
  provider: AIProvider.openai,
  temperature: 0.7,
  maxTokens: 2048,
);

// Stream the response
await for (final chunk in service.streamMessage(request)) {
  print(chunk); // Handle each token
}
```

### Using with Riverpod

```dart
// Send a streaming message
ref.read(messagesProvider.notifier).sendStreamingMessage(
  'Your question',
  AIProvider.openai,
);

// View analytics
final analytics = ref.watch(analyticsProvider);
print('Total cost: \$${analytics.totalCost}');
```

### Comparison Mode

```dart
// Get responses from all providers
ref.read(comparisonMessagesProvider.notifier).sendComparisonMessage(
  'Your question',
);
```

## Cost Estimation

Current pricing (per 1K tokens):

| Provider         | Input Cost | Output Cost |
| ---------------- | ---------- | ----------- |
| OpenAI GPT-4o    | $0.0025    | $0.01       |
| Anthropic Claude | $0.003     | $0.015      |
| XAI Grok         | $0.005     | $0.015      |

## Adding a New Provider

1. **Create Service Implementation**

```dart
class NewProviderService implements AIService {
  @override
  Future<AIResponse> sendMessage(AIRequest request) async {
    // Implementation
  }

  @override
  Stream<String> streamMessage(AIRequest request) async* {
    // Implementation
  }

  @override
  Future<AIResponse> completeStream({...}) async {
    // Implementation
  }
}
```

2. **Update AIProvider Enum**

```dart
enum AIProvider {
  // ...existing providers
  newProvider('New Provider', 'Model Name');
}
```

3. **Update Factory**

```dart
class AIServiceFactory {
  static AIService getService(AIProvider provider, {String? apiKey}) {
    switch (provider) {
      case AIProvider.newProvider:
        return NewProviderService(apiKey: key);
      // ...existing cases
    }
  }
}
```

## API Keys

API keys can be configured in `ai_service_factory.dart`:

```dart
static String _getDefaultApiKey(AIProvider provider) {
  switch (provider) {
    case AIProvider.openai:
      return 'your-openai-key';
    case AIProvider.anthropic:
      return 'your-anthropic-key';
    case AIProvider.xai:
      return 'your-xai-key';
  }
}
```

For production, use environment variables or secure storage:

```dart
final apiKey = Platform.environment['OPENAI_API_KEY'] ?? 'demo-key';
```

## Dependencies

```yaml
dependencies:
  http: ^1.2.0 # HTTP client for API calls
  flutter_riverpod: ^2.5.1 # State management
  uuid: ^4.4.0 # Unique IDs
```

## Error Handling

The service includes graceful error handling:

- Network failures show demo responses
- Invalid API keys are caught
- Streaming errors are handled per-provider

## Performance

- **Streaming**: Minimal latency, token-by-token display
- **Memory**: Efficient stream processing
- **Analytics**: O(1) updates, minimal overhead

## Future Enhancements

- [ ] Conversation history for context
- [ ] Custom system prompts
- [ ] Temperature/parameter controls in UI
- [ ] Export chat history
- [ ] Cost limits and warnings
- [ ] Retry logic for failed requests
- [ ] Caching for repeated queries
