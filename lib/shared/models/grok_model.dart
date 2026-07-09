import 'package:equatable/equatable.dart';

enum GrokModel { grokBuild01, grok43, composer25Fast }

extension GrokModelX on GrokModel {
  String get displayName {
    switch (this) {
      case GrokModel.grokBuild01:
        return 'Grok Build 0.1';
      case GrokModel.grok43:
        return 'Grok 4.3';
      case GrokModel.composer25Fast:
        return 'Composer 2.5 Fast';
    }
  }

  String get cliLabel {
    switch (this) {
      case GrokModel.grokBuild01:
        return 'Grok Build';
      case GrokModel.grok43:
        return 'Grok 4.3';
      case GrokModel.composer25Fast:
        return 'Composer 2.5';
    }
  }

  static GrokModel? fromString(String? value) {
    if (value == null) return null;
    for (final model in GrokModel.values) {
      if (model.name == value || model.displayName == value) {
        return model;
      }
    }
    return null;
  }
}

class ModelSelectionState extends Equatable {
  const ModelSelectionState({
    required this.requested,
    this.confirmed,
    this.lastError,
  });

  final GrokModel requested;
  final GrokModel? confirmed;
  final String? lastError;

  ModelSelectionState copyWith({
    GrokModel? requested,
    GrokModel? confirmed,
    String? lastError,
  }) {
    return ModelSelectionState(
      requested: requested ?? this.requested,
      confirmed: confirmed ?? this.confirmed,
      lastError: lastError,
    );
  }

  @override
  List<Object?> get props => [requested, confirmed, lastError];
}
