
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

/// ที่เก็บตัวไฟล์บนเว็บ (IndexedDB ผ่าน Hive) — iPad ที่ติดตั้งเป็นแอพบนหน้าจอโฮม
/// เก็บได้มากกว่า localStorage (จำกัด ~5 MB) หลายเท่า
class BlobStore {
  static LazyBox<Uint8List>? _box;
  static final Map<String, Uint8List> _cache = {};

  static Future<void> init() async {
    if (!kIsWeb) return;
    _box = await Hive.openLazyBox<Uint8List>('kru_plan_blobs');
  }

  static Future<void> put(String key, Uint8List bytes) async {
    _cache[key] = bytes;
    await _box?.put(key, bytes);
  }

  static Uint8List? peek(String key) => _cache[key];

  static Future<Uint8List?> get(String key) async {
    final c = _cache[key];
    if (c != null) return c;
    final v = await _box?.get(key);
    if (v != null) {
      if (_cache.length > 60) _cache.remove(_cache.keys.first);
      _cache[key] = v;
    }
    return v;
  }

  static Future<void> delete(String key) async {
    _cache.remove(key);
    await _box?.delete(key);
  }
}
