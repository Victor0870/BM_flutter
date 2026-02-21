import 'package:flutter/material.dart';
import '../../core/routes.dart';
import '../../l10n/app_localizations.dart';

/// Màn hình trung tâm Báo cáo: chọn Báo cáo doanh thu hoặc Báo cáo lợi nhuận.
/// Dùng cho tab Báo cáo trên bottom nav / rail.
class ReportsHubScreen extends StatelessWidget {
  final bool? forceMobile;

  const ReportsHubScreen({super.key, this.forceMobile});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 600 || (forceMobile == true);
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.reports),
      ),
      body: Center(
        child: isMobile ? _buildMobileGrid(context) : _buildDesktopGrid(context),
      ),
    );
  }

  Widget _buildMobileGrid(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            AppLocalizations.of(context)!.selectReportType,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 24),
          _ReportCard(
            icon: Icons.trending_up,
            title: AppLocalizations.of(context)!.salesReport,
            subtitle: AppLocalizations.of(context)!.revenueReportSubtitle,
            color: const Color(0xFF0EA5E9),
            onTap: () => Navigator.pushNamed(context, AppRoutes.salesReport),
          ),
          const SizedBox(height: 16),
          _ReportCard(
            icon: Icons.savings,
            title: AppLocalizations.of(context)!.profitReport,
            subtitle: AppLocalizations.of(context)!.profitReportSubtitle,
            color: const Color(0xFF059669),
            onTap: () => Navigator.pushNamed(context, AppRoutes.profitReport),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopGrid(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(48),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              AppLocalizations.of(context)!.selectReportType,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: _ReportCard(
                    icon: Icons.trending_up,
                    title: AppLocalizations.of(context)!.salesReport,
                    subtitle: AppLocalizations.of(context)!.revenueReportSubtitle,
                    color: const Color(0xFF0EA5E9),
                    onTap: () => Navigator.pushNamed(context, AppRoutes.salesReport),
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: _ReportCard(
                    icon: Icons.savings,
                    title: AppLocalizations.of(context)!.profitReport,
                    subtitle: AppLocalizations.of(context)!.profitReportSubtitle,
                    color: const Color(0xFF059669),
                    onTap: () => Navigator.pushNamed(context, AppRoutes.profitReport),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ReportCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: color),
              const SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
