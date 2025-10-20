import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:okara/features/analytics/analytics_screen.dart';
import 'package:okara/features/chat/widgets/chat_drawer.dart';
import 'package:okara/features/chat/widgets/chat_input.dart';
import 'package:okara/features/chat/widgets/comparison_bubble.dart';
import 'package:okara/features/chat/widgets/message_bubble.dart';
import 'package:okara/features/chat/widgets/provider_selector.dart';
import 'package:okara/models/comparison_message.dart';
import 'package:okara/models/message.dart';
import 'package:okara/providers/chat_provider.dart';
import 'package:okara/providers/chat_session_provider.dart';
import 'package:okara/services/database_service.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  @override
  void initState() {
    super.initState();
    // Initialize with a default session if none exists
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeSession();
    });
  }

  Future<void> _initializeSession() async {
    final currentSession = ref.read(currentSessionProvider);

    // Skip if already has a session
    if (currentSession != null) return;

    final db = DatabaseService.instance;
    final sessionNotifier = ref.read(chatSessionsProvider.notifier);
    final currentSessionNotifier = ref.read(currentSessionProvider.notifier);

    // Ensure sessions are loaded from database
    await sessionNotifier.refreshSessions();
    final sessions = ref.read(chatSessionsProvider);

    if (sessions.isEmpty) {
      // No sessions at all, create the first one
      final newSession = await sessionNotifier.createNewSession();
      currentSessionNotifier.setSession(newSession);
      return;
    }

    // Check if there's an empty chat (no messages AND no comparisons) we can reuse
    for (final session in sessions) {
      final messages = await db.getMessages(session.id);
      final comparisons = await db.getComparisonMessages(session.id);
      if (messages.isEmpty && comparisons.isEmpty) {
        // Found an empty chat, use it
        currentSessionNotifier.setSession(session);
        return;
      }
    }

    // No empty chat found, use the most recent session
    currentSessionNotifier.setSession(sessions.first);
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(messagesProvider);
    final comparisons = ref.watch(comparisonMessagesProvider);
    final currentSession = ref.watch(currentSessionProvider);
    final theme = Theme.of(context);
    final hasContent = messages.isNotEmpty || comparisons.isNotEmpty;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      drawer: const ChatDrawer(),
      appBar: AppBar(
        elevation: 0,
        leading: Builder(
          builder: (BuildContext context) {
            return IconButton(
              icon: Image.asset(
                'assets/images/okara.png',
                width: 32,
                height: 32,
              ),
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
            );
          },
        ),
        backgroundColor: theme.colorScheme.surface,
        title: Text(
          currentSession?.title ?? 'Okara',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
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
