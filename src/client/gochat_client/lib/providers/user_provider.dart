import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../services/storage_service.dart';

class UserProvider with ChangeNotifier {
  User? _currentUser;
  String? _token;
  bool _isLoggedIn = false;

  User? get currentUser => _currentUser;
  String? get token => _token;
  bool get isLoggedIn => _isLoggedIn;

  Future<bool> checkLoginStatus() async {
    _token = await StorageService.getToken();
    if (_token != null) {
      final userJson = await StorageService.getUser();
      if (userJson != null) {
        _currentUser = User.fromJson(userJson);
        _isLoggedIn = true;
        notifyListeners();
        return true;
      }
    }
    return false;
  }

  Future<void> login(User user, String token) async {
    _currentUser = user;
    _token = token;
    _isLoggedIn = true;
    
    await StorageService.saveToken(token);
    await StorageService.saveUser(user.toJson());
    
    notifyListeners();
  }

  Future<void> logout() async {
    _currentUser = null;
    _token = null;
    _isLoggedIn = false;
    
    await StorageService.clearAll();
    
    notifyListeners();
  }

  void updateUser(User user) {
    _currentUser = user;
    StorageService.saveUser(user.toJson());
    notifyListeners();
  }
}
