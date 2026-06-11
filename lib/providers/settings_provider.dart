import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preferencias del usuario: nombre de la tienda, margen por defecto
/// y API key de Grok.
class SettingsProvider extends ChangeNotifier {
  static const _keyStoreName = 'storeName';
  static const _keyDefaultMargin = 'defaultMargin';
  static const _keyGrokApiKey = 'grokApiKey';

  String _storeName = 'Mi Tienda';
  double _defaultMargin = 20;
  String _grokApiKey = '';
  bool _loaded = false;

  String get storeName => _storeName;
  double get defaultMargin => _defaultMargin;
  String get grokApiKey => _grokApiKey;
  bool get loaded => _loaded;
  bool get hasGrokKey => _grokApiKey.trim().isNotEmpty;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _storeName = prefs.getString(_keyStoreName) ?? 'Mi Tienda';
    _defaultMargin = prefs.getDouble(_keyDefaultMargin) ?? 20;
    _grokApiKey = prefs.getString(_keyGrokApiKey) ?? '';
    _loaded = true;
    notifyListeners();
  }

  Future<void> setStoreName(String value) async {
    _storeName = value.trim().isEmpty ? 'Mi Tienda' : value.trim();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyStoreName, _storeName);
  }

  Future<void> setDefaultMargin(double value) async {
    _defaultMargin = value.clamp(0, 500);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyDefaultMargin, _defaultMargin);
  }

  Future<void> setGrokApiKey(String value) async {
    _grokApiKey = value.trim();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyGrokApiKey, _grokApiKey);
  }
}
