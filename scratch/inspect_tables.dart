import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final db = await openDatabase('assets/bible/scriptures.db', readOnly: true);
  final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
  print("TABLES: ${tables.map((t) => t['name'])}");

  for (final t in tables) {
    final name = t['name'];
    final info = await db.rawQuery("PRAGMA table_info($name)");
    print("TABLE $name COLUMNS: ${info.map((c) => c['name'])}");
  }

  final vSample = await db.rawQuery("SELECT * FROM verses LIMIT 2");
  print("VERSES SAMPLE: $vSample");

  if (tables.any((t) => t['name'] == 'strongs')) {
    final sSample = await db.rawQuery("SELECT * FROM strongs LIMIT 5");
    print("STRONGS SAMPLE: $sSample");
  }

  await db.close();
}
