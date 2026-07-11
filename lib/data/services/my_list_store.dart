import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/media_item.dart';
import 'tmdb_service.dart';

/// Persists the user's saved titles as "movie:123" / "tv:456" keys in
/// SharedPreferences, and hydrates the full [MediaItem]s back from TMDB
/// on cold start. Single app-wide instance so every screen stays in sync.
class MyListStore extends ChangeNotifier {
  MyListStore._();

  static final MyListStore instance = MyListStore._();

  final Map<String, MediaItem> _items = {};
  bool _loaded = false;
  bool get isLoaded => _loaded;

  List<MediaItem> get items => _items.values.toList().reversed.toList();

  String _key(MediaItem item) => '${item.mediaType.name}:${item.id}';

  bool contains(MediaItem item) => _items.containsKey(_key(item));

  Future<void> ensureLoaded(TmdbService service) async {
    if (_loaded) return;
    _loaded = true;

    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('my_list_keys') ?? [];

    await Future.wait(saved.map((key) async {
      final parts = key.split(':');
      if (parts.length != 2) return;
      final type = parts[0] == 'movie' ? MediaType.movie : MediaType.tv;
      final id = int.tryParse(parts[1]);
      if (id == null) return;
      try {
        _items[key] = await service.details(id, type);
      } catch (_) {
        // Skip titles that fail to load (offline, removed from TMDB, etc.)
      }
    }));

    notifyListeners();
  }

  Future<void> toggle(MediaItem item) async {
    final key = _key(item);
    if (_items.containsKey(key)) {
      _items.remove(key);
    } else {
      _items[key] = item;
    }
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('my_list_keys', _items.keys.toList());
  }
}
