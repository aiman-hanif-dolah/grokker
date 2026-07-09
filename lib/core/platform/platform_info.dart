import 'dart:io';

class PlatformInfo {
  static String get osName {
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isLinux) return 'Linux';
    return Platform.operatingSystem;
  }

  static bool get isDesktop =>
      Platform.isMacOS || Platform.isWindows || Platform.isLinux;

  static String get modifierKeyLabel => Platform.isMacOS ? 'Cmd' : 'Ctrl';
}
