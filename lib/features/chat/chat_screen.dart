import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:okara/features/analytics/analytics_screen.dart';
import 'package:okara/features/chat/widgets/chat_input.dart';
import 'package:okara/features/chat/widgets/comparison_bubble.dart';
import 'package:okara/features/chat/widgets/message_bubble.dart';
import 'package:okara/features/chat/widgets/provider_selector.dart';
import 'package:okara/models/comparison_message.dart';
import 'package:okara/models/message.dart';
import 'package:okara/providers/chat_provider.dart';

class ChatScreen extends ConsumerWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messages = ref.watch(messagesProvider);
    final comparisons = ref.watch(comparisonMessagesProvider);
    final theme = Theme.of(context);
    final hasContent = messages.isNotEmpty || comparisons.isNotEmpty;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.chat_bubble_outline_rounded,
                color: theme.colorScheme.onPrimaryContainer,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Okara',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AnalyticsScreen(),
                ),
              );
            },
            tooltip: 'View analytics',
          ),
          if (hasContent)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () {
                ref.read(messagesProvider.notifier).clear();
                ref.read(comparisonMessagesProvider.notifier).clear();
              },
              tooltip: 'Clear chat',
            ),
        ],
      ),
      body: Column(
        children: [
          const ProviderSelector(),
          Expanded(
            child: hasContent
                ? _buildChatContent(messages, comparisons)
                : _buildEmptyState(theme),
          ),
          const ChatInput(),
        ],
      ),
    );
  }

  Widget _buildChatContent(messages, comparisons) {
    final allItems = <dynamic>[];

    int messageIndex = 0;
    int comparisonIndex = 0;

    while (messageIndex < messages.length ||
        comparisonIndex < comparisons.length) {
      if (messageIndex < messages.length &&
          comparisonIndex < comparisons.length) {
        if (messages[messageIndex].timestamp.isBefore(
          comparisons[comparisonIndex].timestamp,
        )) {
          allItems.add(messages[messageIndex]);
          messageIndex++;
        } else {
          allItems.add(comparisons[comparisonIndex]);
          comparisonIndex++;
        }
      } else if (messageIndex < messages.length) {
        allItems.add(messages[messageIndex]);
        messageIndex++;
      } else {
        allItems.add(comparisons[comparisonIndex]);
        comparisonIndex++;
      }
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 16, bottom: 16),
      itemCount: allItems.length,
      itemBuilder: (context, index) {
        final item = allItems[index];
        if (item is Message) {
          return MessageBubble(message: item);
        } else if (item is ComparisonMessage) {
          return ComparisonBubble(comparison: item);
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.auto_awesome_rounded,
              size: 48,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Start a conversation',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ask anything and get responses from multiple AI models',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
