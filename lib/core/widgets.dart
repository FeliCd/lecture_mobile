import 'package:flutter/material.dart';
import 'config.dart';

class AsyncPanel<T> extends StatefulWidget {
  final Future<T> Function() load;
  final Widget Function(BuildContext, T, Future<void> Function()) builder;
  const AsyncPanel({super.key, required this.load, required this.builder});
  @override
  State<AsyncPanel<T>> createState() => _AsyncPanelState<T>();
}

class _AsyncPanelState<T> extends State<AsyncPanel<T>> {
  late Future<T> future = widget.load();
  Future<void> refresh() async {
    final next = widget.load();
    setState(() {
      future = next;
    });
    try {
      await next;
    } catch (_) {
      /* FutureBuilder displays safe errors. */
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(
          child: CircularProgressIndicator(semanticsLabel: 'Loading'),
        );
      }
      if (snapshot.hasError) {
        return MessagePanel(
          message: safeMessage(snapshot.error!),
          action: refresh,
        );
      }
      return widget.builder(context, snapshot.data as T, refresh);
    },
  );
}

class MessagePanel extends StatelessWidget {
  final String message;
  final VoidCallback? action;
  const MessagePanel({super.key, required this.message, this.action});
  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              action == null
                  ? Icons.event_note_outlined
                  : Icons.cloud_off_outlined,
              size: 42,
            ),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            if (action != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: FilledButton(
                  onPressed: action,
                  child: const Text('Retry'),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
    ),
  );
}

class StatusChip extends StatelessWidget {
  final String status;
  const StatusChip(this.status, {super.key});
  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'PRESENT' || 'CLOSED' => const Color(0xFF176337),
      'ABSENT' => const Color(0xFFAA2424),
      'LATE' => const Color(0xFF805000),
      _ => const Color(0xFF55515A),
    };
    return Chip(
      label: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      backgroundColor: color.withValues(alpha: .08),
      side: BorderSide.none,
    );
  }
}

Future<void> showFailure(BuildContext context, Object error) async {
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(safeMessage(error)),
        duration: const Duration(seconds: 7),
      ),
    );
  }
}
