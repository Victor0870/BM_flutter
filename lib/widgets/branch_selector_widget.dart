import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/branch_provider.dart';
import '../controllers/product_provider.dart';
import '../models/branch_model.dart';

/// Widget để chọn chi nhánh với loading và tự động refresh dữ liệu
class BranchSelectorWidget extends StatefulWidget {
  final bool isCompact; // Nếu true, hiển thị dạng compact (chỉ icon + text ngắn)
  final bool showLabel; // Hiển thị label "Chi nhánh:"
  
  const BranchSelectorWidget({
    super.key,
    this.isCompact = false,
    this.showLabel = false,
  });

  @override
  State<BranchSelectorWidget> createState() => _BranchSelectorWidgetState();
}

class _BranchSelectorWidgetState extends State<BranchSelectorWidget> {
  bool _isChangingBranch = false;

  Future<void> _handleBranchChange(
    BuildContext context,
    String newBranchId,
    BranchProvider branchProvider,
  ) async {
    if (_isChangingBranch) return;
    
    setState(() {
      _isChangingBranch = true;
    });

    try {
      // Cập nhật chi nhánh được chọn
      await branchProvider.setSelectedBranch(newBranchId);
      
      // Refresh các provider khác
      final productProvider = Provider.of<ProductProvider>(context, listen: false);
      
      // Load lại dữ liệu theo chi nhánh mới
      // Sales và Purchase sẽ tự động lọc theo branchId khi được gọi
      await productProvider.loadProducts();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã chuyển sang chi nhánh: ${branchProvider.branches.firstWhere((b) => b.id == newBranchId).name}'),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi chuyển chi nhánh: $e'),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isChangingBranch = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BranchProvider>(
      builder: (context, branchProvider, child) {
        // Load branches nếu chưa có
        if (branchProvider.branches.isEmpty && 
            !branchProvider.isLoading) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            branchProvider.loadBranches();
          });
        }

        final branches = branchProvider.branches.where((b) => b.isActive).toList();
        final currentBranchId = branchProvider.currentBranchId;
        
        if (branches.isEmpty) {
          return const SizedBox.shrink();
        }

        // Tìm chi nhánh hiện tại
        final currentBranch = branches.firstWhere(
          (b) => b.id == currentBranchId,
          orElse: () => branches.first,
        );

        if (widget.isCompact) {
          // Hiển thị dạng compact (ActionChip)
          return ActionChip(
            avatar: _isChangingBranch
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.store, size: 16, color: Colors.white),
            label: _isChangingBranch
                ? const Text('Đang chuyển...', style: TextStyle(color: Colors.white))
                : Text(
                    currentBranch.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
            backgroundColor: Theme.of(context).colorScheme.primary,
            onPressed: _isChangingBranch
                ? null
                : () {
                    _showBranchSelectionDialog(
                      context,
                      branches,
                      currentBranchId ?? '',
                      branchProvider,
                    );
                  },
          );
        }

        // Hiển thị dạng DropdownButton (mặc định)
        return Row(
          children: [
            if (widget.showLabel) ...[
              const Text(
                'Chi nhánh:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Row(
                children: [
                  // Icon bên ngoài dropdown (chỉ hiển thị 1 lần)
                  if (_isChangingBranch)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Icon(
                      Icons.store,
                      size: 18,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  const SizedBox(width: 8),
                  // Dropdown button
                  Expanded(
                    child: DropdownButton<String>(
                      value: currentBranchId,
                      hint: const Text(
                        'Chọn chi nhánh',
                        overflow: TextOverflow.ellipsis,
                      ),
                      isDense: true,
                      isExpanded: true, // Cho phép dropdown mở rộng để tránh overflow
                      underline: Container(), // Ẩn underline mặc định
                items: branches.map((branch) {
                  return DropdownMenuItem<String>(
                    value: branch.id,
                    child: Row(
                      children: [
                        Icon(
                          Icons.store,
                          size: 16,
                          color: branch.id == currentBranchId
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            branch.name,
                            style: TextStyle(
                              fontWeight: branch.id == currentBranchId
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: branch.id == currentBranchId
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: _isChangingBranch
                    ? null
                    : (String? newBranchId) {
                        if (newBranchId != null && newBranchId != currentBranchId) {
                          _handleBranchChange(
                            context,
                            newBranchId,
                            branchProvider,
                          );
                        }
                      },
                selectedItemBuilder: (BuildContext context) {
                  return branches.map((branch) {
                    // Chỉ hiển thị text, không có icon để tránh trùng lặp
                    return Row(
                      children: [
                        if (_isChangingBranch)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        Flexible(
                          child: Text(
                            branch.name,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    );
                  }).toList();
                },
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  void _showBranchSelectionDialog(
    BuildContext context,
    List<BranchModel> branches,
    String currentBranchId,
    BranchProvider branchProvider,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Chọn chi nhánh'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: branches.length,
              itemBuilder: (context, index) {
                final branch = branches[index];
                final isSelected = branch.id == currentBranchId;
                
                return ListTile(
                  leading: Icon(
                    Icons.store,
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey,
                  ),
                  title: Text(
                    branch.name,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                  ),
                  trailing: isSelected
                      ? Icon(
                          Icons.check_circle,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      : null,
                  onTap: () {
                    Navigator.of(context).pop();
                    if (branch.id != currentBranchId) {
                      _handleBranchChange(context, branch.id, branchProvider);
                    }
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }
}
