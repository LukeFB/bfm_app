import 'package:bfm_app/db/app_database.dart';
import 'package:bfm_app/models/transaction_model.dart';
import 'package:bfm_app/repositories/transaction_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final categorized = {
    "_id": "trans_cmg9dvlk701xn02jw3xeo1xbi",
    "_account": "acc_cmfpabfuw000402la5gs92z1c",
    "_user": "user_cmfp9up53008108ju2seag61d",
    "_connection": "conn_cjgaawozb000001nyd111xixr",
    "created_at": "2025-10-02T12:20:34.862Z",
    "updated_at": "2025-10-02T12:20:35.760Z",
    "date": "2025-09-11T11:38:04.000Z",
    "description": "City Superet",
    "amount": -6.17,
    "balance": 336.06,
    "type": "CREDIT CARD",
    "hash": "acc_cmfpabfuw000402la5gs92z1c-4233d47ae058110d3bbbc387ce87ab9e",
    "meta": {
      "card_suffix": "1061",
      "logo": "https://cdn.akahu.nz/logos/merchants/default.png"
    },
    "merchant": {
      "_id": "merchant_ckrlk7gwl004w08l49ppzdhxb",
      "name": "City Superette"
    },
    "category": {
      "_id": "nzfcc_ckouvvyaa001b08ml4uj9b2qc",
      "name": "Convenience stores",
      "groups": {
        "personal_finance": {
          "_id": "group_clasr0ysw000xhk4mf7mg2j1z",
          "name": "Food"
        }
      }
    }
  };

  final uncategorized = {
    "_id": "trans_cmg9dvlk701xq02jw9amq3q12",
    "_account": "acc_cmfpabfuw000402la5gs92z1c",
    "_user": "user_cmfp9up53008108ju2seag61d",
    "_connection": "conn_cjgaawozb000001nyd111xixr",
    "created_at": "2025-10-02T12:20:34.862Z",
    "updated_at": "2025-10-02T12:20:35.760Z",
    "date": "2025-09-10T16:13:19.000Z",
    "description": "Bridgette Tolfrey",
    "amount": -50,
    "balance": 236.37,
    "type": "STANDING ORDER",
    "meta": {
      "other_account": "06-0491-0173079-01"
    },
  };

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    await AppDatabase.instance.close();
    final dbPath = await getDatabasesPath();
    final fullPath = join(dbPath, 'bfm_app.db');
    await databaseFactory.deleteDatabase(fullPath);
  });

  test('TransactionModel.fromAkahu maps categorised payload', () {
    final model = TransactionModel.fromAkahu(Map<String, dynamic>.from(categorized));
    expect(model.akahuId, categorized["_id"]);
    expect(model.akahuHash, categorized["hash"]);
    expect(model.categoryName, "Convenience stores");
    expect(model.type, 'expense');
    expect(model.date, '2025-09-11');
  });

  test('TransactionModel.fromAkahu handles uncategorized payload', () {
    final model = TransactionModel.fromAkahu(Map<String, dynamic>.from(uncategorized));
    expect(model.categoryName, isNull);
    expect(model.akahuHash, isNotEmpty);
    expect(model.description, 'Bridgette Tolfrey');
    expect(model.type, 'expense');
  });

  test('TransactionRepository.upsertFromAkahu deduplicates by akahu hash', () async {
    final dupList = [
      Map<String, dynamic>.from(categorized),
      Map<String, dynamic>.from(categorized),
    ];
    await TransactionRepository.upsertFromAkahu(dupList);
    final db = await AppDatabase.instance.database;
    final rows = await db.query('transactions');
    expect(rows.length, 1);
    expect(rows.first['akahu_hash'], categorized['hash']);
    expect(rows.first['category_name'], 'Convenience stores');
  });

  test('TransactionRepository.upsertFromAkahu assigns Uncategorized fallback', () async {
    await TransactionRepository.upsertFromAkahu([Map<String, dynamic>.from(uncategorized)]);
    final db = await AppDatabase.instance.database;
    final rows = await db.query('transactions');
    expect(rows.length, 1);
    expect(rows.first['category_name'], 'Uncategorized');
    expect(rows.first['akahu_hash'], isNotNull);
  });

  test('Excluded flag persists through upserts', () async {
    await TransactionRepository.upsertFromAkahu([Map<String, dynamic>.from(categorized)]);
    final db = await AppDatabase.instance.database;
    var rows = await db.query('transactions');
    expect(rows.length, 1);
    final id = rows.first['id'] as int?;
    final hash = rows.first['akahu_hash'] as String?;
    expect(id, isNotNull);
    expect(hash, isNotNull);
    expect(rows.first['excluded'], 0);

    await TransactionRepository.setExcluded(id: id!, excluded: true);
    rows = await db.query(
      'transactions',
      where: 'akahu_hash = ?',
      whereArgs: [hash],
    );
    expect(rows.first['excluded'], 1);

    // Upserting the same payload should preserve the exclusion flag.
    await TransactionRepository.upsertFromAkahu([Map<String, dynamic>.from(categorized)]);
    rows = await db.query(
      'transactions',
      where: 'akahu_hash = ?',
      whereArgs: [hash],
    );
    expect(rows.first['excluded'], 1);
  });
}

