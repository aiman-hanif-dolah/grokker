import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/models/diff_file.dart';
import '../../data/services/diff_service.dart';

class DiffState extends Equatable {
  const DiffState({this.files = const [], this.selectedId});

  final List<DiffFile> files;
  final String? selectedId;

  DiffFile? get selected {
    if (selectedId == null) return null;
    try {
      return files.firstWhere((f) => f.id == selectedId);
    } catch (_) {
      return files.isNotEmpty ? files.first : null;
    }
  }

  DiffState copyWith({List<DiffFile>? files, String? selectedId}) {
    return DiffState(
      files: files ?? this.files,
      selectedId: selectedId ?? this.selectedId,
    );
  }

  @override
  List<Object?> get props => [files, selectedId];
}

class DiffCubit extends Cubit<DiffState> {
  DiffCubit(this._service) : super(const DiffState());

  final DiffService _service;

  void addDiff(DiffFile file) {
    emit(state.copyWith(files: [...state.files, file], selectedId: file.id));
  }

  void select(String id) => emit(state.copyWith(selectedId: id));

  void updateStatus(String id, DiffStatus status) {
    emit(
      state.copyWith(
        files: state.files.map((f) {
          if (f.id == id) return f.copyWith(status: status);
          return f;
        }).toList(),
      ),
    );
  }

  void clear() => emit(const DiffState());

  DiffService get service => _service;
}
