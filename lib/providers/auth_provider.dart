import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hipster_videocallingapp/services/api_service.dart';
import 'package:hive_ce/hive.dart';

class AuthState {
  final bool isLoading;
  final String? error;

  AuthState({this.isLoading = false, this.error});
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() => AuthState();

  Future<void> login(String email, String password, VoidCallback onSuccess) async {
    state = AuthState(isLoading: true);
    try {
      await ApiService.login(email, password);  
      // Persist a simple logged-in flag so the app can restore the session on restart.
      try {
        Hive.box('auth').put('isLoggedIn', true);
      } catch (_) {
        // If Hive isn't available for some reason, proceed without persisting.
      }
      onSuccess();
    } catch (e) {
      state = AuthState(error: e.toString());
    }
  }

  /// Log the user out: clear persisted flag and reset state.
  Future<void> logout() async {
    try {
      await Hive.box('auth').put('isLoggedIn', false);
    } catch (_) {}
    // Reset provider state (not loading, no error)
    state = AuthState();
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(() => AuthNotifier());