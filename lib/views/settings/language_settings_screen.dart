import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/locale_provider.dart';
import '../../l10n/app_localizations.dart';

/// Màn chọn ngôn ngữ: 2 lựa chọn (Tiếng Việt, English).
/// Giao diện giống trang Thiết lập cửa hàng / Thông tin tài khoản.
class LanguageSettingsScreen extends StatelessWidget {
  const LanguageSettingsScreen({super.key});

  static const Color _bluePrimary = Color(0xFF2563EB);
  static const Color _blueLight = Color(0xFFEFF6FF);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          l10n.language,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E293B),
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          children: [
            _buildHeader(context),
            const SizedBox(height: 24),
            _buildOptionsCard(context, l10n),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: _blueLight,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.language_rounded,
            size: 26,
            color: _bluePrimary,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context)!.language,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                AppLocalizations.of(context)!.selectLanguage,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOptionsCard(BuildContext context, AppLocalizations l10n) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          _buildLanguageTile(
            context: context,
            locale: const Locale('vi'),
            label: 'Tiếng Việt',
          ),
          Divider(height: 1, color: Colors.grey.shade200),
          _buildLanguageTile(
            context: context,
            locale: const Locale('en'),
            label: 'English',
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageTile({
    required BuildContext context,
    required Locale locale,
    required String label,
  }) {
    return Consumer<LocaleProvider>(
      builder: (context, localeProvider, _) {
        final isSelected = localeProvider.locale.languageCode == locale.languageCode;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () async {
              await localeProvider.setLocale(locale);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Đã chọn: $label'),
                    backgroundColor: Colors.green,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                Navigator.of(context).pop();
              }
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                children: [
                  Icon(
                    Icons.translate,
                    size: 22,
                    color: isSelected ? _bluePrimary : Colors.grey.shade600,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected ? _bluePrimary : const Color(0xFF1E293B),
                      ),
                    ),
                  ),
                  if (isSelected)
                    const Icon(
                      Icons.check_circle,
                      color: _bluePrimary,
                      size: 24,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
