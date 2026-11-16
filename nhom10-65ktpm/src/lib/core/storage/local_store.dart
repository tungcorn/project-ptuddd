import 'dart:async';
import 'dart:convert';

import 'package:hive_ce/hive_ce.dart';

/// Thin JSON document store on top of Hive CE.
///
/// Every value is stored as a JSON string inside a `Box<String>`, which keeps
/// the schema flexible (no generated adapters) and avoids Hive's dynamic map
/// casting pitfalls. Box names follow the project outline: `songs_cache`,
/// `words_{uid}`, `pending_ops`, ...
class LocalStore {
  LocalStore();

  final Map<String, Box<String>> _boxes = {};

  Future<Box<String>> _box(String name) async {
    final existing = _boxes[name];
    if (existing != null && existing.isOpen) return existing;
    final box = await Hive.openBox<String>(_safe(name));
    _boxes[name] = box;
    return box;
  }

  /// Hive box names must be lower case and file-system safe.
  static String _safe(String name) =>
      name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '_');

  Future<Map<String, dynamic>?> get(String box, String key) async {
    final raw = (await _box(box)).get(key);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<void> put(String box, String key, Map<String, dynamic> value) async {
    await (await _box(box)).put(key, jsonEncode(value));
  }

  Future<void> delete(String box, String key) async {
    await (await _box(box)).delete(key);
  }

  Future<List<Map<String, dynamic>>> values(String box) async {
    final b = await _box(box);
    return b.values
        .map((raw) => jsonDecode(raw) as Map<String, dynamic>)
        .toList();
  }

  Future<Map<String, Map<String, dynamic>>> entries(String box) async {
    final b = await _box(box);
    return {
      for (final key in b.keys)
        key.toString(): jsonDecode(b.get(key)!) as Map<String, dynamic>,
    };
  }

  Future<void> clear(String box) async {
    await (await _box(box)).clear();
  }

  /// Emits whenever [box] changes (used to refresh UI reactively).
  Stream<void> watch(String box) async* {
    final b = await _box(box);
    yield* b.watch().map((_) {});
  }

  Future<void> close() async {
    for (final b in _boxes.values) {
      if (b.isOpen) await b.close();
    }
    _boxes.clear();
  }
}
