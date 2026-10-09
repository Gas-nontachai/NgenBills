import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/formatters/date_formatter.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/cards/app_card.dart';
import '../../../core/widgets/sheets/app_bottom_sheet.dart';
import '../../settings/domain/legal_documents.dart';
import '../../settings/presentation/legal_document_screen.dart';
import '../data/backup_service.dart';

class BackupInfoSheet extends StatelessWidget {
  const BackupInfoSheet({super.key});

  @override
  Widget build(BuildContext context) => AppBottomSheet(
    title: 'สำรองข้อมูล',
    onClose: () => Navigator.of(context).pop(false),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'รวมข้อมูลทั้งแอพไว้ในไฟล์ .ngenbills เดียว',
          style: AppTypography.small,
        ),
        const SizedBox(height: 12),
        const _SectionLabel('ข้อมูลที่อยู่ในไฟล์'),
        const AppCard(
          padding: EdgeInsets.all(12),
          child: Column(
            children: [
              _DetailRow(
                Icons.account_balance_wallet_outlined,
                'บัญชีหนี้ทั้งหมด',
                'ชื่อ ยอดเริ่มต้น หมายเหตุ ไอคอน และสี',
              ),
              SizedBox(height: 10),
              _DetailRow(
                Icons.receipt_long_outlined,
                'ประวัติทั้งหมด',
                'รายการจ่ายและกู้เพิ่ม พร้อมยอด วันที่ และหมายเหตุ',
              ),
              SizedBox(height: 10),
              _DetailRow(
                Icons.tune_rounded,
                'การตั้งค่าแอพ',
                'บัญชีหลัก วันและเวลาเตือน และสถานะการตั้งค่าครั้งแรก',
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const _SectionLabel('การจัดเก็บและความเป็นส่วนตัว'),
        const AppCard(
          padding: EdgeInsets.all(12),
          color: AppColors.primarySoft,
          child: Column(
            children: [
              _DetailRow(
                Icons.folder_outlined,
                'คุณเลือกที่บันทึกเอง',
                'การสำรองไม่ลบหรือแทนที่ข้อมูลในแอพ',
              ),
              SizedBox(height: 10),
              _DetailRow(
                Icons.lock_open_outlined,
                'ไฟล์ไม่เข้ารหัสและไม่มีรหัสผ่าน',
                'ผู้ที่มีไฟล์สามารถอ่านและกู้คืนข้อมูลได้ โปรดเก็บในที่ปลอดภัย',
              ),
              SizedBox(height: 10),
              _DetailRow(
                Icons.cloud_off_outlined,
                'แอพไม่อัปโหลดไปยัง server',
                'หากเลือกพื้นที่ cloud ในตัวเลือกไฟล์ จะใช้นโยบายของบริการนั้น',
              ),
            ],
          ),
        ),
        const _PrivacyLink(),
        const SizedBox(height: 8),
        AppButton(
          label: 'สำรองและเลือกที่บันทึก',
          icon: Icons.file_download_outlined,
          onPressed: () => Navigator.of(context).pop(true),
        ),
        const SizedBox(height: 6),
        AppButton(
          label: 'ยกเลิก',
          variant: AppButtonVariant.secondary,
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ],
    ),
  );
}

class RestorePreviewSheet extends StatelessWidget {
  const RestorePreviewSheet({
    super.key,
    required this.snapshot,
    required this.fileName,
  });
  final BackupSnapshot snapshot;
  final String fileName;

  @override
  Widget build(BuildContext context) {
    final local = snapshot.createdAt.toLocal();
    final time =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    return AppBottomSheet(
      title: 'ตรวจสอบก่อนกู้คืน',
      onClose: () => Navigator.of(context).pop(false),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppCard(
            padding: const EdgeInsets.all(12),
            color: AppColors.primarySoft,
            child: _DetailRow(
              Icons.description_outlined,
              fileName,
              'สำรองเมื่อ ${AppDates.format(local)} · $time น.',
            ),
          ),
          const SizedBox(height: 14),
          const _SectionLabel('ข้อมูลที่จะกู้คืน'),
          AppCard(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                _DetailRow(
                  Icons.account_balance_wallet_outlined,
                  '${snapshot.accountCount} บัญชี',
                  'รวมชื่อ ยอดเริ่มต้น หมายเหตุ ไอคอน และสี',
                ),
                const SizedBox(height: 10),
                _DetailRow(
                  Icons.receipt_long_outlined,
                  '${snapshot.paymentCount} รายการจ่าย · ${snapshot.borrowingCount} รายการกู้เพิ่ม',
                  'ประวัติ ยอด วันที่ และหมายเหตุจากไฟล์',
                ),
                const SizedBox(height: 10),
                const _DetailRow(
                  Icons.tune_rounded,
                  'การตั้งค่าทั้งหมด',
                  'ใช้บัญชีหลักและการตั้งค่าแจ้งเตือนจากไฟล์ สิทธิ์แจ้งเตือนยังใช้ของเครื่องนี้',
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          AppCard(
            padding: const EdgeInsets.all(12),
            color: AppColors.errorSoft,
            child: _DetailRow(
              Icons.restore_rounded,
              'ข้อมูลปัจจุบันทั้งหมดจะถูกแทนที่',
              snapshot.accountCount == 0
                  ? 'ไฟล์นี้ไม่มีบัญชี การกู้คืนจะล้างข้อมูลปัจจุบันและแสดงหน้าว่าง หากต้องการเก็บข้อมูลเดิม ให้ยกเลิกและสำรองก่อน'
                  : 'ไม่รวมข้อมูลเดิมเข้ากับไฟล์ หากต้องการเก็บข้อมูลปัจจุบัน ให้ยกเลิกและสำรองก่อนยืนยัน',
            ),
          ),
          const _PrivacyLink(),
          const SizedBox(height: 8),
          AppButton(
            label: 'กู้คืนและแทนที่ข้อมูลทั้งหมด',
            variant: AppButtonVariant.destructive,
            icon: Icons.restore_rounded,
            onPressed: () => Navigator.of(context).pop(true),
          ),
          const SizedBox(height: 6),
          AppButton(
            label: 'ยกเลิก',
            variant: AppButtonVariant.secondary,
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: AppTypography.title.copyWith(fontSize: 14)),
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.icon, this.title, this.description);
  final IconData icon;
  final String title, description;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 18, color: AppColors.secondary),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTypography.title.copyWith(fontSize: 14)),
            const SizedBox(height: 2),
            Text(
              description,
              style: AppTypography.small.copyWith(fontSize: 13, height: 1.4),
            ),
          ],
        ),
      ),
    ],
  );
}

class _PrivacyLink extends StatelessWidget {
  const _PrivacyLink();
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: TextButton(
      // Keep the review sheet beneath the policy so users can return to it.
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              const LegalDocumentScreen(document: LegalDocument.privacy),
        ),
      ),
      child: const Text('อ่านนโยบายความเป็นส่วนตัว'),
    ),
  );
}
