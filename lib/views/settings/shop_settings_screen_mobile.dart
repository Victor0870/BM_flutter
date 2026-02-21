import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_provider.dart';
import '../../core/routes.dart';
import '../../l10n/app_localizations.dart';

/// Card thông tin tài khoản (Email + Gói dịch vụ).
/// [useMobileLayout]: true = bố cục dọc, false = bố cục ngang.
/// Trên mobile, tap vào card sẽ mở màn hình Tài khoản & Gói dịch vụ.
class ShopSettingsAccountInfoCard extends StatelessWidget {
  const ShopSettingsAccountInfoCard({
    super.key,
    required this.useMobileLayout,
  });

  final bool useMobileLayout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        final email = authProvider.user?.email ?? '—';
        final isPro = authProvider.isPro;

        final cardContent = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.person_outline, color: colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context)!.accountInfo,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (useMobileLayout)
                    Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: useMobileLayout
                  ? _AccountInfoMobileLayout(
                      email: email,
                      isPro: isPro,
                      theme: theme,
                      colorScheme: colorScheme,
                    )
                  : _AccountInfoDesktopLayout(
                      email: email,
                      isPro: isPro,
                      theme: theme,
                      colorScheme: colorScheme,
                    ),
            ),
          ],
        );

        final card = Card(child: cardContent);

        if (useMobileLayout) {
          return InkWell(
            onTap: () {
              Navigator.of(context).pushNamed(AppRoutes.accountPackage);
            },
            borderRadius: BorderRadius.circular(12),
            child: card,
          );
        }
        return card;
      },
    );
  }
}

/// Bố cục dọc: Email rồi đến gói dịch vụ.
class _AccountInfoMobileLayout extends StatelessWidget {
  final String email;
  final bool isPro;
  final ThemeData theme;
  final ColorScheme colorScheme;

  const _AccountInfoMobileLayout({
    required this.email,
    required this.isPro,
    required this.theme,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.email_outlined, size: 20, color: colorScheme.onSurfaceVariant),
          title: Text(
            AppLocalizations.of(context)!.loginEmail,
            style: theme.textTheme.labelLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          subtitle: SelectableText(
            email,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: 12),
        _PlanBadgeAndNote(
          isPro: isPro,
          theme: theme,
          colorScheme: colorScheme,
        ),
      ],
    );
  }
}

/// Bố cục ngang: Email bên trái, gói dịch vụ bên phải.
class _AccountInfoDesktopLayout extends StatelessWidget {
  final String email;
  final bool isPro;
  final ThemeData theme;
  final ColorScheme colorScheme;

  const _AccountInfoDesktopLayout({
    required this.email,
    required this.isPro,
    required this.theme,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.email_outlined, size: 20, color: colorScheme.onSurfaceVariant),
            title: Text(
              'Email đăng nhập',
              style: theme.textTheme.labelLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            subtitle: SelectableText(
              email,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: _PlanBadgeAndNote(
            isPro: isPro,
            theme: theme,
            colorScheme: colorScheme,
          ),
        ),
      ],
    );
  }
}

/// Nhãn gói dịch vụ (PRO/BASIC) và chú thích / nút Nâng cấp.
class _PlanBadgeAndNote extends StatelessWidget {
  final bool isPro;
  final ThemeData theme;
  final ColorScheme colorScheme;

  const _PlanBadgeAndNote({
    required this.isPro,
    required this.theme,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isPro
                ? colorScheme.primaryContainer
                : colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            isPro ? 'Gói dịch vụ: PRO' : 'Gói dịch vụ: BASIC',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: isPro ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          isPro
              ? 'Đã mở khóa đồng bộ Cloud và tính năng Real-time.'
              : 'Chế độ Offline-only.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Nếu bạn vừa được gia hạn/nâng cấp gói, hãy đăng xuất rồi đăng nhập lại để áp dụng.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
        if (!isPro) ...[
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(AppLocalizations.of(context)!.contactAdminUpgrade),
                  duration: const Duration(seconds: 3),
                ),
              );
            },
            child: Text(AppLocalizations.of(context)!.upgrade),
          ),
        ],
      ],
    );
  }
}

/// Layout body cho màn hình Cài đặt shop - Mobile.
/// Nhận nội dung form đã build sẵn từ coordinator.
class ShopSettingsMobileBody extends StatelessWidget {
  const ShopSettingsMobileBody({
    super.key,
    required this.formContent,
  });

  final Widget formContent;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: formContent,
    );
  }
}
