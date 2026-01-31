import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/payment_service.dart';
import '../controllers/sales_provider.dart';

/// Dialog hiển thị QR code thanh toán và tự động polling trạng thái
class PaymentQRDialog extends StatefulWidget {
  final String orderId;
  final double amount;
  final String qrData;
  final PaymentService paymentService;
  final SalesProvider salesProvider;
  final bool autoConfirm; // Tự động xác nhận hay không
  final VoidCallback? onCancel;
  final VoidCallback? onPaymentSuccess;

  const PaymentQRDialog({
    super.key,
    required this.orderId,
    required this.amount,
    required this.qrData,
    required this.paymentService,
    required this.salesProvider,
    this.autoConfirm = true, // Mặc định bật tự động xác nhận
    this.onCancel,
    this.onPaymentSuccess,
  });

  @override
  State<PaymentQRDialog> createState() => _PaymentQRDialogState();
}

class _PaymentQRDialogState extends State<PaymentQRDialog> {
  bool _isPolling = false;
  bool _isPaid = false;
  Timer? _pollingTimer;
  int _pollingCount = 0;
  static const int _maxPollingAttempts = 60; // 60 * 5s = 5 phút

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void dispose() {
    _stopPolling();
    super.dispose();
  }

  void _startPolling() {
    if (_isPolling) return;

    setState(() {
      _isPolling = true;
    });

    // Chỉ bắt đầu polling nếu autoConfirm = true
    if (widget.autoConfirm) {
      widget.salesProvider.startPaymentPolling(widget.orderId, widget.paymentService);
      
      // Polling timer để hiển thị UI
      _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
        if (_pollingCount >= _maxPollingAttempts) {
          _stopPolling();
          if (mounted) {
            setState(() {
              _isPolling = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Hết thời gian chờ thanh toán. Vui lòng thử lại.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }

        _pollingCount++;

        try {
          final isPaid = await widget.paymentService.checkPaymentStatus(widget.orderId);
          if (isPaid && mounted) {
            setState(() {
              _isPaid = true;
              _isPolling = false;
            });
            _stopPolling();

            // Đợi một chút để salesProvider xử lý xong
            await Future.delayed(const Duration(milliseconds: 500));

            if (mounted) {
              Navigator.of(context).pop();
              if (widget.onPaymentSuccess != null) {
                widget.onPaymentSuccess!();
              }
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('✅ Thanh toán thành công!'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 3),
                ),
              );
            }
          }
        } catch (e) {
          // Log error nhưng tiếp tục polling
          debugPrint('Payment polling error: $e');
        }
      });
    }
  }

  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  void _handleCancel() {
    _stopPolling();
    if (widget.onCancel != null) {
      widget.onCancel!();
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Thanh toán chuyển khoản',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _handleCancel,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // QR Code
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  QrImageView(
                    data: widget.qrData,
                    version: QrVersions.auto,
                    size: 250,
                    backgroundColor: Colors.white,
                  ),
                  // Loading indicator overlay
                  if (_isPolling && !_isPaid)
                    Container(
                      width: 250,
                      height: 250,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  // Success overlay
                  if (_isPaid)
                    Container(
                      width: 250,
                      height: 250,
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.check_circle,
                        color: Colors.white,
                        size: 80,
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Thông tin thanh toán
            Text(
              'Số tiền: ${_formatCurrency(widget.amount)}',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Mã đơn hàng: ${widget.orderId}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),

            // Trạng thái
            if (!_isPaid)
              Column(
                children: [
                  Text(
                    widget.autoConfirm 
                        ? 'Đang chờ thanh toán...' 
                        : 'Chờ khách quét mã QR',
                    style: TextStyle(
                      fontSize: 16,
                      color: widget.autoConfirm ? Colors.orange : Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.autoConfirm
                        ? 'Vui lòng quét mã QR bằng ứng dụng ngân hàng. Hệ thống sẽ tự động xác nhận khi nhận được tiền.'
                        : 'Vui lòng quét mã QR bằng ứng dụng ngân hàng. Sau khi khách chuyển tiền, nhấn nút "Xác nhận đã nhận tiền" bên dưới.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            if (_isPaid)
              const Text(
                '✅ Thanh toán thành công!',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),

            const SizedBox(height: 24),

            // Nút Xác nhận đã nhận tiền (chỉ hiện khi autoConfirm = false)
            if (!widget.autoConfirm && !_isPaid)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      // Kiểm tra trạng thái thanh toán trước khi xác nhận
                      final isPaid = await widget.paymentService.checkPaymentStatus(widget.orderId);
                      if (isPaid) {
                        // Thanh toán thành công, hoàn tất đơn hàng
                        setState(() {
                          _isPaid = true;
                        });
                        await widget.salesProvider.completeTransferPayment(widget.orderId);
                        await Future.delayed(const Duration(milliseconds: 500));
                        if (!context.mounted) return;
                        Navigator.of(context).pop();
                        if (widget.onPaymentSuccess != null) {
                          widget.onPaymentSuccess!();
                        }
                      } else {
                        // Chưa nhận được tiền, yêu cầu xác nhận thủ công
                        if (!context.mounted) return;
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Xác nhận thủ công'),
                            content: const Text(
                              'Hệ thống chưa nhận được thông báo thanh toán từ ngân hàng. Bạn có chắc chắn đã nhận được tiền chuyển khoản từ khách hàng?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Hủy'),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(context, true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                ),
                                child: const Text('Xác nhận đã nhận'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true && mounted) {
                          // Xác nhận thủ công - hoàn tất đơn hàng
                          setState(() {
                            _isPaid = true;
                          });
                          await widget.salesProvider.completeTransferPayment(widget.orderId);
                          await Future.delayed(const Duration(milliseconds: 500));
                          if (!context.mounted) return;
                          Navigator.of(context).pop();
                          if (widget.onPaymentSuccess != null) {
                            widget.onPaymentSuccess!();
                          }
                        }
                      }
                    },
                    icon: const Icon(Icons.check_circle),
                    label: const Text('Xác nhận đã nhận tiền'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ),

            // Nút Hủy
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _handleCancel,
                child: const Text('Hủy / Quay lại'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCurrency(double amount) {
    return '${amount.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        )} ₫';
  }
}

