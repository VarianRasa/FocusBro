import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class SecureStorageBackend {
  Future<String?> read({required String key});
  Future<void> write({required String key, required String value});
  Future<void> delete({required String key});
  Future<void> deleteAll();
}

class FlutterSecureStorageBackend implements SecureStorageBackend {
  FlutterSecureStorageBackend({
    FlutterSecureStorage? storage,
  }) : _storage = storage ?? const FlutterSecureStorage();

  static const AndroidOptions _androidOptions = AndroidOptions(
    encryptedSharedPreferences: true,
  );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read({required String key}) {
    return _storage.read(key: key, aOptions: _androidOptions);
  }

  @override
  Future<void> write({required String key, required String value}) {
    return _storage.write(
      key: key,
      value: value,
      aOptions: _androidOptions,
    );
  }

  @override
  Future<void> delete({required String key}) {
    return _storage.delete(key: key, aOptions: _androidOptions);
  }

  @override
  Future<void> deleteAll() {
    return _storage.deleteAll(aOptions: _androidOptions);
  }
}

class InMemorySecureStorageBackend implements SecureStorageBackend {
  final Map<String, String> _values = <String, String>{};

  @override
  Future<String?> read({required String key}) async => _values[key];

  @override
  Future<void> write({required String key, required String value}) async {
    _values[key] = value;
  }

  @override
  Future<void> delete({required String key}) async {
    _values.remove(key);
  }

  @override
  Future<void> deleteAll() async {
    _values.clear();
  }
}

class SecureStorageService {
  static final SecureStorageService instance = SecureStorageService._();

  SecureStorageService._();

  SecureStorageBackend _backend = FlutterSecureStorageBackend();

  Future<String?> readString(String key) {
    return _backend.read(key: key);
  }

  Future<void> writeString(String key, String value) {
    return _backend.write(key: key, value: value);
  }

  Future<void> delete(String key) {
    return _backend.delete(key: key);
  }

  Future<bool> containsKey(String key) async {
    final value = await readString(key);
    return value != null && value.trim().isNotEmpty;
  }

  @visibleForTesting
  void setBackendForTesting(SecureStorageBackend backend) {
    _backend = backend;
  }

  @visibleForTesting
  void resetBackendForTesting() {
    _backend = FlutterSecureStorageBackend();
  }
}
