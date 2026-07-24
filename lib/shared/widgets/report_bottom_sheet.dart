import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/social/data/ai_repository.dart';
import '../../core/constants/app_text_styles.dart';

class ReportOption {
  final String label;
  final String? categoryName; // Maps to database categories (adult, violence, scam, spam, etc.)
  final List<ReportOption>? children;

  const ReportOption({
    required this.label,
    this.categoryName,
    this.children,
  });
}

// ── CÂY CÂU HỎI BÀI VIẾT & BÌNH LUẬN ──
final List<ReportOption> postCommentReportTree = [
  ReportOption(
    label: 'Nội dung người lớn',
    categoryName: 'adult',
    children: [
      ReportOption(label: 'Ảnh/video khỏa thân', children: [
        ReportOption(label: 'Khỏa thân một phần'),
        ReportOption(label: 'Khỏa thân hoàn toàn'),
        ReportOption(label: 'Có liên quan đến trẻ em'),
      ]),
      ReportOption(label: 'Nội dung gợi dục', children: [
        ReportOption(label: 'Hình ảnh'),
        ReportOption(label: 'Video'),
        ReportOption(label: 'Văn bản'),
        ReportOption(label: 'Bình luận'),
        ReportOption(label: 'Livestream'),
      ]),
      ReportOption(label: 'Mại dâm hoặc môi giới mại dâm'),
      ReportOption(label: 'Khai thác tình dục'),
      ReportOption(label: 'Khác'),
    ],
  ),
  ReportOption(
    label: 'Bóc lột hoặc xâm hại trẻ em',
    categoryName: 'adult',
    children: [
      ReportOption(label: 'Hình ảnh trẻ em nhạy cảm'),
      ReportOption(label: 'Lôi kéo hoặc dụ dỗ trẻ em'),
      ReportOption(label: 'Nội dung tình dục liên quan trẻ em'),
      ReportOption(label: 'Mua bán trẻ em'),
      ReportOption(label: 'Khác'),
    ],
  ),
  ReportOption(
    label: 'Quấy rối hoặc bắt nạt',
    categoryName: 'harassment',
    children: [
      ReportOption(label: 'Chửi bới, xúc phạm', children: [
        ReportOption(label: 'Chửi tục'),
        ReportOption(label: 'Miệt thị ngoại hình'),
        ReportOption(label: 'Miệt thị gia đình'),
        ReportOption(label: 'Làm nhục công khai'),
      ]),
      ReportOption(label: 'Đe dọa', children: [
        ReportOption(label: 'Đe dọa gây thương tích'),
        ReportOption(label: 'Đe dọa giết'),
        ReportOption(label: 'Đe dọa tài sản'),
        ReportOption(label: 'Đe dọa người thân'),
      ]),
      ReportOption(label: 'Quấy rối liên tục'),
      ReportOption(label: 'Tiết lộ thông tin cá nhân'),
      ReportOption(label: 'Kêu gọi người khác tấn công'),
      ReportOption(label: 'Khác'),
    ],
  ),
  ReportOption(
    label: 'Ngôn từ thù ghét',
    categoryName: 'hate_speech',
    children: [
      ReportOption(label: 'Chủng tộc'),
      ReportOption(label: 'Quốc tịch'),
      ReportOption(label: 'Tôn giáo', children: [
        ReportOption(label: 'Xúc phạm tín ngưỡng'),
        ReportOption(label: 'Chế giễu biểu tượng tôn giáo'),
        ReportOption(label: 'Kêu gọi thù ghét'),
      ]),
      ReportOption(label: 'Giới tính', children: [
        ReportOption(label: 'Miệt thị phụ nữ'),
        ReportOption(label: 'Miệt thị nam giới'),
        ReportOption(label: 'Miệt thị LGBT'),
        ReportOption(label: 'Kêu gọi phân biệt đối xử'),
      ]),
      ReportOption(label: 'Xu hướng tính dục'),
      ReportOption(label: 'Người khuyết tật'),
      ReportOption(label: 'Khác'),
    ],
  ),
  ReportOption(
    label: 'Bạo lực hoặc đe dọa',
    categoryName: 'violence',
    children: [
      ReportOption(label: 'Hình ảnh bạo lực', children: [
        ReportOption(label: 'Máu me nhẹ'),
        ReportOption(label: 'Máu me nghiêm trọng'),
        ReportOption(label: 'Thi thể'),
        ReportOption(label: 'Bộ phận cơ thể'),
      ]),
      ReportOption(label: 'Đánh nhau', children: [
        ReportOption(label: 'Một người đánh một người'),
        ReportOption(label: 'Đánh hội đồng'),
        ReportOption(label: 'Bạo hành trẻ em'),
        ReportOption(label: 'Bạo hành động vật'),
      ]),
      ReportOption(label: 'Giết người'),
      ReportOption(label: 'Đe dọa bạo lực'),
      ReportOption(label: 'Kêu gọi bạo lực'),
      ReportOption(label: 'Khác'),
    ],
  ),
  ReportOption(
    label: 'Tự gây hại hoặc tự tử',
    categoryName: 'self_harm',
    children: [
      ReportOption(label: 'Khuyến khích tự tử'),
      ReportOption(label: 'Hướng dẫn tự gây hại'),
      ReportOption(label: 'Hình ảnh tự gây hại'),
      ReportOption(label: 'Người có dấu hiệu cần giúp đỡ'),
      ReportOption(label: 'Khác'),
    ],
  ),
  ReportOption(
    label: 'Ma túy hoặc chất cấm',
    categoryName: 'drug',
    children: [
      ReportOption(label: 'Mua bán'),
      ReportOption(label: 'Sử dụng'),
      ReportOption(label: 'Hướng dẫn sử dụng'),
      ReportOption(label: 'Sản xuất'),
      ReportOption(label: 'Khác'),
    ],
  ),
  ReportOption(
    label: 'Thông tin sai lệch',
    categoryName: 'fake_news',
    children: [
      ReportOption(label: 'Y tế', children: [
        ReportOption(label: 'Thuốc'),
        ReportOption(label: 'Vaccine'),
        ReportOption(label: 'Điều trị bệnh'),
        ReportOption(label: 'Thực phẩm chức năng'),
      ]),
      ReportOption(label: 'Chính trị'),
      ReportOption(label: 'Thiên tai'),
      ReportOption(label: 'Tài chính', children: [
        ReportOption(label: 'Đầu tư'),
        ReportOption(label: 'Tiền điện tử'),
        ReportOption(label: 'Cho vay'),
        ReportOption(label: 'Đa cấp'),
      ]),
      ReportOption(label: 'Người nổi tiếng'),
      ReportOption(label: 'Khác'),
    ],
  ),
  ReportOption(
    label: 'Spam hoặc quảng cáo',
    categoryName: 'spam',
    children: [
      ReportOption(label: 'Quảng cáo', children: [
        ReportOption(label: 'Bán hàng'),
        ReportOption(label: 'Dịch vụ'),
        ReportOption(label: 'Cờ bạc'),
        ReportOption(label: 'Tiền điện tử'),
        ReportOption(label: 'Affiliate'),
      ]),
      ReportOption(label: 'Bình luận hàng loạt'),
      ReportOption(label: 'Nội dung lặp lại'),
      ReportOption(label: 'Link lạ', children: [
        ReportOption(label: 'Link giả mạo'),
        ReportOption(label: 'Link rút gọn đáng ngờ'),
        ReportOption(label: 'Link chứa mã độc'),
        ReportOption(label: 'Link lừa đảo'),
      ]),
      ReportOption(label: 'Tăng tương tác giả'),
      ReportOption(label: 'Khác'),
    ],
  ),
  ReportOption(
    label: 'Lừa đảo hoặc giả mạo',
    categoryName: 'scam',
    children: [
      ReportOption(label: 'Lừa chuyển tiền'),
      ReportOption(label: 'Giả mạo doanh nghiệp'),
      ReportOption(label: 'Giả mạo cá nhân', children: [
        ReportOption(label: 'Giả người quen'),
        ReportOption(label: 'Giả người nổi tiếng'),
        ReportOption(label: 'Giả cán bộ'),
        ReportOption(label: 'Giả nhân viên doanh nghiệp'),
      ]),
      ReportOption(label: 'Đầu tư lừa đảo', children: [
        ReportOption(label: 'Tiền điện tử'),
        ReportOption(label: 'Forex'),
        ReportOption(label: 'Chứng khoán'),
        ReportOption(label: 'Đa cấp'),
      ]),
      ReportOption(label: 'Phishing'),
      ReportOption(label: 'Khác'),
    ],
  ),
  ReportOption(
    label: 'Vi phạm quyền riêng tư',
    categoryName: 'privacy',
    children: [
      ReportOption(label: 'Công khai số điện thoại'),
      ReportOption(label: 'Công khai địa chỉ'),
      ReportOption(label: 'Công khai email'),
      ReportOption(label: 'Công khai giấy tờ cá nhân', children: [
        ReportOption(label: 'CCCD/CMND'),
        ReportOption(label: 'Hộ chiếu'),
        ReportOption(label: 'Bằng lái xe'),
      ]),
      ReportOption(label: 'Chia sẻ ảnh/video riêng tư'),
      ReportOption(label: 'Khác'),
    ],
  ),
  ReportOption(
    label: 'Vi phạm bản quyền',
    categoryName: 'other',
    children: [
      ReportOption(label: 'Hình ảnh'),
      ReportOption(label: 'Video'),
      ReportOption(label: 'Âm nhạc'),
      ReportOption(label: 'Văn bản'),
      ReportOption(label: 'Phần mềm'),
      ReportOption(label: 'Khác'),
    ],
  ),
  ReportOption(
    label: 'Mạo danh người khác',
    categoryName: 'harassment',
    children: [
      ReportOption(label: 'Mạo danh cá nhân'),
      ReportOption(label: 'Mạo danh doanh nghiệp'),
      ReportOption(label: 'Mạo danh người nổi tiếng'),
      ReportOption(label: 'Mạo danh cơ quan nhà nước'),
      ReportOption(label: 'Khác'),
    ],
  ),
  ReportOption(
    label: 'Khác',
    categoryName: 'other',
    children: [
      ReportOption(label: 'Nội dung không phù hợp'),
      ReportOption(label: 'Không tìm thấy lý do phù hợp'),
      ReportOption(label: 'Khác'),
    ],
  ),
];

// ── CÂY CÂU HỎI TIN NHẮN CHAT ──
final List<ReportOption> chatReportTree = [
  ReportOption(
    label: 'Quấy rối hoặc bắt nạt',
    categoryName: 'harassment',
    children: [
      ReportOption(label: 'Chửi bới, xúc phạm', children: [
        ReportOption(label: 'Chửi tục'),
        ReportOption(label: 'Làm nhục'),
        ReportOption(label: 'Miệt thị ngoại hình'),
        ReportOption(label: 'Miệt thị gia đình'),
      ]),
      ReportOption(label: 'Quấy rối liên tục', children: [
        ReportOption(label: 'Gửi tin nhắn liên tục'),
        ReportOption(label: 'Gọi liên tục'),
        ReportOption(label: 'Tạo nhiều tài khoản để nhắn'),
        ReportOption(label: 'Cố tình làm phiền sau khi bị chặn'),
      ]),
      ReportOption(label: 'Đe dọa'),
      ReportOption(label: 'Tống tiền'),
      ReportOption(label: 'Theo dõi hoặc làm phiền'),
      ReportOption(label: 'Khác'),
    ],
  ),
  ReportOption(
    label: 'Ngôn từ thù ghét',
    categoryName: 'hate_speech',
    children: [
      ReportOption(label: 'Chủng tộc'),
      ReportOption(label: 'Quốc tịch'),
      ReportOption(label: 'Tôn giáo', children: [
        ReportOption(label: 'Xúc phạm tín ngưỡng'),
        ReportOption(label: 'Chế giễu biểu tượng tôn giáo'),
        ReportOption(label: 'Kêu gọi thù ghét'),
      ]),
      ReportOption(label: 'Giới tính', children: [
        ReportOption(label: 'Miệt thị phụ nữ'),
        ReportOption(label: 'Miệt thị nam giới'),
        ReportOption(label: 'Miệt thị LGBT'),
      ]),
      ReportOption(label: 'Xu hướng tính dục'),
      ReportOption(label: 'Người khuyết tật'),
      ReportOption(label: 'Khác'),
    ],
  ),
  ReportOption(
    label: 'Đe dọa hoặc bạo lực',
    categoryName: 'violence',
    children: [
      ReportOption(label: 'Đe dọa gây thương tích'),
      ReportOption(label: 'Đe dọa giết'),
      ReportOption(label: 'Kêu gọi bạo lực'),
      ReportOption(label: 'Gửi hình ảnh bạo lực'),
      ReportOption(label: 'Khác'),
      ReportOption(label: 'Đe dọa', children: [
        ReportOption(label: 'Nhắm vào tôi'),
        ReportOption(label: 'Nhắm vào gia đình tôi'),
        ReportOption(label: 'Nhắm vào người khác'),
      ]),
    ],
  ),
  ReportOption(
    label: 'Nội dung người lớn',
    categoryName: 'adult',
    children: [
      ReportOption(label: 'Gửi ảnh/video nhạy cảm'),
      ReportOption(label: 'Gửi nội dung gợi dục', children: [
        ReportOption(label: 'Văn bản'),
        ReportOption(label: 'Hình ảnh'),
        ReportOption(label: 'Video'),
        ReportOption(label: 'Tin nhắn thoại'),
      ]),
      ReportOption(label: 'Gạ gẫm quan hệ tình dục'),
      ReportOption(label: 'Mua bán dâm'),
      ReportOption(label: 'Khác'),
    ],
  ),
  ReportOption(
    label: 'Bóc lột hoặc xâm hại trẻ em',
    categoryName: 'adult',
    children: [
      ReportOption(label: 'Gạ gẫm trẻ em'),
      ReportOption(label: 'Chia sẻ hình ảnh trẻ em nhạy cảm'),
      ReportOption(label: 'Nội dung tình dục liên quan trẻ em'),
      ReportOption(label: 'Khác'),
    ],
  ),
  ReportOption(
    label: 'Lừa đảo hoặc giả mạo',
    categoryName: 'scam',
    children: [
      ReportOption(label: 'Yêu cầu chuyển tiền', children: [
        ReportOption(label: 'Giả người thân'),
        ReportOption(label: 'Giả bạn bè'),
        ReportOption(label: 'Giả nhân viên công ty'),
        ReportOption(label: 'Giả cơ quan nhà nước'),
      ]),
      ReportOption(label: 'Mạo danh người quen'),
      ReportOption(label: 'Mạo danh doanh nghiệp'),
      ReportOption(label: 'Phishing'),
      ReportOption(label: 'Đầu tư lừa đảo', children: [
        ReportOption(label: 'Tiền điện tử'),
        ReportOption(label: 'Forex'),
        ReportOption(label: 'Chứng khoán'),
        ReportOption(label: 'Đa cấp'),
      ]),
      ReportOption(label: 'Khác'),
    ],
  ),
  ReportOption(
    label: 'Ma túy hoặc chất cấm',
    categoryName: 'drug',
    children: [
      ReportOption(label: 'Mua bán'),
      ReportOption(label: 'Hướng dẫn sử dụng'),
      ReportOption(label: 'Rủ rê sử dụng'),
      ReportOption(label: 'Khác'),
    ],
  ),
  ReportOption(
    label: 'Spam',
    categoryName: 'spam',
    children: [
      ReportOption(label: 'Gửi tin nhắn hàng loạt'),
      ReportOption(label: 'Quảng cáo'),
      ReportOption(label: 'Link đáng ngờ', children: [
        ReportOption(label: 'Link lừa đảo'),
        ReportOption(label: 'Link giả mạo'),
        ReportOption(label: 'Link chứa mã độc'),
      ]),
      ReportOption(label: 'Nội dung lặp lại'),
      ReportOption(label: 'Khác'),
    ],
  ),
  ReportOption(
    label: 'Vi phạm quyền riêng tư',
    categoryName: 'privacy',
    children: [
      ReportOption(label: 'Yêu cầu thông tin cá nhân'),
      ReportOption(label: 'Công khai thông tin cá nhân', children: [
        ReportOption(label: 'Số điện thoại'),
        ReportOption(label: 'Địa chỉ'),
        ReportOption(label: 'CCCD/Hộ chiếu'),
        ReportOption(label: 'Tài khoản ngân hàng'),
      ]),
      ReportOption(label: 'Chia sẻ ảnh/video riêng tư'),
      ReportOption(label: 'Đe dọa phát tán thông tin'),
      ReportOption(label: 'Khác'),
    ],
  ),
  ReportOption(
    label: 'Khác',
    categoryName: 'other',
    children: [
      ReportOption(label: 'Không tìm thấy lý do phù hợp'),
      ReportOption(label: 'Nội dung gây khó chịu khác'),
    ],
  ),
];

class ReportBottomSheet extends ConsumerStatefulWidget {
  final String contentId;
  final String contentType; // 'post', 'comment', 'message'
  final String reporterId;

  const ReportBottomSheet({
    super.key,
    required this.contentId,
    required this.contentType,
    required this.reporterId,
  });

  @override
  ConsumerState<ReportBottomSheet> createState() => _ReportBottomSheetState();
}

class _ReportBottomSheetState extends ConsumerState<ReportBottomSheet> {
  // Navigation State
  final List<List<ReportOption>> _history = [];
  List<ReportOption> _currentOptions = [];

  // Selections
  String? _level1Selection;
  String? _level2Selection;
  String? _level3Selection;
  String? _finalCategory;

  bool _showSummary = false;
  bool _submitting = false;

  // Answers & Form fields
  final TextEditingController _descController = TextEditingController();
  
  // Post/Comment only
  String _urgencyLevel = 'medium'; // 'low', 'medium', 'high', 'critical'
  bool _shouldBlockUser = false;
  bool _shouldHideContent = false;

  // Chat message only
  String _reportScope = 'single_message'; // 'single_message', 'multiple_messages', 'full_conversation'
  bool _shouldDeleteConversation = false;

  @override
  void initState() {
    super.initState();
    // Setup initial level 1 based on contentType
    _currentOptions = (widget.contentType == 'message') ? chatReportTree : postCommentReportTree;
  }

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  void _onOptionTapped(ReportOption option) {
    setState(() {
      final level = _history.length + 1;
      if (level == 1) {
        _level1Selection = option.label;
        _finalCategory = option.categoryName;
      } else if (level == 2) {
        _level2Selection = option.label;
      }

      if (option.children != null && option.children!.isNotEmpty) {
        // Navigate deeper
        _history.add(_currentOptions);
        _currentOptions = option.children!;
      } else {
        // Terminated leaf node, set remaining levels as null/N/A
        if (level == 2) {
          _level3Selection = null;
        } else if (level == 3) {
          _level3Selection = option.label;
        }
        _showSummary = true;
      }
    });
  }

  void _goBack() {
    if (_showSummary) {
      setState(() {
        _showSummary = false;
        // Restore correct list depending on how deep we completed
        if (_level3Selection != null) {
          // Re-traverse or just pop history
          _level3Selection = null;
        } else {
          _level2Selection = null;
        }
      });
      return;
    }

    if (_history.isNotEmpty) {
      setState(() {
        _currentOptions = _history.removeLast();
        final currentLevel = _history.length + 1;
        if (currentLevel == 1) {
          _level2Selection = null;
        } else if (currentLevel == 2) {
          _level3Selection = null;
        }
      });
    }
  }

  Future<void> _submitReport() async {
    setState(() => _submitting = true);
    try {
      final desc = _descController.text.trim();
      final success = await ref.read(aiRepositoryProvider).submitReport(
            reporterId: widget.reporterId,
            contentId: widget.contentId,
            contentType: widget.contentType,
            categoryName: _finalCategory ?? 'other',
            description: desc.isNotEmpty ? desc : 'Báo cáo vi phạm tiêu chuẩn cộng đồng',
            reasonLevel1: _level1Selection,
            reasonLevel2: _level2Selection,
            reasonLevel3: _level3Selection,
            urgencyLevel: widget.contentType != 'message' ? _urgencyLevel : null,
            reportScope: widget.contentType == 'message' ? _reportScope : null,
            shouldBlockUser: _shouldBlockUser,
            shouldHideContent: widget.contentType != 'message' ? _shouldHideContent : false,
            shouldDeleteConversation: widget.contentType == 'message' ? _shouldDeleteConversation : false,
          );

      if (success) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cảm ơn bạn đã báo cáo. Chúng tôi sẽ xem xét nội dung này sớm nhất.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('Gửi báo cáo thất bại');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final titleText = widget.contentType == 'message'
        ? 'Báo cáo cuộc trò chuyện hoặc tin nhắn'
        : 'Báo cáo bài viết hoặc bình luận';

    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header Drag Handle & Back Button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: Row(
              children: [
                if (_history.isNotEmpty || _showSummary)
                  IconButton(
                    icon: const Icon(CupertinoIcons.left_chevron),
                    onPressed: _goBack,
                  )
                else
                  const SizedBox(width: 48),
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white24 : Colors.black12,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        titleText,
                        style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(CupertinoIcons.xmark),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Content body
          Expanded(
            child: _submitting
                ? const Center(child: CupertinoActivityIndicator(radius: 14))
                : _showSummary
                    ? _buildSummaryScreen()
                    : _buildOptionsList(),
          ),
        ],
      ),
    );
  }

  // ── SCREEN 1: OPTIONS SELECTION TREE ──
  Widget _buildOptionsList() {
    final theme = Theme.of(context);
    final currentLevel = _history.length + 1;
    final levelText = currentLevel == 1
        ? 'Điều gì không ổn với nội dung này?'
        : currentLevel == 2
            ? 'Chọn loại vi phạm cụ thể'
            : 'Phân loại chi tiết vi phạm';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            levelText,
            style: AppTextStyles.caption.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: theme.hintColor,
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _currentOptions.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final option = _currentOptions[index];
              final hasChildren = option.children != null && option.children!.isNotEmpty;

              return InkWell(
                onTap: () => _onOptionTapped(option),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              option.label,
                              style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        hasChildren ? CupertinoIcons.chevron_right : CupertinoIcons.arrow_right_circle_fill,
                        size: 16,
                        color: hasChildren ? theme.hintColor : const Color(0xFF2E7D32),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── SCREEN 2: SUMMARY & DYNAMIC FORM FIELDS ──
  Widget _buildSummaryScreen() {
    final theme = Theme.of(context);

    final summaryPath = [
      _level1Selection,
      _level2Selection,
      if (_level3Selection != null) _level3Selection
    ].join(' ➔ ');

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Resume card selection path
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF2E7D32).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF2E7D32).withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'LÝ DO BÁO CÁO ĐÃ CHỌN',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2E7D32),
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                summaryPath,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Description textfield
        Text(
          'Mô tả thêm (không bắt buộc)',
          style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _descController,
          maxLines: 3,
          style: AppTextStyles.bodyMedium,
          decoration: InputDecoration(
            hintText: 'Bạn có thể mô tả chi tiết hơn để giúp chúng tôi xem xét báo cáo nhanh hơn...',
            hintStyle: AppTextStyles.caption,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: theme.dividerColor),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // 🟢 FOR POSTS/COMMENTS: Urgency level & Hide content
        if (widget.contentType != 'message') ...[
          Text(
            'Mức độ khẩn cấp',
            style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildUrgencyChip('Thấp', 'low', Colors.green),
              _buildUrgencyChip('Trung bình', 'medium', Colors.orange),
              _buildUrgencyChip('Cao', 'high', Colors.amber.shade800),
              _buildUrgencyChip('Khẩn cấp', 'critical', Colors.red),
            ],
          ),
          const SizedBox(height: 20),
          _buildFormToggle(
            title: 'Ẩn nội dung tương tự',
            subtitle: 'Bạn sẽ không nhìn thấy các nội dung tương đương trong tương lai',
            value: _shouldHideContent,
            onChanged: (val) => setState(() => _shouldHideContent = val),
          ),
        ],

        // 💬 FOR CHAT MESSAGES: Scope & Delete Chat
        if (widget.contentType == 'message') ...[
          Text(
            'Bạn muốn báo cáo điều gì?',
            style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          _buildScopeRadio('Tin nhắn này', 'single_message'),
          _buildScopeRadio('Nhiều tin nhắn trong cuộc trò chuyện', 'multiple_messages'),
          _buildScopeRadio('Toàn bộ cuộc trò chuyện', 'full_conversation'),
          const SizedBox(height: 20),
          _buildFormToggle(
            title: 'Xóa cuộc trò chuyện',
            subtitle: 'Xóa hoàn toàn lịch sử chat này khỏi danh sách chat của bạn',
            value: _shouldDeleteConversation,
            onChanged: (val) => setState(() => _shouldDeleteConversation = val),
          ),
        ],

        // Block user option
        _buildFormToggle(
          title: 'Chặn tài khoản này',
          subtitle: 'Họ sẽ không thể tìm kiếm, gửi tin nhắn hay bình luận bài đăng của bạn',
          value: _shouldBlockUser,
          onChanged: (val) => setState(() => _shouldBlockUser = val),
        ),
        const SizedBox(height: 28),

        // Submit Button (Strictly Green Bg, White Text)
        ElevatedButton(
          onPressed: _submitReport,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2E7D32), // Green
            foregroundColor: Colors.white,
            elevation: 2,
            shadowColor: Colors.black45,
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: const Text(
            'Gửi báo cáo',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.white, // Strict white color
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUrgencyChip(String label, String value, Color color) {
    final isSelected = _urgencyLevel == value;
    return GestureDetector(
      onTap: () => setState(() => _urgencyLevel = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withValues(alpha: 0.1),
          border: Border.all(color: color.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : color,
          ),
        ),
      ),
    );
  }

  Widget _buildScopeRadio(String label, String value) {
    return RadioListTile<String>(
      title: Text(label, style: AppTextStyles.bodyMedium),
      value: value,
      groupValue: _reportScope,
      activeColor: const Color(0xFF2E7D32),
      contentPadding: EdgeInsets.zero,
      onChanged: (val) {
        if (val != null) {
          setState(() => _reportScope = val);
        }
      },
    );
  }

  Widget _buildFormToggle({
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            activeColor: const Color(0xFF2E7D32),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
