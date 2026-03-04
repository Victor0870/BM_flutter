import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../controllers/auth_provider.dart';
import '../../core/routes.dart';
import '../../models/feedback_model.dart';
import '../../services/feedback_service.dart';

/// Màn hình danh sách góp ý: danh sách hiện đại + nút thêm góp ý.
class FeedbackListScreen extends StatelessWidget {
  const FeedbackListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Góp ý cho phần mềm'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => _openAddFeedback(context),
            tooltip: 'Thêm góp ý',
          ),
        ],
      ),
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          final shopId = authProvider.shop?.id;
          if (shopId == null || shopId.isEmpty) {
            return const Center(child: Text('Vui lòng đăng nhập shop.'));
          }
          return StreamBuilder<QuerySnapshot>(
            stream: FeedbackService.streamByShop(shopId),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Lỗi: ${snapshot.error}'));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snapshot.data!.docs;
              final list = docs
                  .map((d) => FeedbackModel.fromFirestore(
                      d.data() as Map<String, dynamic>, d.id))
                  .toList();
              if (list.isEmpty) {
                return _EmptyState(onAdd: () => _openAddFeedback(context));
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: list.length,
                itemBuilder: (context, index) {
                  final item = list[index];
                  return _FeedbackListTile(
                    feedback: item,
                    onTap: () => Navigator.pushNamed(
                      context,
                      AppRoutes.feedbackDetail,
                      arguments: item.id,
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddFeedback(context),
        icon: const Icon(Icons.add),
        label: const Text('Thêm góp ý'),
      ),
    );
  }

  void _openAddFeedback(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => const _AddFeedbackPage(),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.feedback_outlined,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 24),
            Text(
              'Chưa có góp ý nào',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Gửi góp ý để chúng tôi cải thiện phần mềm.',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Thêm góp ý'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedbackListTile extends StatelessWidget {
  final FeedbackModel feedback;
  final VoidCallback onTap;

  const _FeedbackListTile({
    required this.feedback,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final responded = feedback.isResponded;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: responded
              ? Colors.green.shade100
              : theme.colorScheme.primaryContainer,
          child: Icon(
            responded ? Icons.check_circle : Icons.feedback_outlined,
            color: responded ? Colors.green.shade700 : theme.colorScheme.primary,
            size: 24,
          ),
        ),
        title: Text(
          feedback.content,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: responded ? FontWeight.w500 : FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Text(
                _formatDate(feedback.createdAt),
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (responded) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Đã phản hồi',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.green.shade800,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }

  String _formatDate(DateTime d) {
    final now = DateTime.now();
    if (d.year == now.year && d.month == now.month && d.day == now.day) {
      return 'Hôm nay ${DateFormat.Hm().format(d)}';
    }
    return DateFormat('dd/MM/yyyy HH:mm').format(d);
  }
}

/// Trang thêm góp ý (có kiểm tra rate limit).
class _AddFeedbackPage extends StatefulWidget {
  const _AddFeedbackPage();

  @override
  State<_AddFeedbackPage> createState() => _AddFeedbackPageState();
}

class _AddFeedbackPageState extends State<_AddFeedbackPage> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  String? _rateLimitError;

  @override
  void initState() {
    super.initState();
    _checkRateLimit();
  }

  Future<void> _checkRateLimit() async {
    final auth = context.read<AuthProvider>();
    final userId = auth.user?.uid;
    if (userId == null) return;
    final error = await FeedbackService.canSubmitFeedback(userId);
    if (mounted) setState(() => _rateLimitError = error);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rateLimitError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_rateLimitError!), backgroundColor: Colors.orange),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final shopId = auth.shop?.id;
    final userId = auth.user?.uid;
    if (shopId == null || userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng đăng nhập.'), backgroundColor: Colors.red),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      await FeedbackService.submitFeedback(
        shopId: shopId,
        userId: userId,
        content: _controller.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã gửi góp ý.'), backgroundColor: Colors.green),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thêm góp ý'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (_rateLimitError != null)
              Card(
                color: Colors.orange.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _rateLimitError!,
                          style: TextStyle(color: Colors.orange.shade900),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (_rateLimitError != null) const SizedBox(height: 16),
            TextFormField(
              controller: _controller,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Nội dung góp ý',
                hintText: 'Nhập góp ý của bạn...',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Vui lòng nhập nội dung.';
                return null;
              },
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _loading || _rateLimitError != null ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Gửi góp ý'),
            ),
          ],
        ),
      ),
    );
  }
}
