import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../domain/entities/account_appearance.dart';

abstract final class AccountVisuals {
  static const icons = <String, IconData>{
    'wallet': Icons.account_balance_wallet_outlined,
    'card': Icons.credit_card_outlined,
    'bank': Icons.account_balance_outlined,
    'car': Icons.directions_car_outlined,
    'home': Icons.home_outlined,
    'education': Icons.school_outlined,
    'phone': Icons.phone_android_outlined,
    'shopping': Icons.shopping_bag_outlined,
    'travel': Icons.flight_outlined,
    'heart': Icons.favorite_border,
  };
  static const iconLabels = [
    'กระเป๋า',
    'บัตร',
    'ธนาคาร',
    'รถ',
    'บ้าน',
    'การศึกษา',
    'โทรศัพท์',
    'ซื้อของ',
    'เดินทาง',
    'หัวใจ',
  ];
  static const colors = <String, Color>{
    'green': AppColors.primarySoft,
    'blue': Color(0xFFD9EEF5),
    'purple': Color(0xFFE6DEF5),
    'pink': Color(0xFFFADDE5),
    'orange': Color(0xFFFFE1D0),
    'yellow': Color(0xFFFFEDBC),
    'gray': Color(0xFFE4E5E7),
  };
  static const colorLabels = [
    'เขียว',
    'ฟ้า',
    'ม่วง',
    'ชมพู',
    'ส้ม',
    'เหลือง',
    'เทา',
  ];
  static String iconLabel(String key) =>
      iconLabels[AccountAppearance.iconKeys.indexOf(key)];
  static String colorLabel(String key) =>
      colorLabels[AccountAppearance.colorKeys.indexOf(key)];
}

class AccountAvatar extends StatelessWidget {
  const AccountAvatar({
    super.key,
    required this.iconKey,
    required this.colorKey,
    this.size = 43,
  });
  final String iconKey, colorKey;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: AccountVisuals.colors[colorKey] ?? AppColors.primarySoft,
      borderRadius: BorderRadius.circular(size * .28),
    ),
    child: Icon(
      AccountVisuals.icons[iconKey] ?? Icons.account_balance_wallet_outlined,
      size: size * .54,
      color: AppColors.primaryDark,
    ),
  );
}
