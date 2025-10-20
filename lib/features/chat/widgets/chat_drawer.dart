import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:okara/providers/chat_provider.dart';
import 'package:okara/providers/chat_session_provider.dart';
import 'package:okara/services/database_service.dart';

class ChatDrawer extends ConsumerWidget {
  const ChatDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(chatSessionsProvider);
    final currentSession = ref.watch(currentSessionProvider);
    final theme = Theme.of(context);

    return Drawer(
      child: Column(
        children: [
          _buildHeader(context, theme),
          _buildNewChatButton(context, ref, theme),
          const Divider(),
          Expanded(
            child: sessions.isEmpty
                ? _buildEmptyState(theme)
                : _buildSessionsList(
                    context,
                    ref,
                    sessions,
                    currentSession,
                    theme,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ThemeData theme) {
    return DrawerHeader(
      decoration: BoxDecoration(color: theme.colorScheme.primaryContainer),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Icon(
            Icons.chat_bubble_outline_rounded,
            size: 48,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 8),
          Text(
            'Okara',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'Chat History',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onPrimaryContainer.withValues(
                alpha: 0.8,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewChatButton(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
  ) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: ElevatedButton.icon(
        onPressed: () async {
          final sessions = ref.read(chatSessionsProvider);
          final db = DatabaseService.instance;

          // Check if there's already an empty chat (no messages AND no comparisons)
          for (final session in sessions) {
            final messages = await db.getMessages(session.id);
            final comparisons = await db.getComparisonMessages(session.id);
            if (messages.isEmpty && comparisons.isEmpty) {
              // Found an empty chat, switch to it instead of creating new one
              ref.read(currentSessionProvider.notifier).setSession(session);
              ref.read(messagesProvider.notifier).clear();
              if (context.mounted) {
                Navigator.pop(context);
              }
              return;
            }
          }

          // No empty chat found, create a new one
          final session = await ref
              .read(chatSessionsProvider.notifier)
              .createNewSession();
          ref.read(currentSessionProvider.notifier).setSession(session);
          ref.read(messagesProvider.notifier).clear();
          if (context.mounted) {
            Navigator.pop(context);
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('New Chat'),
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: theme.colorScheme.onPrimary,
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_outlined, size: 64, color: theme.colorScheme.outline),
          const SizedBox(height: 16),
          Text(
            'No chats yet',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start a new chat to begin',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionsList(
    BuildContext context,
    WidgetRef ref,
    List<dynamic> sessions,
    dynamic currentSession,
    ThemeData theme,
  ) {
    return ListView.builder(
      itemCount: sessions.length,
      itemBuilder: (context, index) {
        final session = sessions[index];
        final isSelected = currentSession?.id == session.id;

        return ListTile(
          selected: isSelected,
          selectedTileColor: theme.colorScheme.primaryContainer.withValues(
            alpha: 0.3,
          ),
          leading: Icon(
            Icons.chat_bubble_outline,
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface,
          ),
          title: Text(
            session.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          subtitle: Text(
            _formatDate(session.updatedAt),
            style: theme.textTheme.bodySmall,
          ),
          trailing: PopupMenuButton(
            icon: const Icon(Icons.more_vert),
            itemBuilder: (context) => [
              PopupMenuItem(
                onTap: () {
                  Future.delayed(Duration.zero, () {
                    if (context.mounted) {
                      _showRenameDialog(context, ref, session);
                    }
                  });
                },
                child: const Row(
                  children: [
                    Icon(Icons.edit),
                    SizedBox(width: 8),
                    Text('Rename'),
                  ],
                ),
              ),
              PopupMenuItem(
                onTap: () async {
                  final sessionNotifier = ref.read(
                    chatSessionsProvider.notifier,
                  );
                  final currentSessionNotifier = ref.read(
                    currentSessionProvider.notifier,
                  );
                  final messagesNotifier = ref.read(messagesProvider.notifier);

                  await sessionNotifier.deleteSession(session.id);

                  if (isSelected) {
                    // If we deleted the active session, create a new one
                    final remainingSessions = ref.read(chatSessionsProvider);
                    if (remainingSessions.isEmpty) {
                      // No sessions left, create a new one
                      final newSession = await sessionNotifier
                          .createNewSession();
                      currentSessionNotifier.setSession(newSession);
                    } else {
                      // Switch to the most recent session
                      currentSessionNotifier.setSession(
                        remainingSessions.first,
                      );
                    }
                    messagesNotifier.clear();
                  }
                },
                child: Row(
                  children: [
                    Icon(Icons.delete, color: theme.colorScheme.error),
                    const SizedBox(width: 8),
                    Text(
                      'Delete',
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ],
                ),
              ),
            ],
          ),
          onTap: () {
            ref.read(currentSessionProvider.notifier).setSession(session);
            Navigator.pop(context);
          },
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  void _showRenameDialog(BuildContext context, WidgetRef ref, dynamic session) {
    final controller = TextEditingController(text: session.title);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rename Chat'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Chat Title',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                ref
                    .read(chatSessionsProvider.notifier)
                    .updateSessionTitle(session.id, controller.text.trim());
                Navigator.pop(dialogContext);
              }
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }
}
