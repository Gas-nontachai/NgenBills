import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/cards/app_card.dart';
import '../domain/legal_documents.dart';

class LegalDocumentScreen extends StatelessWidget {
  const LegalDocumentScreen({super.key, required this.document});
  final LegalDocument document;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(document.title)),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              AppCard(
                color: AppColors.primarySoft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'เงินบิล — NgenBills',
                      style: AppTypography.title,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'ฉบับ ${LegalDocument.version} · มีผล ${LegalDocument.effectiveDate}',
                      style: AppTypography.small,
                    ),
                    const SizedBox(height: 6),
                    const SelectableText(LegalDocument.provider),
                    const SelectableText(LegalDocument.email),
                  ],
                ),
              ),
              for (final section in document.sections) ...[
                const SizedBox(height: 24),
                Text(section.title, style: AppTypography.title),
                const SizedBox(height: 8),
                SelectableText(section.body, style: AppTypography.body),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
