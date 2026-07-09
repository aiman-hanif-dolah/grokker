enum ApprovalMode {
  askEveryTime,
  autoApproveReads,
  autoApproveReadsAndWrites,
  fullTrust,
}

extension ApprovalModeX on ApprovalMode {
  String get displayName {
    switch (this) {
      case ApprovalMode.askEveryTime:
        return 'Ask every time';
      case ApprovalMode.autoApproveReads:
        return 'Auto-approve safe reads only';
      case ApprovalMode.autoApproveReadsAndWrites:
        return 'Auto-approve reads and writes';
      case ApprovalMode.fullTrust:
        return 'Full trust mode';
    }
  }

  String get description {
    switch (this) {
      case ApprovalMode.askEveryTime:
        return 'Grokker asks before file writes and external reads.';
      case ApprovalMode.autoApproveReads:
        return 'Reads inside the workspace are auto-approved.';
      case ApprovalMode.autoApproveReadsAndWrites:
        return 'Reads and writes inside the workspace are auto-approved.';
      case ApprovalMode.fullTrust:
        return 'Grok can modify local files without approval. Use with caution.';
    }
  }

  static ApprovalMode? fromString(String? value) {
    if (value == null) return null;
    for (final mode in ApprovalMode.values) {
      if (mode.name == value) return mode;
    }
    return null;
  }
}
