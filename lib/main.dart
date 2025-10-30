import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';
import 'package:hive_ce_flutter/adapters.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('users'); 
  // Open an 'auth' box to persist simple auth state (isLoggedIn)
  await Hive.openBox('auth');
  final bool isLoggedIn = Hive.box('auth').get('isLoggedIn', defaultValue: false) as bool;
  runApp(ProviderScope(child: MyApp(isLoggedIn: isLoggedIn)));
}