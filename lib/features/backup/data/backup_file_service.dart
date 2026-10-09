import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/app_exception.dart';
import 'backup_service.dart';

class PickedBackupFile {
  const PickedBackupFile({required this.name, required this.bytes});
  final String name;
  final Uint8List bytes;
}

/// Native dialogs own access to the selected destination, including content URIs.
class BackupFileService {
  Future<bool> save(Uint8List bytes) async {
    try {
      final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final result = await FilePicker.saveFile(
        fileName: 'ngenbills_$stamp.ngenbills',
        bytes: bytes,
        dialogTitle: 'บันทึกไฟล์สำรอง NgenBills',
      );
      return result != null;
    } catch (_) {
      throw const AppException(
        'บันทึกไฟล์สำรองไม่สำเร็จ กรุณาตรวจพื้นที่ว่างและลองอีกครั้ง',
      );
    }
  }

  Future<PickedBackupFile?> pick() async {
    try {
      // Unknown extensions can be hidden by iOS/Android providers. Show all
      // documents and verify the extension and content ourselves instead.
      final file = await FilePicker.pickFile(
        dialogTitle: 'เลือกไฟล์ .ngenbills เพื่อกู้คืน',
      );
      if (file == null) return null;
      if (file.extension?.toLowerCase() != 'ngenbills') {
        throw const AppException('กรุณาเลือกไฟล์สำรองนามสกุล .ngenbills');
      }
      final size = await file.length();
      if (size != null && size > BackupService.maxFileBytes) {
        throw const AppException('ไฟล์สำรองมีขนาดเกิน 32 MB ที่รองรับ');
      }
      final builder = BytesBuilder(copy: false);
      await for (final chunk in file.readAsByteStream()) {
        if (builder.length + chunk.length > BackupService.maxFileBytes) {
          throw const AppException('ไฟล์สำรองมีขนาดเกิน 32 MB ที่รองรับ');
        }
        builder.add(chunk);
      }
      return PickedBackupFile(name: file.name, bytes: builder.takeBytes());
    } on AppException {
      rethrow;
    } catch (_) {
      throw const AppException('อ่านไฟล์สำรองไม่สำเร็จ กรุณาเลือกไฟล์อีกครั้ง');
    }
  }
}
