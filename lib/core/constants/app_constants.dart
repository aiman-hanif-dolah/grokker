class AppConstants {
  static const appName = 'Grokker';
  static const appVersion = '1.0.0';
  static const defaultGrokCommand = 'grok';
  static const defaultGrokArgs = ['agent', 'stdio'];
  static const npxGrokCommand = 'npx';
  static const npxGrokArgs = ['@xai-official/grok', 'agent', 'stdio'];
  static const acpProtocolVersion = 1;
  static const acpRequestTimeout = Duration(seconds: 30);
  static const maxRawEvents = 50;
  static const maxStderrLines = 50;
  static const maxPersistedSessionsDefault = 100;
  static const attachmentWarningBytesDefault = 5 * 1024 * 1024;
  static const inlineTextMaxBytes = 32 * 1024;
  static const minWindowWidth = 1100.0;
  static const minWindowHeight = 700.0;
  static const sidebarWidth = 260.0;
  static const inspectorWidth = 320.0;
}
