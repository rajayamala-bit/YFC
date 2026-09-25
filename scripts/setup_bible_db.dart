import 'dart:convert';
import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() async {
  print('Building Bible SQLite database assets/bible/scriptures.db using sqflite_common_ffi...');

  // Initialize FFI for desktop/command-line Dart
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final dbFile = File('assets/bible/scriptures.db');
  if (dbFile.existsSync()) {
    dbFile.deleteSync();
  }
  final dbPath = dbFile.absolute.path;

  final db = await openDatabase(dbPath, version: 1, onCreate: (db, version) async {
    await db.execute('''
      CREATE TABLE verses (
        book_id INTEGER NOT NULL,
        chapter INTEGER NOT NULL,
        verse INTEGER NOT NULL,
        text_te TEXT,
        text_en TEXT,
        PRIMARY KEY (book_id, chapter, verse)
      )
    ''');
    await db.execute('CREATE INDEX idx_book_chapter ON verses (book_id, chapter)');
  });

  int totalInserted = 0;

  await db.transaction((txn) async {
    final batch = txn.batch();

    for (int b = 1; b <= 66; b++) {
      File bookFile = File('assets/bible/books/book_$b.json');
      if (b == 2 && File('assets/bible/books/book_2_exodus.json').existsSync()) {
        bookFile = File('assets/bible/books/book_2_exodus.json');
      }

      if (!bookFile.existsSync()) {
        continue;
      }

      try {
        final Map<String, dynamic> bookData = jsonDecode(bookFile.readAsStringSync());
        final chapters = bookData['chapters'] as List? ?? [];

        for (var ch in chapters) {
          final cNum = ch['chapter_num'] is int ? ch['chapter_num'] as int : 1;
          final verses = ch['verses'] as List? ?? [];

          for (var v in verses) {
            final vNum = v['verse_num'] is int ? v['verse_num'] as int : 1;
            final te = v['text_te']?.toString() ?? v['text']?.toString() ?? '';
            final en = v['text_en']?.toString() ?? '';

            batch.insert(
              'verses',
              {
                'book_id': b,
                'chapter': cNum,
                'verse': vNum,
                'text_te': te,
                'text_en': en,
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
            totalInserted++;
          }
        }
      } catch (e) {
        print('Error parsing book $b: $e');
      }
    }

    await batch.commit(noResult: true);
  });

  await db.close();

  final finalSize = File(dbPath).lengthSync();
  print('Successfully compiled assets/bible/scriptures.db with $totalInserted verses ($finalSize bytes)!');
}
