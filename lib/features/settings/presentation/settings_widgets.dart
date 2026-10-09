import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/cards/app_card.dart';

class SettingsSectionTitle extends StatelessWidget {
  const SettingsSectionTitle(this.title, {super.key});
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 18, bottom: 8, left: 4),
    child: Text(title, style: AppTypography.title.copyWith(fontSize: 16)),
  );
}

class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.destructive = false,
    this.uniform = false,
    this.compact = false,
  });
  final IconData icon;
  final String title, subtitle;
  final VoidCallback? onTap;
  final bool destructive;
  final bool uniform;
  final bool compact;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: compact ? 6 : 8),
    child: AppCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 12 : 14,
            vertical: compact ? 10 : 12,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(compact ? 6 : 8),
                decoration: BoxDecoration(
                  color: destructive
                      ? AppColors.errorSoft
                      : AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  size: compact ? 18 : 20,
                  color: destructive ? AppColors.error : AppColors.primaryDark,
                ),
              ),
              SizedBox(width: compact ? 10 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.title.copyWith(
                        fontSize: compact ? 14 : 16,
                        color: destructive ? AppColors.error : AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    if (uniform)
                      SizedBox(
                        height:
                            MediaQuery.textScalerOf(context).scale(13) *
                            1.4 *
                            2,
                        child: Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.small.copyWith(
                            fontSize: 13,
                            height: 1.4,
                          ),
                          strutStyle: const StrutStyle(
                            fontFamily: 'Kanit',
                            fontSize: 13,
                            height: 1.4,
                            forceStrutHeight: true,
                          ),
                        ),
                      )
                    else
                      Text(
                        subtitle,
                        style: AppTypography.small.copyWith(
                          fontSize: compact ? 12 : 13,
                          height: 1.4,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: onTap == null ? AppColors.border : AppColors.secondary,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Secondary settings share a card and keep a comfortable tap target.
class SettingsLink extends StatelessWidget {
  const SettingsLink({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 52),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: AppColors.primarySoft.withValues(alpha: .6),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, size: 17, color: AppColors.primaryDark),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: AppTypography.small.copyWith(
                  color: AppColors.text,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: onTap == null
                  ? AppColors.border
                  : AppColors.secondary.withValues(alpha: .7),
            ),
          ],
        ),
      ),
    ),
  );
}
