// ---------------------------------------------------------------------------
// File: lib/main.dart
// Author: Luke Fraser-Brown
//
// Called by:
//   - Flutter runtime right after the engine spins up this binary.
//
// Purpose:
//   - Boots Flutter bindings, configures sqflite FFI on desktop, warms up the
//     AppDatabase singleton, then launches `MyApp` inside a ProviderScope.
//
// Inputs:
//   - `defaultTargetPlatform` and sqflite factories to know which database
//     driver to use, plus our AppDatabase singleton.
//
// Outputs:
//   - A fully initialised widget tree with dependency injection wired and
//     ready for `LockGate` to gate access.
//
// Notes:
//   - Keep this lean; heavy logic belongs in services or the database layer.
// ---------------------------------------------------------------------------
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:bfm_app/db/app_database.dart';
import 'package:bfm_app/app.dart';
import 'package:bfm_app/services/alert_notification_service.dart';
import 'package:bfm_app/services/referral_seeder.dart'; // TODO: Remove - use backend sync

import 'package:flutter/foundation.dart';

/// Boots bindings, configures sqflite for desktop, ensures the DB exists, and
/// finally calls `runApp`. Keep async work before `runApp` to avoid blank frames.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if ([ // Enable sqflite ffi for desktop dev 
    TargetPlatform.windows,
    TargetPlatform.linux,
    TargetPlatform.macOS,
  ].contains(defaultTargetPlatform)) {
    sqfliteFfiInit();
    sqflite.databaseFactory = databaseFactoryFfi;
  }

  // Initialize the database
  await AppDatabase.instance.database;

  // TODO: Remove this seed - pull referrals from backend instead
  try {
    await ReferralSeeder.seedIfEmpty();
  } catch (err) {
    debugPrint('Referral seeding failed: $err');
  }

  try {
    await AlertNotificationService.instance.resyncScheduledAlerts();
  } catch (err, stack) {
    debugPrint('Unable to prepare alert notifications: $err');
    debugPrint('$stack');
  }

  runApp(const ProviderScope(child: MyApp()));
}

