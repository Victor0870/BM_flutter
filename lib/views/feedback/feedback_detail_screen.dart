import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/feedback_model.dart';
import '../../services/feedback_service.dart';
import '../../core/routes.dart';

/// Màn hình xem chi tiết góp ý và phản hồi; có nút "Góp ý tiếp" để tạo góp ý mới.
class FeedbackDetailScreen extends StatefulWidget {
  final String feedbackId;

  const FeedbackDetailScreen({super.key, required this.feedbackId});

  @override
  State<FeedbackDetailScreen> createState() => _FeedbackDetailScreenState();
}

class _FeedbackDetailScreenState extends State<FeedbackDetailScreen> {
  FeedbackModel? _feedback;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.feedbackId.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Không tìm thấy góp ý.';
      });
      return;
    }
    final item = await FeedbackService.getById(widget.feedbackId);
    if (mounted) {
      setState(() {
        _feedback = item;
        _loading = false;
        if (item == null) _error = 'Không tìm thấy góp ý.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null || _feedback == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chi tiết góp ý')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_error ?? 'Không tìm thấy góp ý.'),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Quay lại'),
              ),
            ],
          ),
        ),
      );
    }
    final f = _feedback!;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết góp ý'),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, AppRoutes.feedback);
            },
            icon: const Icon(Icons.add),
            label: const Text('Tạo mới'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          f.isResponded ? Icons.check_circle : Icons.feedback_outlined,
                          color: f.isResponded ? Colors.green : theme.colorScheme.primary,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            f.isResponded ? 'Đã phản hồi' : 'Chưa phản hồi',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: f.isResponded ? Colors.green.shade700 : theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Thời gian gửi: ${DateFormat('dd/MM/yyyy HH:mm').format(f.createdAt)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const Divider(height: 24),
                    Text(
                      'Góp ý',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      f.content,
                      style: theme.textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            ),
            if (f.isResponded && f.response != null && f.response!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Card(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.reply_rounded,
                            color: theme.colorScheme.primary,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Phản hồi',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      if (f.respondedAt != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('dd/MM/yyyy HH:mm').format(f.respondedAt!),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Text(
                        f.response!,
                        style: theme.textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, AppRoutes.feedback);
              },
              icon: const Icon(Icons.add),
              label: const Text('Góp ý tiếp'),
            ),
          ],
        ),
      ),
    );
  }
}
