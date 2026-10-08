import 'package:flutter/material.dart';

class AppLoadingState extends StatelessWidget {
  const AppLoadingState({super.key});
  @override
  Widget build(BuildContext context) => Center(
    child: Semantics(
      label: 'กำลังโหลดข้อมูล',
      child: const CircularProgressIndicator(),
    ),
  );
}
