import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:bfm_app/db/app_database.dart';
import 'package:bfm_app/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // --- Desktop DB setup (Windows, Linux, macOS) ---
  if ([
    TargetPlatform.windows,
    TargetPlatform.linux,
    TargetPlatform.macOS,
  ].contains(defaultTargetPlatform)) {
    sqfliteFfiInit();
    sqflite.databaseFactory = databaseFactoryFfi;
  }

  // Ensure DB is created
  await AppDatabase.instance.database;

  // Seed mock data (for development only)
  await seedMockData();

  // Run app with Riverpod
  runApp(const ProviderScope(child: MyApp()));
}

/// Seeds categories, transactions, budgets, goals, and recurring bills.
Future<void> seedMockData() async {
  final db = await AppDatabase.instance.database;

  // Clear existing tables
  await db.delete("categories");
  await db.delete("transactions");
  await db.delete("goals");
  await db.delete("budgets");
  await db.delete("recurring_transactions");

  // Insert categories
  final categories = [
    {"name": "Food", "icon": "🍔", "color": "#ff6934"},
    {"name": "Bills", "icon": "💡", "color": "#005494"},
    {"name": "Rent", "icon": "🏠", "color": "#548db6"},
    {"name": "Transport", "icon": "🚌", "color": "#fb9261"},
    {"name": "Entertainment", "icon": "🎮", "color": "#f5f5e1"},
  ];
  for (var c in categories) {
    await db.insert("categories", c);
  }

  // Insert some sample transactions
  await db.insert("transactions", {
    "category_id": 1,
    "amount": -45.20,
    "description": "Groceries",
    "date": "2025-09-09",
    "type": "expense",
  });
  await db.insert("transactions", {
    "category_id": 3, 
    "amount": -500.00,
    "description": "Rent",
    "date": "2025-09-05",
    "type": "expense",
  });
  await db.insert("transactions", {
    "category_id": 2,
    "amount": -80.00,
    "description": "Phone Bill",
    "date": "2025-09-01",
    "type": "expense",
  });
  await db.insert("transactions", {
    "category_id": 4,
    "amount": -20.00,
    "description": "Bus Pass",
    "date": "2025-09-03",
    "type": "expense",
  });
  await db.insert("transactions", {
    "category_id": 5,
    "amount": -75.00,
    "description": "Concert",
    "date": "2025-09-01",
    "type": "expense",
  });
  await db.insert("transactions", {
    "category_id": null,
    "amount": 1200.00,
    "description": "Paycheck",
    "date": "2025-08-30",
    "type": "income",
  });

  // Weekly budgets
  await db.insert("budgets", {
    "category_id": 1,
    "weekly_limit": 100.0,
    "period_start": "2025-09-08",
  });
  await db.insert("budgets", {
    "category_id": 2,
    "weekly_limit": 80.0,
    "period_start": "2025-09-08",
  });
  await db.insert("budgets", {
    "category_id": 3,
    "weekly_limit": 125.0,
    "period_start": "2025-09-08",
  });

  // Goals
  await db.insert("goals", {
    "title": "Save for Laptop",
    "target_amount": 1500,
    "current_amount": 750,
    "due_date": "2025-12-01"
  });
  await db.insert("goals", {
    "title": "Emergency Fund",
    "target_amount": 2000,
    "current_amount": 400,
    "due_date": "2026-01-01"
  });

  // Recurring bills
  await db.insert("recurring_transactions", {
    "category_id": 2,
    "amount": 80.0,
    "frequency": "monthly",
    "next_due_date": "2025-10-01",
    "description": "Phone Bill"
  });
  await db.insert("recurring_transactions", {
    "category_id": 2,
    "amount": 120.0,
    "frequency": "monthly",
    "next_due_date": "2025-09-25",
    "description": "Car Insurance"
  });
}
