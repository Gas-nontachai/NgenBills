import '../entities/debt_direction.dart';

export '../entities/debt_direction.dart';

/// Copy belongs to the account, independent of the currently selected account.
class DebtWording {
  const DebtWording(this.direction);
  final DebtDirection direction;
  String _pick(String payable, String receivable) =>
      direction == DebtDirection.receivable ? receivable : payable;
  String get paid => _pick('จ่ายแล้ว', 'รับคืนแล้ว');
  String get remaining => _pick('คงเหลือ', 'รอรับคืน');
  String get progress => _pick('ชำระแล้ว', 'รับคืนแล้ว');
  String get complete => _pick('ชำระครบแล้ว', 'ได้รับเงินคืนครบแล้ว');
  String get completeCelebration =>
      _pick('ชำระครบแล้ว! 🎉', 'ได้รับเงินคืนครบแล้ว! 🎉');
  String get savePayment => _pick('บันทึกการจ่าย', 'บันทึกการรับคืน');
  String get paymentDate => _pick('วันที่จ่าย', 'วันที่รับคืน');
  String get pickPaymentDate => _pick('เลือกวันที่จ่าย', 'เลือกวันที่รับคืน');
  String get borrowing => _pick('กู้เพิ่ม', 'ให้ยืมเพิ่ม');
  String get paymentHistory => _pick('ชำระหนี้', 'รับเงินคืน');
  String get dueDate => _pick('วันครบกำหนดชำระ', 'วันครบกำหนดรับคืน');
  String get paymentSaved => _pick(
    'บันทึกการจ่ายแล้ว อีกก้าวที่ใกล้เป้าหมาย 🌱',
    'บันทึกการรับคืนแล้ว 🌱',
  );
  String get borrowingSaved =>
      _pick('บันทึกการกู้เพิ่มแล้ว', 'บันทึกการให้ยืมเพิ่มแล้ว');
  String get congratTitle => _pick('เก่งมากเลย! 🌱', 'ได้รับเงินคืนครบแล้ว 🌱');
  String get congratBody => _pick(
    'คุณก้าวมาถึงเป้าหมายแล้ว\nขอบคุณที่ดูแลตัวเองนะ',
    'บัญชีนี้ได้รับเงินคืนครบแล้ว ขอบคุณที่ติดตามอย่างสม่ำเสมอนะ',
  );
  String get initialAmount =>
      _pick('ยอดหนี้ตั้งต้น (บาท)', 'ยอดให้ยืมตั้งต้น (บาท)');
  String get initialSummary => _pick('จากยอดเริ่มต้น', 'จากยอดให้ยืมตั้งต้น');
  String get fromTotal => _pick('จากยอดหนี้รวม', 'จากยอดให้ยืมรวม');
  String get outstanding => _pick('ยอดหนี้คงเหลือ', 'ยอดรอรับคืน');
  String get total => _pick('ยอดหนี้รวม', 'ยอดให้ยืมรวม');
  String get paymentHelp => _pick(
    'ทุกยอดที่จ่าย คืออีกก้าวที่ใกล้เป้าหมาย',
    'ติดตามเงินที่ได้รับคืน ทีละรายการ',
  );
  String get remainingAmount => _pick('ยอดคงเหลือ', 'ยอดรอรับคืน');
  String get paymentHint =>
      _pick('เช่น จ่ายผ่านแอปธนาคาร', 'เช่น รับคืนผ่านแอปธนาคาร');
  String get paymentDetail => _pick('รายละเอียดการจ่าย', 'รายละเอียดการรับคืน');
  String get deletePayment => _pick('ลบรายการจ่าย', 'ลบรายการรับคืน');
  String get deletePaymentSaved => _pick(
    'ลบรายการจ่ายแล้ว ยอดคงเหลืออัปเดตแล้ว',
    'ลบรายการรับคืนแล้ว ยอดรอรับคืนอัปเดตแล้ว',
  );
  String get paymentAmount => _pick('จำนวนเงินที่จ่าย', 'จำนวนเงินที่รับคืน');
  String get paymentAmountBaht =>
      _pick('จำนวนเงินที่จ่าย (บาท)', 'จำนวนเงินที่รับคืน (บาท)');
  String get paymentMenu => _pick('เมนูรายการจ่าย', 'เมนูรายการรับคืน');
  String get borrowingDetail =>
      _pick('รายละเอียดการกู้เพิ่ม', 'รายละเอียดการให้ยืมเพิ่ม');
  String get deleteBorrowing =>
      _pick('ลบรายการกู้เพิ่ม', 'ลบรายการให้ยืมเพิ่ม');
  String get deleteBorrowingSaved => _pick(
    'ลบรายการกู้เพิ่มแล้ว ยอดคงเหลืออัปเดตแล้ว',
    'ลบรายการให้ยืมเพิ่มแล้ว ยอดรอรับคืนอัปเดตแล้ว',
  );
  String get borrowingDeleteExplanation => _pick(
    'ยอดหนี้รวมและยอดคงเหลือจะลดลง\nลบได้เมื่อยอดหนี้รวมยังไม่น้อยกว่ายอดที่จ่ายแล้ว',
    'ยอดให้ยืมรวมและยอดรอรับคืนจะลดลง\nลบได้เมื่อยอดให้ยืมรวมยังไม่น้อยกว่ายอดที่รับคืนแล้ว',
  );
  String get currentOutstanding =>
      _pick('ยอดหนี้คงเหลือปัจจุบัน', 'ยอดรอรับคืนปัจจุบัน');
  String get borrowingAmount =>
      _pick('จำนวนเงินที่กู้เพิ่ม (บาท)', 'จำนวนเงินที่ให้ยืมเพิ่ม (บาท)');
  String get borrowingDate => _pick('วันที่กู้เพิ่ม', 'วันที่ให้ยืมเพิ่ม');
  String get pickBorrowingDate =>
      _pick('เลือกวันที่กู้เพิ่ม', 'เลือกวันที่ให้ยืมเพิ่ม');
  String get borrowingHint =>
      _pick('เช่น กู้เพิ่มเพื่อซ่อมรถ', 'เช่น ให้ยืมเพิ่มเพื่อซ่อมรถ');
  String get saveBorrowing =>
      _pick('บันทึกการกู้เพิ่ม', 'บันทึกการให้ยืมเพิ่ม');
  String get newOutstanding => _pick('ยอดหนี้คงเหลือใหม่', 'ยอดรอรับคืนใหม่');
  String get borrowingHistoryNotice => _pick(
    'รายการนี้ถูกบันทึกในประวัติรายการในฐานะ “กู้เพิ่ม”',
    'รายการนี้ถูกบันทึกในประวัติรายการในฐานะ “ให้ยืมเพิ่ม”',
  );
  String get editPayment => _pick('แก้ไขรายการจ่าย', 'แก้ไขรายการรับคืน');
  String get editBorrowing =>
      _pick('แก้ไขรายการกู้เพิ่ม', 'แก้ไขรายการให้ยืมเพิ่ม');
  String get editSaved => _pick(
    'บันทึกการแก้ไขแล้ว ยอดคงเหลืออัปเดตแล้ว',
    'บันทึกการแก้ไขแล้ว ยอดรอรับคืนอัปเดตแล้ว',
  );
  String get overflow =>
      _pick('ยอดหนี้รวมเกินวงเงินที่รองรับ', 'ยอดให้ยืมรวมเกินวงเงินที่รองรับ');
  String get belowPaid => _pick(
    'ยอดหนี้รวมต้องไม่น้อยกว่ายอดที่จ่ายแล้ว',
    'ยอดให้ยืมรวมต้องไม่น้อยกว่ายอดที่รับคืนแล้ว',
  );
  String get cannotEditBorrowing => _pick(
    'แก้ไขไม่ได้ เพราะยอดหนี้รวมจะน้อยกว่ายอดที่จ่ายแล้ว',
    'แก้ไขไม่ได้ เพราะยอดให้ยืมรวมจะน้อยกว่ายอดที่รับคืนแล้ว',
  );
  String get cannotDeleteBorrowing => _pick(
    'ลบรายการนี้ไม่ได้ เพราะยอดหนี้รวมจะน้อยกว่ายอดที่จ่ายแล้ว',
    'ลบรายการนี้ไม่ได้ เพราะยอดให้ยืมรวมจะน้อยกว่ายอดที่รับคืนแล้ว',
  );
  String get accountDeleteAmounts =>
      _pick('ยอดหนี้และยอดคงเหลือ', 'ยอดให้ยืมและยอดรอรับคืน');
  String get accountDeletePayments =>
      _pick('ประวัติการจ่ายทั้งหมด', 'ประวัติการรับคืนทั้งหมด');
  String get accountDeleteBorrowings =>
      _pick('ประวัติการกู้เพิ่มทั้งหมด', 'ประวัติการให้ยืมเพิ่มทั้งหมด');
  String get footer =>
      _pick('ค่อย ๆ จ่าย ค่อย ๆ ไป 🌱', 'ค่อย ๆ ติดตามเงินคืนไปด้วยกัน 🌱');
  String get createFooter => _pick(
    'ค่อย ๆ จ่าย ค่อย ๆ ไป ถึงเป้าหมายได้เหมือนกัน',
    'ค่อย ๆ ติดตามเงินคืนไปด้วยกัน 🌱',
  );
  String get createHint => _pick('เช่น บัตรเครดิต', 'เช่น ให้ยืมเพื่อน');
  String get createHelp => _pick(
    'แค่รู้ว่าเรามีหนี้เท่าไหร่\nก็เป็นจุดเริ่มต้นที่ดีแล้ว',
    'เริ่มติดตามว่าให้ยืมไปเท่าไหร่\nและได้รับเงินคืนแล้วเท่าไหร่',
  );
  String get createSaved => _pick(
    'เริ่มต้นได้ดีแล้ว มาค่อย ๆ ไปด้วยกัน 🌱',
    'เริ่มติดตามเงินให้ยืมแล้ว มาค่อย ๆ ไปด้วยกัน 🌱',
  );
  String get createFirstTitle =>
      _pick('เพิ่มหนี้ก้อนแรก', 'เพิ่มบัญชีให้ยืมแรก');
  String get createFirstSave =>
      _pick('สร้างหนี้ก้อนแรก', 'สร้างบัญชีให้ยืมแรก');
  String get accountName => _pick('ชื่อหนี้', 'ชื่อบัญชีให้ยืม');
  String get emptyHistory => _pick(
    'บันทึกการจ่ายหรือกู้เพิ่ม\nเพื่อเริ่มติดตามบัญชีของคุณ',
    'บันทึกการรับคืนหรือให้ยืมเพิ่ม\nเพื่อเริ่มติดตามบัญชีของคุณ',
  );
  String get borrowingMenuHelp =>
      _pick('เพิ่มยอดหนี้และบันทึกประวัติ', 'เพิ่มยอดให้ยืมและบันทึกประวัติ');
  String get reminderMenuHelp =>
      _pick('จัดการเตือนวันชำระ', 'จัดการเตือนวันรับเงินคืน');
  String get reminderComplete => _pick(
    'ชำระครบแล้ว · หยุดแจ้งเตือน',
    'ได้รับเงินคืนครบแล้ว · หยุดแจ้งเตือน',
  );
  String get reminderChoose =>
      _pick('เลือกวันชำระและเวลาเตือน', 'เลือกวันรับเงินคืนและเวลาเตือน');
  String get reminderDay => _pick('วันชำระ', 'วันรับเงินคืน');
  String get dueDateLabel => _pick('วันครบกำหนดชำระ:', 'วันครบกำหนดรับคืน:');
  String get onboardingHelp => _pick(
    'ไม่ต้องจำวันจ่ายหนี้ด้วยตัวเอง\nเราจะคอยเตือนคุณเมื่อใกล้ถึงวันครบกำหนด',
    'ไม่ต้องจำวันรับเงินคืนด้วยตัวเอง\nเราจะคอยเตือนคุณเมื่อใกล้ถึงวันครบกำหนด',
  );
  String get onboardingBenefit =>
      _pick('ไม่พลาดวันจ่ายหนี้', 'ไม่พลาดวันรับเงินคืน');
  String get onboardingSuccess => _pick(
    'คุณเริ่มต้นจัดการหนี้ก้อนแรกแล้ว\nก้าวแรกสำเร็จแล้ว มาค่อย ๆ ไปด้วยกันนะ 🌱',
    'คุณเริ่มต้นติดตามเงินให้ยืมบัญชีแรกแล้ว\nมาค่อย ๆ ติดตามเงินคืนไปด้วยกันนะ 🌱',
  );
  String get createTitle => _pick('เพิ่มบัญชีหนี้', 'เพิ่มบัญชีให้ยืม');
  String get createSave => _pick('สร้างบัญชีหนี้', 'สร้างบัญชีให้ยืม');
  String get nameRequired =>
      _pick('กรุณากรอกชื่อหนี้', 'กรุณากรอกชื่อบัญชีให้ยืม');
  String get nameTooLong => _pick(
    'ชื่อหนี้ต้องไม่เกิน 100 ตัวอักษร',
    'ชื่อบัญชีให้ยืมต้องไม่เกิน 100 ตัวอักษร',
  );
  String get nameInvalid => _pick(
    'ชื่อหนี้ต้องมี 1–100 ตัวอักษร',
    'ชื่อบัญชีให้ยืมต้องมี 1–100 ตัวอักษร',
  );
  String get amountInvalid => _pick('ยอดหนี้ไม่ถูกต้อง', 'ยอดให้ยืมไม่ถูกต้อง');
  String get accountMenu => _pick('เมนูหนี้', 'เมนูบัญชีให้ยืม');
  String progressPercent(String percent) => '$progress $percent%';
  String progressSemantics(int percent) => '$progress $percent เปอร์เซ็นต์';
  String deletePaymentExplanation(String amount) => _pick(
    'ยอดคงเหลือจะเพิ่มขึ้น $amount เมื่อเอารายการนี้ออกจากยอดที่จ่ายแล้ว',
    'ยอดรอรับคืนจะเพิ่มขึ้น $amount เมื่อเอารายการนี้ออกจากยอดที่รับคืนแล้ว',
  );
  String overRemaining(String amount) => _pick(
    'จำนวนเงินเกินยอดคงเหลือ $amount',
    'จำนวนเงินเกินยอดรอรับคืน $amount',
  );
  String reminderHeading(int days) => days == 0
      ? _pick('วันนี้ถึงวันชำระ', 'วันนี้ถึงวันรับเงินคืน')
      : _pick('อีก $days วันถึงวันชำระ', 'อีก $days วันถึงวันรับเงินคืน');
}
