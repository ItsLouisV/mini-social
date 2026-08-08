import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../social/data/ai_repository.dart';
import '../../../auth/providers/auth_provider.dart';

class AppealsScreen extends ConsumerStatefulWidget {
  const AppealsScreen({super.key});

  @override
  ConsumerState<AppealsScreen> createState() => _AppealsScreenState();
}

class _AppealsScreenState extends ConsumerState<AppealsScreen> {
  final _reasonController = TextEditingController();
  bool _isLoading = true;
  bool _isSubmitting = false;
  List<Map<String, dynamic>> _violations = [];
  List<Map<String, dynamic>> _appeals = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final user = ref.read(authStateProvider).valueOrNull?.session?.user;
    if (user == null) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }

    setState(() => _isLoading = true);

    final repo = ref.read(aiRepositoryProvider);
    final violations = await repo.getViolations(user.id);
    final appeals = await repo.getAppeals(user.id);

    if (mounted) {
      setState(() {
        _violations = violations;
        _appeals = appeals;
        _isLoading = false;
      });
    }
  }

  Future<void> _submitAppeal() async {
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập lý do kháng cáo')),
      );
      return;
    }

    final user = ref.read(authStateProvider).valueOrNull?.session?.user;
    if (user == null) return;

    setState(() => _isSubmitting = true);
    final repo = ref.read(aiRepositoryProvider);
    final success = await repo.submitAppeal(
      userId: user.id,
      reason: reason,
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        _reasonController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đơn kháng cáo đã được gửi thành công!')),
        );
        _loadData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể gửi đơn kháng cáo. Vui lòng thử lại.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch sử vi phạm & Kháng cáo'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Submit Appeal Card
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Gửi đơn kháng cáo mới', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Text(
                              'Nếu bạn tin rằng bài viết hoặc tài khoản của bạn bị nhầm lẫn trong quá trình kiểm duyệt, hãy gửi đơn để ban quản trị xem xét lại.',
                              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _reasonController,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                hintText: 'Mô tả rõ lý do bạn cho rằng quyết định kiểm duyệt chưa chính xác...',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _isSubmitting ? null : _submitAppeal,
                                child: _isSubmitting
                                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                    : const Text('Gửi đơn kháng cáo'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                    Text('Lịch sử vi phạm (Strikes)', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    if (_violations.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: Text('Tài khoản của bạn chưa có vi phạm nào 🎉')),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _violations.length,
                        itemBuilder: (context, index) {
                          final v = _violations[index];
                          final isActive = v['is_active'] == true;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: Icon(
                                isActive ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                                color: isActive ? Colors.red : Colors.green,
                              ),
                              title: Text(v['violation_type']?.toString() ?? 'Vi phạm quy chuẩn'),
                              subtitle: Text('Strike count: +${v['strike_count_at_time'] ?? 1}'),
                              trailing: Chip(
                                label: Text(isActive ? 'Hiệu lực' : 'Đã gỡ', style: const TextStyle(fontSize: 10)),
                                backgroundColor: isActive ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                              ),
                            ),
                          );
                        },
                      ),

                    const SizedBox(height: 24),
                    Text('Các đơn kháng cáo đã gửi', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    if (_appeals.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: Text('Bạn chưa gửi đơn kháng cáo nào')),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _appeals.length,
                        itemBuilder: (context, index) {
                          final a = _appeals[index];
                          final status = a['status']?.toString() ?? 'pending';
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text(a['reason']?.toString() ?? ''),
                              subtitle: Text('Gửi ngày: ${a['created_at']?.toString().split('T').first ?? ''}'),
                              trailing: Chip(
                                label: Text(
                                  status == 'approved' ? 'Đã duyệt' : status == 'rejected' ? 'Bị từ chối' : 'Đang chờ',
                                  style: const TextStyle(fontSize: 10),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}
