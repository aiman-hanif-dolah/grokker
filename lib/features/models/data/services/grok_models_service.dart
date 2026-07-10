import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../../shared/models/grok_model.dart';

/// Loads available models from the local Grok Build CLI cache
/// (`~/.grok/models_cache.json`), optionally refreshed by running `grok models`.
class GrokModelsService {
  GrokModelsService({String? homeDirectory})
    : _home =
          homeDirectory ??
          Platform.environment['USERPROFILE'] ??
          Platform.environment['HOME'] ??
          '';

  final String _home;

  File get _cacheFile => File(p.join(_home, '.grok', 'models_cache.json'));

  /// Read cache (fast). Does not invoke the network.
  Future<GrokModelsSnapshot> loadFromCache() async {
    final file = _cacheFile;
    if (!await file.exists()) {
      return GrokModelsSnapshot.fallback();
    }
    try {
      final raw = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return _parseCache(raw);
    } catch (_) {
      return GrokModelsSnapshot.fallback();
    }
  }

  /// Best-effort: run `grok models` so the CLI refreshes the cache, then reload.
  Future<GrokModelsSnapshot> refresh({
    String? grokCommand,
    List<String> grokArgs = const [],
  }) async {
    try {
      final cmd = grokCommand ?? 'grok';
      await Process.run(cmd, [
        ...grokArgs,
        'models',
      ], runInShell: true).timeout(const Duration(seconds: 20));
    } catch (_) {
      // Fall through to cache even if refresh fails.
    }
    return loadFromCache();
  }

  GrokModelsSnapshot _parseCache(Map<String, dynamic> raw) {
    final modelsMap = raw['models'] as Map<String, dynamic>? ?? {};
    final models = <GrokModel>[];

    for (final entry in modelsMap.entries) {
      final body = entry.value;
      if (body is! Map<String, dynamic>) continue;
      final info = body['info'] as Map<String, dynamic>? ?? body;
      final id =
          (info['id'] as String?) ?? (info['model'] as String?) ?? entry.key;
      final name = (info['name'] as String?) ?? id;
      final hidden = info['hidden'] as bool? ?? false;
      final effortsRaw = info['reasoning_efforts'] as List<dynamic>?;
      final efforts =
          effortsRaw
              ?.map((e) {
                if (e is Map<String, dynamic>) {
                  return (e['value'] as String?) ?? (e['id'] as String?) ?? '';
                }
                return e.toString();
              })
              .where((e) => e.isNotEmpty)
              .toList() ??
          const <String>[];

      models.add(
        GrokModel(
          id: id,
          displayName: name,
          description: (info['description'] as String?) ?? '',
          hidden: hidden,
          supportsReasoningEffort:
              info['supports_reasoning_effort'] as bool? ?? efforts.isNotEmpty,
          reasoningEfforts: efforts,
          // Prefer frontier-style default when present.
          isDefault:
              id == 'grok-4.5' ||
              id == 'grok-4' ||
              (info['is_default'] as bool? ?? false),
        ),
      );
    }

    if (models.isEmpty) return GrokModelsSnapshot.fallback();

    // Ensure exactly one default: prefer marked, else first visible.
    final visible = models.where((m) => !m.hidden).toList();
    String? defaultId;
    final marked = visible.where((m) => m.isDefault);
    if (marked.isNotEmpty) {
      defaultId = marked.first.id;
    } else if (visible.isNotEmpty) {
      defaultId = visible.first.id;
    }

    final normalized = models
        .map((m) => m.copyWith(isDefault: m.id == defaultId))
        .toList();

    DateTime? fetchedAt;
    final fetchedRaw = raw['fetched_at'] as String?;
    if (fetchedRaw != null) {
      fetchedAt = DateTime.tryParse(fetchedRaw);
    }

    return GrokModelsSnapshot(
      models: normalized,
      defaultModelId: defaultId ?? normalized.first.id,
      fetchedAt: fetchedAt,
      source: 'cache',
    );
  }
}

class GrokModelsSnapshot {
  const GrokModelsSnapshot({
    required this.models,
    required this.defaultModelId,
    this.fetchedAt,
    this.source = 'fallback',
  });

  final List<GrokModel> models;
  final String defaultModelId;
  final DateTime? fetchedAt;
  final String source;

  GrokModel get defaultModel =>
      models.cast<GrokModel?>().firstWhere(
        (m) => m!.id == defaultModelId,
        orElse: () => models.isNotEmpty ? models.first : null,
      ) ??
      GrokModel.grok45;

  List<GrokModel> get visible =>
      models.where((m) => !m.hidden).toList(growable: false);

  factory GrokModelsSnapshot.fallback() {
    return const GrokModelsSnapshot(
      models: [GrokModel.grok45, GrokModel.composer25Fast],
      defaultModelId: 'grok-4.5',
      source: 'fallback',
    );
  }
}
