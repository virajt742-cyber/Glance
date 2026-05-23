import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Copy generated assets from brain to project assets directory', () {
    final srcIconPath = 'C:/Users/Viraj/.gemini/antigravity-ide/brain/5686377f-9bb5-4761-a299-b2e36d57bdb9/app_icon_1779458966646.png';
    final srcSplashPath = 'C:/Users/Viraj/.gemini/antigravity-ide/brain/5686377f-9bb5-4761-a299-b2e36d57bdb9/splash_image_1779458986187.png';

    final destIconPath = 'c:/V/Glance/assets/images/app_icon.png';
    final destIconForegroundPath = 'c:/V/Glance/assets/images/app_icon_foreground.png';
    final destSplashPath = 'c:/V/Glance/assets/images/splash.png';

    // 1. Verify sources exist
    final srcIcon = File(srcIconPath);
    final srcSplash = File(srcSplashPath);

    if (!srcIcon.existsSync() || !srcSplash.existsSync()) {
      print('Skipping asset copy test: source assets do not exist (normal on CI/CD)');
      return;
    }

    // 2. Ensure destination folder exists
    final destDir = Directory('c:/V/Glance/assets/images');
    if (!destDir.existsSync()) {
      destDir.createSync(recursive: true);
    }

    // 3. Copy files
    srcIcon.copySync(destIconPath);
    srcIcon.copySync(destIconForegroundPath);
    srcSplash.copySync(destSplashPath);

    // 4. Verify copies exist and are not empty
    final destIcon = File(destIconPath);
    final destIconForeground = File(destIconForegroundPath);
    final destSplash = File(destSplashPath);

    expect(destIcon.existsSync(), isTrue, reason: 'Copied app icon should exist');
    expect(destIcon.lengthSync(), greaterThan(0), reason: 'Copied app icon should not be empty');

    expect(destIconForeground.existsSync(), isTrue, reason: 'Copied app icon foreground should exist');
    expect(destIconForeground.lengthSync(), greaterThan(0), reason: 'Copied app icon foreground should not be empty');

    expect(destSplash.existsSync(), isTrue, reason: 'Copied splash image should exist');
    expect(destSplash.lengthSync(), greaterThan(0), reason: 'Copied splash image should not be empty');

    print('SUCCESS: App icons and splash screen copied to assets/images/');
  });
}
