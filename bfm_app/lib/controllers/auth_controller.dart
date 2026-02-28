import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bfm_app/auth/token_store.dart';
import 'package:bfm_app/api/auth_api.dart';
import 'package:bfm_app/providers/api_providers.dart';

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

  @override
  AuthState build() {
    _authApi = ref.watch(authApiProvider);
    _tokenStore = ref.watch(tokenStoreProvider);
    _checkExistingSession();
    return const AuthState();
  }

  Future<void> _checkExistingSession() async {
    final token = await _tokenStore.getToken();
    if (token != null && token.isNotEmpty) {
      state = state.copyWith(isAuthed: true, clearError: true);
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
    state = const AuthState();
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);
