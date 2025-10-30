// lib/providers/user_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';
import '../services/api_service.dart';

final userProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final box = Hive.box('users');

  if (box.isNotEmpty) {
    final cached = box.get('cached_users');
    if (cached is List) {
      return cached.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
  }

  final users = await ApiService.getUsers();
  await box.put('cached_users', users);
  return users;
});