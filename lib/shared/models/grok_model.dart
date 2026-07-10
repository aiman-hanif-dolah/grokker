import 'package:equatable/equatable.dart';

/// A Grok model exposed by the local Grok Build CLI / models cache.
///
/// Not a fixed enum — the catalog is refreshed from
/// `~/.grok/models_cache.json` so the UI always lists what the CLI offers.
class GrokModel extends Equatable {
  const GrokModel({
    required this.id,
    required this.displayName,
    this.description = '',
    this.isDefault = false,
    this.hidden = false,
    this.supportsReasoningEffort = true,
    this.reasoningEfforts = const [],
  });

  /// CLI / API id, e.g. `grok-4.5`, `grok-composer-2.5-fast`.
  final String id;

  /// Human label, e.g. `Grok 4.5`.
  final String displayName;

  final String description;
  final bool isDefault;
  final bool hidden;
  final bool supportsReasoningEffort;
  final List<String> reasoningEfforts;

  /// Alias used by older settings keys (`customModelLabels`).
  String get name => id;

  /// Value passed to `/model …` slash control.
  String get cliLabel => id;

  GrokModel copyWith({
    String? displayName,
    String? description,
    bool? isDefault,
    bool? hidden,
  }) {
    return GrokModel(
      id: id,
      displayName: displayName ?? this.displayName,
      description: description ?? this.description,
      isDefault: isDefault ?? this.isDefault,
      hidden: hidden ?? this.hidden,
      supportsReasoningEffort: supportsReasoningEffort,
      reasoningEfforts: reasoningEfforts,
    );
  }

  /// Built-in fallback when the CLI cache is missing (latest known).
  static const GrokModel grok45 = GrokModel(
    id: 'grok-4.5',
    displayName: 'Grok 4.5',
    description: "SpaceXAI's frontier model",
    isDefault: true,
  );

  static const GrokModel composer25Fast = GrokModel(
    id: 'grok-composer-2.5-fast',
    displayName: 'Composer 2.5',
    description: "Cursor's coding model",
  );

  /// Prefer [GrokModelCatalog.defaultModel] at runtime.
  static const GrokModel defaultModel = grok45;

  /// Legacy enum-name / display-name aliases → current ids.
  static const Map<String, String> _legacyAliases = {
    'grokBuild01': 'grok-4.5',
    'grok43': 'grok-4.5',
    'composer25Fast': 'grok-composer-2.5-fast',
    'Grok Build 0.1': 'grok-4.5',
    'Grok Build': 'grok-4.5',
    'Grok 4.3': 'grok-4.5',
    'Composer 2.5 Fast': 'grok-composer-2.5-fast',
    'Composer 2.5': 'grok-composer-2.5-fast',
  };

  static GrokModel? fromString(String? value) {
    if (value == null || value.isEmpty) return null;
    final mapped = _legacyAliases[value] ?? value;
    // Defer to catalog if loaded; otherwise synthesize from id.
    final fromCatalog = GrokModelCatalog.instance.find(mapped);
    if (fromCatalog != null) return fromCatalog;
    // Known fallbacks
    if (mapped == grok45.id) return grok45;
    if (mapped == composer25Fast.id) return composer25Fast;
    // Unknown id still usable (CLI may accept it)
    return GrokModel(id: mapped, displayName: mapped);
  }

  @override
  List<Object?> get props => [id];

  @override
  String toString() => 'GrokModel($id)';
}

/// In-memory catalog of models from the Grok CLI cache.
class GrokModelCatalog {
  GrokModelCatalog._();
  static final GrokModelCatalog instance = GrokModelCatalog._();

  List<GrokModel> _models = const [GrokModel.grok45, GrokModel.composer25Fast];
  String? _defaultId = GrokModel.grok45.id;
  DateTime? fetchedAt;

  List<GrokModel> get models =>
      _models.where((m) => !m.hidden).toList(growable: false);

  /// All known models including hidden (for lookups).
  List<GrokModel> get allModels => List.unmodifiable(_models);

  GrokModel get defaultModel {
    if (_defaultId != null) {
      final match = find(_defaultId);
      if (match != null) return match;
    }
    final marked = _models.where((m) => m.isDefault && !m.hidden);
    if (marked.isNotEmpty) return marked.first;
    if (models.isNotEmpty) return models.first;
    return GrokModel.grok45;
  }

  GrokModel? find(String? idOrName) {
    if (idOrName == null || idOrName.isEmpty) return null;
    final mapped = GrokModel._legacyAliases[idOrName] ?? idOrName;
    for (final m in _models) {
      if (m.id == mapped || m.displayName == idOrName || m.id == idOrName) {
        return m;
      }
    }
    return null;
  }

  void replace(List<GrokModel> models, {String? defaultId}) {
    if (models.isEmpty) return;
    _models = List.unmodifiable(models);
    _defaultId =
        defaultId ??
        models
            .cast<GrokModel?>()
            .firstWhere((m) => m!.isDefault, orElse: () => null)
            ?.id ??
        models.first.id;
  }
}

/// Back-compat: older code calls [GrokModelX.fromString].
extension GrokModelX on GrokModel {
  static GrokModel? fromString(String? value) => GrokModel.fromString(value);
}
