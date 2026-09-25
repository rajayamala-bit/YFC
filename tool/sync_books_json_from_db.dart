import 'dart:convert';
import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() async {
  print('Syncing assets/bible/books/*.json files from scriptures.db...');

  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final dbPath = File('assets/bible/scriptures.db').absolute.path;
  final db = await openDatabase(dbPath, readOnly: true);

  final booksDir = Directory('assets/bible/books');
  if (!booksDir.existsSync()) {
    booksDir.createSync(recursive: true);
  }

  for (int b = 1; b <= 66; b++) {
    final List<Map<String, dynamic>> rows = await db.query(
      'verses',
      where: 'book_id = ?',
      whereArgs: [b],
      orderBy: 'chapter ASC, verse ASC',
    );

    if (rows.isEmpty) continue;

    Map<int, List<Map<String, dynamic>>> chapterMap = {};
    for (final row in rows) {
      final c = row['chapter'] as int;
      final v = row['verse'] as int;
      final te = row['text_te']?.toString() ?? '';
      final en = row['text_en']?.toString() ?? '';

      chapterMap.putIfAbsent(c, () => []).add({
        "verse_num": v,
        "text_te": te,
        "text_en": en,
      });
    }

    final List<Map<String, dynamic>> chaptersList = [];
    chapterMap.forEach((cNum, verses) {
      chaptersList.add({
        "chapter_num": cNum,
        "total_verses": verses.length,
        "verses": verses,
      });
    });

    final Map<String, dynamic> bookJson = {
      "book_id": b,
      "total_chapters": chaptersList.length,
      "chapters": chaptersList,
    };

    final bookFile = File('assets/bible/books/book_$b.json');
    final encoder = JsonEncoder.withIndent('  ');
    bookFile.writeAsStringSync(encoder.convert(bookJson));
    print('Synced book_$b.json (${chaptersList.length} chapters, ${rows.length} verses)');
  }

  await db.close();
  print('SUCCESS: All 66 book JSON files synced from canonical scriptures.db!');
}
