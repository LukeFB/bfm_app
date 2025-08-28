import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:bfm_app/db/database.dart';
import 'package:bfm_app/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Desktop DB setup
  if ([
    TargetPlatform.windows,
    TargetPlatform.linux,
    TargetPlatform.macOS,
  ].contains(defaultTargetPlatform)) {
    sqfliteFfiInit();
    sqflite.databaseFactory = databaseFactoryFfi;
  }

  await BfmDatabase.instance.database;

  // Run app
  runApp(const ProviderScope(child: MyApp()));
}
