import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:okara/models/ai_provider.dart';
import 'package:okara/providers/chat_provider.dart';

class ProviderSelector extends ConsumerWidget {
  const ProviderSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedProvider = ref.watch(selectedProviderProvider);
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: DropdownButton<AIProvider>(
        value: selectedProvider,
        onChanged: (AIProvider? newValue) {
          if (newValue != null) {
            ref.read(selectedProviderProvider.notifier).setProvider(newValue);
          }
        },
        underline: const SizedBox.shrink(),
        borderRadius: BorderRadius.circular(12),
        icon: Icon(
          Icons.keyboard_arrow_down_rounded,
          color: theme.colorScheme.onSurface,
        ),
        items: AIProvider.values.map((provider) {
          return DropdownMenuItem<AIProvider>(
            value: provider,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (provider.isCompareMode)
                  Icon(
                    Icons.compare_arrows_rounded,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                if (provider.isCompareMode) const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: provider.isCompareMode
                        ? theme.colorScheme.tertiaryContainer
                        : theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    provider.name,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: provider.isCompareMode
                          ? theme.colorScheme.onTertiaryContainer
                          : theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (!provider.isCompareMode) const SizedBox(width: 8),
                if (!provider.isCompareMode)
                  Text(
                    provider.model,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
