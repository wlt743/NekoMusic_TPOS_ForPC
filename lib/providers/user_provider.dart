import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../models/user.dart';
import '../services/api_service.dart';

class UserProvider extends ChangeNotifier {
  static const String _userKey = 'user_data';
  static const String _tokenKey = 'user_token';
  
  final Box _settingsBox = Hive.box('settings');
  
  User? _user;
  String? _token;
  bool _isLoading = true;
  String? _error;
  
  User? get user => _user;
  String? get token => _token;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _user != null && _token != null;
  String? get error => _error;
  
  Future<void> loadUserFromStorage() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      final userData = _settingsBox.get(_userKey);
      final token = _settingsBox.get(_tokenKey);
      
      if (userData != null && token != null) {
        _user = User.fromJson(jsonDecode(userData));
        _token = token;
      }
    } catch (e) {
      print('Error loading user from storage: $e');
      _user = null;
      _token = null;
    }
    
    _isLoading = false;
    notifyListeners();
  }
  
  Future<bool> login(String username, String password, ApiService apiService) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final response = await apiService.login(username, password);
      
      if (response['success'] == true) {
        final data = response['data'];
        _user = User.fromJson(data['user']);
        _token = data['token'];
        
        // 保存到本地
        await _settingsBox.put(_userKey, jsonEncode(_user!.toJson()));
        await _settingsBox.put(_tokenKey, _token);
        
        // 设置 API token
        apiService.setToken(_token);
        
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = response['message'] ?? '登录失败';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = '网络错误，请稍后重试';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
  
  Future<bool> register({
    required String username,
    required String password,
    required String email,
    required String verificationCode,
    required ApiService apiService,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final response = await apiService.register(
        username: username,
        password: password,
        email: email,
        verificationCode: verificationCode,
      );
      
      if (response['success'] == true) {
        final data = response['data'];
        _user = User.fromJson(data['user']);
        _token = data['token'];
        
        // 保存到本地
        await _settingsBox.put(_userKey, jsonEncode(_user!.toJson()));
        await _settingsBox.put(_tokenKey, _token);
        
        // 设置 API token
        apiService.setToken(_token);
        
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = response['message'] ?? '注册失败';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = '网络错误，请稍后重试';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
  
  Future<void> logout(ApiService apiService) async {
    _user = null;
    _token = null;
    
    await _settingsBox.delete(_userKey);
    await _settingsBox.delete(_tokenKey);
    
    apiService.setToken(null);
    
    notifyListeners();
  }
  
  void updateUser(User user) {
    _user = user;
    _settingsBox.put(_userKey, jsonEncode(_user!.toJson()));
    notifyListeners();
  }
  
  void clearError() {
    _error = null;
    notifyListeners();
  }
  
  // 恢复 token 到 API 服务
  void restoreToken(ApiService apiService) {
    if (_token != null) {
      apiService.setToken(_token);
    }
  }
}
