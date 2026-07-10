import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/models/grok_model.dart';
import '../../data/services/grok_models_service.dart';

class ModelsState extends Equatable {
  const ModelsState({
    this.models = const [GrokModel.grok45, GrokModel.composer25Fast],
    this.defaultModel = GrokModel.grok45,
    this.isLoading = false,
    this.source = 'fallback',
    this.fetchedAt,
    this.error,
  });

  final List<GrokModel> models;
  final GrokModel defaultModel;
  final bool isLoading;
  final String source;
  final DateTime? fetchedAt;
  final String? error;

  ModelsState copyWith({
    List<GrokModel>? models,
    GrokModel? defaultModel,
    bool? isLoading,
    String? source,
    DateTime? fetchedAt,
    String? error,
    bool clearError = false,
  }) {
    return ModelsState(
      models: models ?? this.models,
      defaultModel: defaultModel ?? this.defaultModel,
      isLoading: isLoading ?? this.isLoading,
      source: source ?? this.source,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [
    models,
    defaultModel,
    isLoading,
    source,
    fetchedAt,
    error,
  ];
}

class ModelsCubit extends Cubit<ModelsState> {
  ModelsCubit(this._service) : super(const ModelsState());

  final GrokModelsService _service;

  Future<void> load({bool refreshCli = false, String? grokCommand}) async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final snapshot = refreshCli
          ? await _service.refresh(grokCommand: grokCommand)
          : await _service.loadFromCache();

      GrokModelCatalog.instance.replace(
        snapshot.models,
        defaultId: snapshot.defaultModelId,
      );

      emit(
        ModelsState(
          models: snapshot.visible,
          defaultModel: snapshot.defaultModel,
          source: snapshot.source,
          fetchedAt: snapshot.fetchedAt,
        ),
      );
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }
}
