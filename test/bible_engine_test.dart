import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  test('Verify scriptures.db contents and structure', () async {
    final dbFile = File('assets/bible/scriptures.db');
    expect(dbFile.existsSync(), isTrue, reason: 'assets/bible/scriptures.db must exist');

    final db = await openDatabase(dbFile.absolute.path, readOnly: true);

    final countResult = await db.rawQuery('SELECT COUNT(*) as total FROM verses');
    final totalVerses = countResult.first['total'] as int;
    expect(totalVerses, greaterThan(12000));

    final gen1 = await db.rawQuery('SELECT text_te, text_en FROM verses WHERE book_id = 1 AND chapter = 1 AND verse = 1');
    expect(gen1.isNotEmpty, isTrue);
    expect(gen1.first['text_te'], contains('ఆదియందు దేవుడు'));

    final ex1 = await db.rawQuery('SELECT text_te, text_en FROM verses WHERE book_id = 2 AND chapter = 1 AND verse = 1');
    expect(ex1.isNotEmpty, isTrue);
    expect(ex1.first['text_te'], contains('యాకోబుతో'));

    final ex40 = await db.rawQuery('SELECT text_te, text_en FROM verses WHERE book_id = 2 AND chapter = 40 AND verse = 38');
    expect(ex40.isNotEmpty, isTrue);
    expect(ex40.first['text_te'], contains('యెహోవా మేఘము'));

    final jn3 = await db.rawQuery('SELECT text_te, text_en FROM verses WHERE book_id = 43 AND chapter = 3 AND verse = 16');
    expect(jn3.isNotEmpty, isTrue);
    expect(jn3.first['text_te'], contains('దేవుడు లోకమును ఎంతో ప్రేమించెను'));

    // Verify strongs table
    final strongsCheck = await db.rawQuery('SELECT * FROM strongs WHERE id = "H7225"');
    expect(strongsCheck.isNotEmpty, isTrue);
    expect(strongsCheck.first['translit'].toString().toLowerCase(), contains('bereshit'));

    await db.close();
  });
}
