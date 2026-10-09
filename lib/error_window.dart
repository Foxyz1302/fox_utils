import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'dio_exceptions.dart'; // Assuming they are in the same package

class ErrorWindow extends StatelessWidget {
  final Object? originalError;
  final Widget? child; // For retry buttons, etc.

  const ErrorWindow(this.originalError, {this.child, super.key});

  @override
  Widget build(BuildContext context) {
    final error = originalError;

    Widget errorContent = Text(
      'An unexpected error occurred:\n${error.toString()}',
      style: Theme.of(context).textTheme.bodyMedium,
    );

    if (error is DioException) {
      errorContent = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildFriendlyHeader(context, error),
          const Divider(height: 30),
          Text(
            'Technical Details:',
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(
              error.toDebugString(),
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: Colors.white70,
              ),
            ),
          ),
        ],
      );
    }

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, minHeight: 200),
        padding: const EdgeInsets.all(20),
        margin: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Theme.of(context).colorScheme.error.withValues(alpha: 0.3),
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              errorContent,
              if (child != null)
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Align(alignment: Alignment.bottomRight, child: child),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFriendlyHeader(BuildContext context, DioException error) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.warning_rounded, color: Colors.redAccent, size: 28),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                error.userMessage,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Request: ${error.requestOptions.method} ${error.requestOptions.uri.path}',
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: Colors.grey),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
