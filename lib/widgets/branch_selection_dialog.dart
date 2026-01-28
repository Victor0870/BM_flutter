import 'package:flutter/material.dart';
import '../models/branch_model.dart';

/// Dialog để Admin chọn chi nhánh làm việc
class BranchSelectionDialog extends StatelessWidget {
  final List<BranchModel> branches;
  final String? currentBranchId;
  final Function(String) onBranchSelected;

  const BranchSelectionDialog({
    super.key,
    required this.branches,
    this.currentBranchId,
    required this.onBranchSelected,
  });

  @override
  Widget build(BuildContext context) {
    String? selectedBranchId = currentBranchId ?? (branches.isNotEmpty ? branches.first.id : null);

    return StatefulBuilder(
      builder: (context, setState) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.store, color: Colors.blue),
              SizedBox(width: 8),
              Text('Chọn chi nhánh làm việc'),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: branches.isEmpty
                ? const Text('Chưa có chi nhánh nào. Vui lòng tạo chi nhánh trước.')
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Vui lòng chọn chi nhánh bạn muốn làm việc:',
                        style: TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 16),
                      ...branches.map((branch) {
                        final isSelected = branch.id == selectedBranchId;
                        return RadioListTile<String>(
                          title: Row(
                            children: [
                              Icon(
                                Icons.store,
                                size: 18,
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.grey,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  branch.name,
                                  style: TextStyle(
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    color: isSelected
                                        ? Theme.of(context).colorScheme.primary
                                        : null,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          value: branch.id,
                          groupValue: selectedBranchId,
                          onChanged: (String? value) {
                            if (value != null) {
                              setState(() {
                                selectedBranchId = value;
                              });
                            }
                          },
                        );
                      }).toList(),
                    ],
                  ),
          ),
          actions: [
            if (branches.isNotEmpty) ...[
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Hủy'),
              ),
              ElevatedButton(
                onPressed: selectedBranchId != null
                    ? () {
                        Navigator.of(context).pop();
                        onBranchSelected(selectedBranchId!);
                      }
                    : null,
                child: const Text('Xác nhận'),
              ),
            ] else
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Đóng'),
              ),
          ],
        );
      },
    );
  }

  /// Hiển thị dialog chọn chi nhánh
  static Future<String?> show(
    BuildContext context, {
    required List<BranchModel> branches,
    String? currentBranchId,
  }) async {
    String? selectedBranchId;
    
    await showDialog(
      context: context,
      barrierDismissible: false, // Không cho phép đóng bằng cách tap bên ngoài
      builder: (BuildContext context) {
        return BranchSelectionDialog(
          branches: branches,
          currentBranchId: currentBranchId,
          onBranchSelected: (branchId) {
            selectedBranchId = branchId;
          },
        );
      },
    );
    
    return selectedBranchId;
  }
}
