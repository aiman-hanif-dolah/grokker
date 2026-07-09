import 'package:equatable/equatable.dart';

import 'approval_mode.dart';
import 'grok_model.dart';
import 'thinking_effort.dart';

enum AppThemeMode { dark, light, system }

enum ComposerEnterBehavior { newline, send }

class AppSettings extends Equatable {
  const AppSettings({
    this.grokCommandPath = '',
    this.useNpxGrok = false,
    this.defaultModel = GrokModel.grokBuild01,
    this.defaultEffort = ThinkingEffort.auto,
    this.approvalMode = ApprovalMode.autoApproveReads,
    this.themeMode = AppThemeMode.dark,
    this.composerEnterBehavior = ComposerEnterBehavior.send,
    this.autoStartGrokProcess = true,
    this.autoCreateSession = true,
    this.showRawAcpEvents = false,
    this.showStderrLogs = true,
    this.maxPersistedSessions = 100,
    this.attachmentWarningBytes = 5242880,
    this.inlineSmallTextAttachments = true,
    this.privacyMode = false,
    this.customModelLabels = const {},
    this.hiddenTools = const {},
  });

  final String grokCommandPath;
  final bool useNpxGrok;
  final GrokModel defaultModel;
  final ThinkingEffort defaultEffort;
  final ApprovalMode approvalMode;
  final AppThemeMode themeMode;
  final ComposerEnterBehavior composerEnterBehavior;
  final bool autoStartGrokProcess;
  final bool autoCreateSession;
  final bool showRawAcpEvents;
  final bool showStderrLogs;
  final int maxPersistedSessions;
  final int attachmentWarningBytes;
  final bool inlineSmallTextAttachments;
  final bool privacyMode;
  final Map<String, String> customModelLabels;
  final Set<String> hiddenTools;

  AppSettings copyWith({
    String? grokCommandPath,
    bool? useNpxGrok,
    GrokModel? defaultModel,
    ThinkingEffort? defaultEffort,
    ApprovalMode? approvalMode,
    AppThemeMode? themeMode,
    ComposerEnterBehavior? composerEnterBehavior,
    bool? autoStartGrokProcess,
    bool? autoCreateSession,
    bool? showRawAcpEvents,
    bool? showStderrLogs,
    int? maxPersistedSessions,
    int? attachmentWarningBytes,
    bool? inlineSmallTextAttachments,
    bool? privacyMode,
    Map<String, String>? customModelLabels,
    Set<String>? hiddenTools,
  }) {
    return AppSettings(
      grokCommandPath: grokCommandPath ?? this.grokCommandPath,
      useNpxGrok: useNpxGrok ?? this.useNpxGrok,
      defaultModel: defaultModel ?? this.defaultModel,
      defaultEffort: defaultEffort ?? this.defaultEffort,
      approvalMode: approvalMode ?? this.approvalMode,
      themeMode: themeMode ?? this.themeMode,
      composerEnterBehavior:
          composerEnterBehavior ?? this.composerEnterBehavior,
      autoStartGrokProcess: autoStartGrokProcess ?? this.autoStartGrokProcess,
      autoCreateSession: autoCreateSession ?? this.autoCreateSession,
      showRawAcpEvents: showRawAcpEvents ?? this.showRawAcpEvents,
      showStderrLogs: showStderrLogs ?? this.showStderrLogs,
      maxPersistedSessions: maxPersistedSessions ?? this.maxPersistedSessions,
      attachmentWarningBytes:
          attachmentWarningBytes ?? this.attachmentWarningBytes,
      inlineSmallTextAttachments:
          inlineSmallTextAttachments ?? this.inlineSmallTextAttachments,
      privacyMode: privacyMode ?? this.privacyMode,
      customModelLabels: customModelLabels ?? this.customModelLabels,
      hiddenTools: hiddenTools ?? this.hiddenTools,
    );
  }

  Map<String, dynamic> toJson() => {
    'grokCommandPath': grokCommandPath,
    'useNpxGrok': useNpxGrok,
    'defaultModel': defaultModel.name,
    'defaultEffort': defaultEffort.name,
    'approvalMode': approvalMode.name,
    'themeMode': themeMode.name,
    'composerEnterBehavior': composerEnterBehavior.name,
    'autoStartGrokProcess': autoStartGrokProcess,
    'autoCreateSession': autoCreateSession,
    'showRawAcpEvents': showRawAcpEvents,
    'showStderrLogs': showStderrLogs,
    'maxPersistedSessions': maxPersistedSessions,
    'attachmentWarningBytes': attachmentWarningBytes,
    'inlineSmallTextAttachments': inlineSmallTextAttachments,
    'privacyMode': privacyMode,
    'customModelLabels': customModelLabels,
    'hiddenTools': hiddenTools.toList(),
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      grokCommandPath: json['grokCommandPath'] as String? ?? '',
      useNpxGrok: json['useNpxGrok'] as bool? ?? false,
      defaultModel:
          GrokModelX.fromString(json['defaultModel'] as String?) ??
          GrokModel.grokBuild01,
      defaultEffort:
          ThinkingEffortX.fromString(json['defaultEffort'] as String?) ??
          ThinkingEffort.auto,
      approvalMode:
          ApprovalModeX.fromString(json['approvalMode'] as String?) ??
          ApprovalMode.autoApproveReads,
      themeMode: AppThemeMode.values.byName(
        json['themeMode'] as String? ?? 'dark',
      ),
      composerEnterBehavior: ComposerEnterBehavior.values.byName(
        json['composerEnterBehavior'] as String? ?? 'newline',
      ),
      autoStartGrokProcess: json['autoStartGrokProcess'] as bool? ?? true,
      autoCreateSession: json['autoCreateSession'] as bool? ?? true,
      showRawAcpEvents: json['showRawAcpEvents'] as bool? ?? false,
      showStderrLogs: json['showStderrLogs'] as bool? ?? true,
      maxPersistedSessions: json['maxPersistedSessions'] as int? ?? 100,
      attachmentWarningBytes: json['attachmentWarningBytes'] as int? ?? 5242880,
      inlineSmallTextAttachments:
          json['inlineSmallTextAttachments'] as bool? ?? true,
      privacyMode: json['privacyMode'] as bool? ?? false,
      customModelLabels:
          (json['customModelLabels'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, v as String),
          ) ??
          const {},
      hiddenTools:
          (json['hiddenTools'] as List<dynamic>?)?.cast<String>().toSet() ??
          const {},
    );
  }

  @override
  List<Object?> get props => [
    grokCommandPath,
    useNpxGrok,
    defaultModel,
    defaultEffort,
    approvalMode,
    themeMode,
    composerEnterBehavior,
    autoStartGrokProcess,
    autoCreateSession,
    showRawAcpEvents,
    showStderrLogs,
    maxPersistedSessions,
    attachmentWarningBytes,
    inlineSmallTextAttachments,
    privacyMode,
    customModelLabels,
    hiddenTools,
  ];
}
