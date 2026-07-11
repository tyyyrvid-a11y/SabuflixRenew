import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/media_item.dart';

class ContinueWatchingEntry {
  const ContinueWatchingEntry(this.item, this.positionInSeconds, this.durationInSeconds, this.timestamp);
  
  final MediaItem item;
  final int positionInSeconds;
  final int durationInSeconds;
  final int timestamp; // epoch ms

  double get progress => durationInSeconds > 0 ? (positionInSeconds / durationInSeconds).clamp(0.0, 1.0) : 0.0;

  Map<String, dynamic> toJson() {
    return {
      'item': item.toJson(),
      'positionInSeconds': positionInSeconds,
      'durationInSeconds': durationInSeconds,
      'timestamp': timestamp,
    };
  }

  factory ContinueWatchingEntry.fromJson(Map<String, dynamic> json) {
    return ContinueWatchingEntry(
      MediaItem.fromJson(json['item'] as Map<String, dynamic>),
      json['positionInSeconds'] as int? ?? 0,
      json['durationInSeconds'] as int? ?? 0,
      json['timestamp'] as int? ?? 0,
    );
  }
}

/// Tracks which titles have actually been opened in the player, persisted
/// locally, so the "Assistidos" stat reflects real usage instead of a
/// fixed mock number. Also stores playback position for "Continue Watching".
class WatchHistoryStore extends ChangeNotifier {
  WatchHistoryStore._();

  static final WatchHistoryStore instance = WatchHistoryStore._();

  final Map<String, ContinueWatchingEntry> _entries = {};
  bool _loaded = false;

  int get count => _entries.length;

  List<ContinueWatchingEntry> get sortedEntries {
    final list = _entries.values.toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return list;
  }

  String _key(MediaItem item) => '${item.mediaType.name}:${item.id}';

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    final prefs = await SharedPreferences.getInstance();
    
    final historyJsonList = prefs.getStringList('watch_history_entries') ?? [];
    for (final jsonStr in historyJsonList) {
      try {
        final entry = ContinueWatchingEntry.fromJson(json.decode(jsonStr) as Map<String, dynamic>);
        _entries[_key(entry.item)] = entry;
      } catch (e) {
        // Ignora itens inválidos
      }
    }
    
    // Migração de chaves antigas se necessário (watch_history_keys)
    final oldKeys = prefs.getStringList('watch_history_keys');
    if (oldKeys != null && oldKeys.isNotEmpty) {
      prefs.remove('watch_history_keys'); // Não usaremos mais
    }
    
    notifyListeners();
  }

  Future<void> markWatched(MediaItem item, {int positionInSeconds = 0, int durationInSeconds = 0}) async {
    final k = _key(item);
    
    _entries[k] = ContinueWatchingEntry(
      item, 
      positionInSeconds, 
      durationInSeconds, 
      DateTime.now().millisecondsSinceEpoch
    );
    
    notifyListeners();
    
    final prefs = await SharedPreferences.getInstance();
    final jsonList = _entries.values.map((e) => json.encode(e.toJson())).toList();
    await prefs.setStringList('watch_history_entries', jsonList);
  }

  int? getSavedPosition(MediaItem item) {
    final entry = _entries[_key(item)];
    return entry?.positionInSeconds;
  }
}
