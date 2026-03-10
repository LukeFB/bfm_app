import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bfm_app/auth/credential_store.dart';
import 'package:bfm_app/auth/token_store.dart';
import 'package:bfm_app/api/api_client.dart';
import 'package:bfm_app/api/auth_api.dart';
import 'package:bfm_app/providers/api_providers.dart';

enum SessionStatus { valid, expired, noToken, networkError }

@immutable
class AuthState {
  final bool isLoading;
  final bool isAuthed;
  final String? error;
  final Map<String, dynamic>? user;

  const AuthState({
    this.isLoading = false,
    this.isAuthed = false,
    this.error,
    this.user,
  });

  AuthState copyWith({
    bool? isLoading,
    bool? isAuthed,
    String? error,
    Map<String, dynamic>? user,
    bool clearError = false,
    bool clearUser = false,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isAuthed: isAuthed ?? this.isAuthed,
      error: clearError ? null : (error ?? this.error),
      user: clearUser ? null : (user ?? this.user),
    );
  }
}

class AuthController extends Notifier<AuthState> {
  late final AuthApi _authApi;
  late final TokenStore _tokenStore;
  late final CredentialStore _credentialStore;

  @override
  AuthState build() {
    _authApi = ref.watch(authApiProvider);
    _tokenStore = ref.watch(tokenStoreProvider);
    _credentialStore = ref.watch(credentialStoreProvider);
    _checkExistingSession();
    return const AuthState();
  }

  Future<void> _checkExistingSession() async {
    final token = await _tokenStore.getToken();
    if (token != null && token.isNotEmpty) {
      state = state.copyWith(isAuthed: true, clearError: true);
    }
  }

  /// Validates the stored token against the backend.
  /// Returns [SessionStatus.valid] if /auth/me succeeds,
  /// [SessionStatus.expired] if 401, [SessionStatus.noToken] if no stored
  /// token, or [SessionStatus.networkError] on connectivity failure.
  ///
  /// When the token is expired but stored credentials exist, automatically
  /// re-authenticates so the user doesn't have to sign in again.
  Future<SessionStatus> tryRestoreSession() async {
    final token = await _tokenStore.getToken();
    if (token == null || token.isEmpty) {
      return await _tryAutoLogin() ? SessionStatus.valid : SessionStatus.noToken;
    }

    try {
      final user = await _authApi.me();
      state = state.copyWith(isAuthed: true, user: user, clearError: true);
      return SessionStatus.valid;
    } on DioException catch (e) {
      if (e.error is UnauthorizedException) {
        await _tokenStore.clear();
        state = const AuthState();
        final reAuthed = await _tryAutoLogin();
        return reAuthed ? SessionStatus.valid : SessionStatus.expired;
      }
      state = state.copyWith(isAuthed: true, clearError: true);
      return SessionStatus.networkError;
    } catch (_) {
      state = state.copyWith(isAuthed: true, clearError: true);
      return SessionStatus.networkError;
    }
  }

  /// Attempts to sign in using stored credentials. Returns true on success.
  Future<bool> _tryAutoLogin() async {
    if (!await _credentialStore.hasCredentials()) return false;

    final email = await _credentialStore.getEmail();
    final password = await _credentialStore.getPassword();
    if (email == null || password == null) return false;

    try {
      final token = await _authApi.login(email: email, password: password);
      await _tokenStore.setToken(token);
      state = state.copyWith(isAuthed: true, clearError: true);
      return true;
    } catch (_) {
      await _credentialStore.clear();
      return false;
    }
  }

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final token = await _authApi.login(email: email, password: password);
      await _tokenStore.setToken(token);
      await _credentialStore.saveCredentials(email, password);
      state = state.copyWith(isLoading: false, isAuthed: true);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> register({
    required String email,
    required String password,
    required String passwordConfirmation,
    required String firstName,
    String? lastName,
    String? phone,
    String? dateOfBirth,
    String? incomeFrequency,
    String? primaryGoal,
    dynamic referrerToken,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final token = await _authApi.register(
        email: email,
        password: password,
        passwordConfirmation: passwordConfirmation,
        firstName: firstName,
        lastName: lastName,
        phone: phone,
        dateOfBirth: dateOfBirth,
        incomeFrequency: incomeFrequency,
        primaryGoal: primaryGoal,
        referrerToken: referrerToken,
      );
      await _tokenStore.setToken(token);
      await _credentialStore.saveCredentials(email, password);
      state = state.copyWith(isLoading: false, isAuthed: true);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<void> loadMe() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final user = await _authApi.me();
      state = state.copyWith(isLoading: false, user: user);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> logout() async {
    await _tokenStore.clear();
    await _credentialStore.clear();
    state = const AuthState();
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);
