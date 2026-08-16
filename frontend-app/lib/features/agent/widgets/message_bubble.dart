import 'package:flutter/material.dart';

import '../../../core/models/agent_message.dart';
import '../../../core/util/markdown_content.dart';

/// Renders a user / answer / error message with polished mobile layout.
/// Tool, thinking, swarm and run-complete entries have their own widgets.
class MessageBubble extends StatelessWidget {
  const MessageBubble({super.key, required this.message, this.onRetry});

  final AgentMessage message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    switch (message.type) {
      case AgentMessageType.user:
        return _userBubble(context);
      case AgentMessageType.error:
        return _errorBubble(context);
      case AgentMessageType.answer:
      default:
        return _answer(context);
    }
  }

  // --- User message: right-aligned bubble with tail --- //

  Widget _userBubble(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.80),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.colorScheme.primary,
                theme.colorScheme.primary.withValues(alpha: 0.88),
              ],
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(4),
            ),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withValues(alpha: 0.15),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: SelectableText(
            message.content,
            style: TextStyle(
              color: Colors.white,
              height: 1.4,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }

  // --- Assistant answer: full-width markdown with avatar --- //

  Widget _answer(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Avatar circle
        Container(
          width: 32,
          height: 32,
          margin: const EdgeInsets.only(right: 10, top: 2),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.colorScheme.primary.withValues(alpha: 0.15),
                theme.colorScheme.secondary.withValues(alpha: 0.15),
              ],
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.auto_awesome, size: 16, color: theme.colorScheme.primary),
        ),
        // Content — GFM markdown (tables, strikethrough) + LaTeX math,
        // mirroring the web MarkdownContent pipeline.
        Expanded(
          child: MarkdownContent(content: message.content),
        ),
      ],
    );
  }

  // --- Error: bordered card with icon + retry --- //

  Widget _errorBubble(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.error.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline,
                  color: theme.colorScheme.error, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: SelectableText(message.content,
                    style: TextStyle(
                        height: 1.4,
                        color: theme.colorScheme.onErrorContainer)),
              ),
            ],
          ),
          if (onRetry != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 16),
                label: Text(_retryHint(message.content)),
                style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8)),
              ),
            ),
        ],
      ),
    );
  }

  static String _retryHint(String content) {
    final c = content.toLowerCase();
    if (c.contains('timeout') || c.contains('timed out') || c.contains('超时')) {
      return '重试';
    }
    if (c.contains('429') || c.contains('rate limit') || c.contains('503') || c.contains('5xx')) {
      return '重试';
    }
    return '重试';
  }
}
