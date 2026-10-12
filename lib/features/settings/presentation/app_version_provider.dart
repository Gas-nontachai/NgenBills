import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

final appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return formatAppVersion(info);
});

String formatAppVersion(PackageInfo info, {bool release = kReleaseMode}) {
  if (release || info.buildNumber.isEmpty) return info.version;
  return '${info.version} (build ${info.buildNumber})';
}
