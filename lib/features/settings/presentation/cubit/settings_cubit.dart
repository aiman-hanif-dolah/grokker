import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../shared/models/app_settings.dart';
import '../../data/repositories/settings_repository.dart';

class SettingsState extends Equatable {
  const SettingsState({
    required this.settings,
    this.isLoading = false,
    this.saved = false,
  });

  final AppSettings settings;
  final bool isLoading;
  final bool saved;

  SettingsState copyWith({
    AppSettings? settings,
    bool? isLoading,
    bool? saved,
  }) {
    return SettingsState(
      settings: settings ?? this.settings,
      isLoading: isLoading ?? this.isLoading,
      saved: saved ?? this.saved,
    );
  }

  @override
  List<Object?> get props => [settings, isLoading, saved];
}

class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit(this._repository)
    : super(const SettingsState(settings: AppSettings()));

  final SettingsRepository _repository;

  Future<void> load() async {
    emit(state.copyWith(isLoading: true));
    final settings = await _repository.load();
    emit(SettingsState(settings: settings));
  }

  Future<void> update(AppSettings settings) async {
    await _repository.save(settings);
    emit(state.copyWith(settings: settings, saved: true));
  }

  Future<void> reset() async {
    await _repository.reset();
    emit(const SettingsState(settings: AppSettings(), saved: true));
  }
}
