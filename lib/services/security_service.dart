import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// On-device security: the database encryption key, the app-lock PIN, and
/// biometric unlock.
///
/// Everything here stays on the device. The database key is a per-install
/// random value kept in the platform keystore/keychain (via
/// [FlutterSecureStorage]); it is never derived from the PIN, so unlocking is
/// instant and losing the PIN does not lose the data. The PIN is stored only as
/// a salted SHA-256 hash — the plaintext PIN is never persisted.
///
/// The key protects data *at rest*: a database file copied off a stolen device
/// is unreadable without the keystore entry. The PIN/biometric lock is a
/// separate access gate on the running app (see `LockController`).
class SecurityService {
  SecurityService({
    FlutterSecureStorage? storage,
    LocalAuthentication? localAuth,
  })  : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            ),
        _localAuth = localAuth ?? LocalAuthentication();

  final FlutterSecureStorage _storage;
  final LocalAuthentication _localAuth;

  static const _kDbKey = 'db_passphrase';
  static const _kPinHash = 'pin_hash';
  static const _kPinSalt = 'pin_salt';

  // --- Database encryption key ---

  /// The SQLCipher passphrase for this install, creating it on first use. A
  /// 256-bit random value, base64-encoded.
  Future<String> databasePassphrase() async {
    final existing = await _storage.read(key: _kDbKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final key = base64UrlEncode(_randomBytes(32));
    await _storage.write(key: _kDbKey, value: key);
    return key;
  }

  // --- App-lock PIN ---

  Future<bool> hasPin() async {
    final hash = await _storage.read(key: _kPinHash);
    return hash != null && hash.isNotEmpty;
  }

  /// Set (or replace) the PIN. Stored as a salted SHA-256 hash.
  Future<void> setPin(String pin) async {
    final salt = base64UrlEncode(_randomBytes(16));
    await _storage.write(key: _kPinSalt, value: salt);
    await _storage.write(key: _kPinHash, value: _hashPin(pin, salt));
  }

  Future<bool> verifyPin(String pin) async {
    final salt = await _storage.read(key: _kPinSalt);
    final hash = await _storage.read(key: _kPinHash);
    if (salt == null || hash == null) return false;
    return _constantTimeEquals(_hashPin(pin, salt), hash);
  }

  Future<void> clearPin() async {
    await _storage.delete(key: _kPinHash);
    await _storage.delete(key: _kPinSalt);
  }

  // --- Biometric ---

  /// Whether the device can do biometric (or device-credential) auth.
  Future<bool> canUseBiometric() async {
    try {
      final supported = await _localAuth.isDeviceSupported();
      final canCheck = await _localAuth.canCheckBiometrics;
      return supported && canCheck;
    } catch (_) {
      return false;
    }
  }

  /// Prompt for biometric unlock. Returns false (never throws) when biometrics
  /// are unavailable or the user cancels — the caller falls back to the PIN.
  Future<bool> authenticateBiometric(String reason) async {
    try {
      return await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  // --- Helpers ---

  static String _hashPin(String pin, String salt) {
    final digest = sha256.convert(utf8.encode('$salt:$pin'));
    return digest.toString();
  }

  static List<int> _randomBytes(int n) {
    final rng = Random.secure();
    return List<int>.generate(n, (_) => rng.nextInt(256));
  }

  /// Length-constant comparison, so verification time doesn't leak the hash.
  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}
