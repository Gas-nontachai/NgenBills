import 'package:flutter_test/flutter_test.dart';
import 'package:ngenbills/features/settings/presentation/app_version_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  final info = PackageInfo(
    appName: 'NgenBills',
    packageName: 'com.gasnontachai.ngenbills',
    version: '2.3.4',
    buildNumber: '42',
  );

  test('Production hides the build number', () {
    expect(formatAppVersion(info, release: true), '2.3.4');
  });

  test('Development includes the build number', () {
    expect(formatAppVersion(info, release: false), '2.3.4 (build 42)');
  });
}
