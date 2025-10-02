import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:local_auth/local_auth.dart';  // local_auth
import 'package:bfm_app/db/app_database.dart';
import 'package:bfm_app/app.dart';

import 'package:flutter/foundation.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if ([
    TargetPlatform.windows,
    TargetPlatform.linux,
    TargetPlatform.macOS,
  ].contains(defaultTargetPlatform)) {
    sqfliteFfiInit();
    sqflite.databaseFactory = databaseFactoryFfi;
  }

  // Initialize the database (creates tables if not exists)
  await AppDatabase.instance.database;

  // ** Remove development seed data ** 
  // (No more calling seedMockData(); to avoid inserting fake data on startup)

  runApp(const ProviderScope(child: MyApp()));
}

