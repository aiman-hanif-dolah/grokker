import 'package:equatable/equatable.dart';

enum ThinkingEffort { auto, low, medium, high, maximum }

extension ThinkingEffortX on ThinkingEffort {
  String get displayName {
    switch (this) {
      case ThinkingEffort.auto:
        return 'Auto';
      case ThinkingEffort.low:
        return 'Low';
      case ThinkingEffort.medium:
        return 'Medium';
      case ThinkingEffort.high:
        return 'High';
      case ThinkingEffort.maximum:
        return 'Maximum';
    }
  }

  String get cliValue => displayName.toLowerCase();

  static ThinkingEffort? fromString(String? value) {
    if (value == null) return null;
    for (final effort in ThinkingEffort.values) {
      if (effort.name == value || effort.displayName == value) {
        return effort;
      }
    }
    return null;
  }
}

class EffortSelectionState extends Equatable {
  const EffortSelectionState({
    required this.requested,
    this.confirmed,
    this.lastError,
  });

  final ThinkingEffort requested;
  final ThinkingEffort? confirmed;
  final String? lastError;

  @override
  List<Object?> get props => [requested, confirmed, lastError];
}
