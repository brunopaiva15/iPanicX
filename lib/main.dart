import 'dart:io';

import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/app_controller.dart';
import 'diagnostics/knowledge_base.dart';
import 'diagnostics/knowledge_base_loader.dart';
import 'services/iphone_service.dart';
import 'services/libimobiledevice_service.dart';
import 'services/platform_bridge.dart';
import 'services/mock_iphone_service.dart';

/// `flutter run -d macos|windows --dart-define=USE_MOCK_DEVICE=true`
/// (the `USE_MOCK_DEVICE=true` environment variable works too).
bool get useMockDevice =>
    const bool.fromEnvironment('USE_MOCK_DEVICE') ||
    Platform.environment['USE_MOCK_DEVICE']?.toLowerCase() == 'true';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  KnowledgeBase knowledgeBase;
  try {
    knowledgeBase = await loadKnowledgeBaseFromAssets();
  } catch (e) {
    debugPrint('Knowledge base could not be loaded: $e');
    knowledgeBase = KnowledgeBase.empty;
  }

  final bridge = PlatformBridge.forHost();
  final IPhoneService iphone = useMockDevice
      ? MockIPhoneService()
      : LibimobiledeviceService(usbEvents: bridge.usbDeviceEvents);

  final controller = AppController(
    iphone: iphone,
    knowledgeBase: knowledgeBase,
    bridge: bridge,
  );
  runApp(IPanicXApp(controller: controller));
  await controller.start();
}
