import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:ngenbills/features/reminders/data/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  const codec = StandardMethodCodec();
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    test(
      'Notification payload reaches account navigation on $platform, cold and warm',
      () async {
        debugDefaultTargetPlatformOverride = platform;
        if (platform == TargetPlatform.android) {
          AndroidFlutterLocalNotificationsPlugin.registerWith();
        } else {
          IOSFlutterLocalNotificationsPlugin.registerWith();
        }
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        addTearDown(() {
          debugDefaultTargetPlatformOverride = null;
          messenger.setMockMethodCallHandler(channel, null);
        });
        messenger.setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'initialize') {
            return platform == TargetPlatform.android;
          }
          if (call.method == 'getNotificationAppLaunchDetails') {
            return {
              'notificationLaunchedApp': true,
              'notificationResponse': {
                'notificationId': 1,
                'notificationResponseType': 0,
                'payload': 'cold-account',
              },
            };
          }
          return null;
        });
        final opened = <String?>[];
        final service = LocalNotificationService(onTap: opened.add);
        await service.initialize();
        expect(opened, ['cold-account']);
        // Initialization is idempotent: returning from background must not reopen
        // the original launch account after the user has selected another one.
        await service.initialize();
        expect(opened, ['cold-account']);
        final completed = Completer<void>();
        // ignore: deprecated_member_use
        messenger.handlePlatformMessage(
          channel.name,
          codec.encodeMethodCall(
            const MethodCall('didReceiveNotificationResponse', {
              'notificationId': 2,
              'notificationResponseType': 0,
              'payload': 'warm-account',
            }),
          ),
          (_) => completed.complete(),
        );
        await completed.future;
        expect(opened, ['cold-account', 'warm-account']);
      },
    );
  }
}
