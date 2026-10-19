import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

const shareMessage =
    'MoneyKit: free offline calculators for MAB, interest, mortgage and CPF interest.';

class AppInfo {
  const AppInfo({this.versionName, this.apkPath});

  final String? versionName;

  /// Path of the installed APK, when the platform can tell us.
  final String? apkPath;
}

const _channel = MethodChannel('moneykit/app');

typedef AppInfoLoader = Future<AppInfo> Function();
typedef AppSharer = Future<void> Function();

Future<AppInfo> loadAppInfo() async {
  try {
    final m = await _channel.invokeMapMethod<String, String>('info');
    return AppInfo(versionName: m?['versionName'], apkPath: m?['apkPath']);
  } catch (_) {
    return const AppInfo();
  }
}

/// Shares the installed APK (so a friend can sideload it) with a short message;
/// falls back to text only if the APK cannot be copied.
Future<void> shareApp() async {
  final info = await loadAppInfo();
  XFile? apk;
  try {
    final src = info.apkPath;
    if (src != null) {
      final dir = await getTemporaryDirectory();
      final copy = await XFile(src)
          .saveTo('${dir.path}/MoneyKit.apk')
          .then(
            (_) => XFile(
              '${dir.path}/MoneyKit.apk',
              mimeType: 'application/vnd.android.package-archive',
            ),
          );
      apk = copy;
    }
  } catch (_) {}
  await Share.shareXFiles([?apk], text: shareMessage, subject: 'MoneyKit');
}
