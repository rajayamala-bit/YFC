import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() async {
  print('====================================================');
  print('Building Complete 66-Book Canonical Scripture Database');
  print('====================================================');

  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final dbFile = File('assets/bible/scriptures.db');
  if (dbFile.existsSync()) {
    try {
      dbFile.deleteSync();
      print('Deleted old scriptures.db');
    } catch (e) {
      print('Warning deleting old db: $e');
    }
  }

  final dbPath = dbFile.absolute.path;
  final db = await openDatabase(
    dbPath,
    version: 1,
    onCreate: (db, version) async {
      await db.execute('''
        CREATE TABLE verses (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          book_id INTEGER NOT NULL,
          chapter INTEGER NOT NULL,
          verse INTEGER NOT NULL,
          text_te TEXT,
          text_en TEXT
        );
      ''');
      await db.execute('CREATE INDEX idx_lookup ON verses(book_id, chapter);');

      await db.execute('''
        CREATE TABLE strongs (
          id TEXT PRIMARY KEY,
          lemma TEXT,
          translit TEXT,
          pronounce TEXT,
          definition TEXT,
          outline TEXT
        );
      ''');
    },
  );

  final List<Map<String, String>> bookMap = [
    {"id": "1", "te": "Genesis.json", "en": "Genesis.json"},
    {"id": "2", "te": "Exodus.json", "en": "Exodus.json"},
    {"id": "3", "te": "Leviticus.json", "en": "Leviticus.json"},
    {"id": "4", "te": "Numbers.json", "en": "Numbers.json"},
    {"id": "5", "te": "Deuteronomy.json", "en": "Deuteronomy.json"},
    {"id": "6", "te": "Joshua.json", "en": "Joshua.json"},
    {"id": "7", "te": "Judges.json", "en": "Judges.json"},
    {"id": "8", "te": "Ruth.json", "en": "Ruth.json"},
    {"id": "9", "te": "1 Samuel.json", "en": "1Samuel.json"},
    {"id": "10", "te": "2 Samuel.json", "en": "2Samuel.json"},
    {"id": "11", "te": "1 Kings.json", "en": "1Kings.json"},
    {"id": "12", "te": "2 Kings.json", "en": "2Kings.json"},
    {"id": "13", "te": "1 Chronicles.json", "en": "1Chronicles.json"},
    {"id": "14", "te": "2 Chronicles.json", "en": "2Chronicles.json"},
    {"id": "15", "te": "Ezra.json", "en": "Ezra.json"},
    {"id": "16", "te": "Nehemiah.json", "en": "Nehemiah.json"},
    {"id": "17", "te": "Esther.json", "en": "Esther.json"},
    {"id": "18", "te": "Job.json", "en": "Job.json"},
    {"id": "19", "te": "Psalms.json", "en": "Psalms.json"},
    {"id": "20", "te": "Proverbs.json", "en": "Proverbs.json"},
    {"id": "21", "te": "Ecclesiastes.json", "en": "Ecclesiastes.json"},
    {"id": "22", "te": "Song of Songs.json", "en": "SongofSolomon.json"},
    {"id": "23", "te": "Isaiah.json", "en": "Isaiah.json"},
    {"id": "24", "te": "Jeremiah.json", "en": "Jeremiah.json"},
    {"id": "25", "te": "Lamentations.json", "en": "Lamentations.json"},
    {"id": "26", "te": "Ezekiel.json", "en": "Ezekiel.json"},
    {"id": "27", "te": "Daniel.json", "en": "Daniel.json"},
    {"id": "28", "te": "Hosea.json", "en": "Hosea.json"},
    {"id": "29", "te": "Joel.json", "en": "Joel.json"},
    {"id": "30", "te": "Amos.json", "en": "Amos.json"},
    {"id": "31", "te": "Obadiah.json", "en": "Obadiah.json"},
    {"id": "32", "te": "Jonah.json", "en": "Jonah.json"},
    {"id": "33", "te": "Micah.json", "en": "Micah.json"},
    {"id": "34", "te": "Nahum.json", "en": "Nahum.json"},
    {"id": "35", "te": "Habakkuk.json", "en": "Habakkuk.json"},
    {"id": "36", "te": "Zephaniah.json", "en": "Zephaniah.json"},
    {"id": "37", "te": "Haggai.json", "en": "Haggai.json"},
    {"id": "38", "te": "Zechariah.json", "en": "Zechariah.json"},
    {"id": "39", "te": "Malachi.json", "en": "Malachi.json"},
    {"id": "40", "te": "Matthew.json", "en": "Matthew.json"},
    {"id": "41", "te": "Mark.json", "en": "Mark.json"},
    {"id": "42", "te": "Luke.json", "en": "Luke.json"},
    {"id": "43", "te": "John.json", "en": "John.json"},
    {"id": "44", "te": "Acts.json", "en": "Acts.json"},
    {"id": "45", "te": "Romans.json", "en": "Romans.json"},
    {"id": "46", "te": "1 Corinthians.json", "en": "1Corinthians.json"},
    {"id": "47", "te": "2 Corinthians.json", "en": "2Corinthians.json"},
    {"id": "48", "te": "Galatians.json", "en": "Galatians.json"},
    {"id": "49", "te": "Ephesians.json", "en": "Ephesians.json"},
    {"id": "50", "te": "Philippians.json", "en": "Philippians.json"},
    {"id": "51", "te": "Colossians.json", "en": "Colossians.json"},
    {"id": "52", "te": "1 Thessalonians.json", "en": "1Thessalonians.json"},
    {"id": "53", "te": "2 Thessalonians.json", "en": "2Thessalonians.json"},
    {"id": "54", "te": "1 Timothy.json", "en": "1Timothy.json"},
    {"id": "55", "te": "2 Timothy.json", "en": "2Timothy.json"},
    {"id": "56", "te": "Titus.json", "en": "Titus.json"},
    {"id": "57", "te": "Philemon.json", "en": "Philemon.json"},
    {"id": "58", "te": "Hebrews.json", "en": "Hebrews.json"},
    {"id": "59", "te": "James.json", "en": "James.json"},
    {"id": "60", "te": "1 Peter.json", "en": "1Peter.json"},
    {"id": "61", "te": "2 Peter.json", "en": "2Peter.json"},
    {"id": "62", "te": "1 John.json", "en": "1John.json"},
    {"id": "63", "te": "2 John.json", "en": "2John.json"},
    {"id": "64", "te": "3 John.json", "en": "3John.json"},
    {"id": "65", "te": "Jude.json", "en": "Jude.json"},
    {"id": "66", "te": "Revelation.json", "en": "Revelation.json"}
  ];

  final client = http.Client();
  int totalVersesInserted = 0;

  for (final b in bookMap) {
    final bookId = int.parse(b['id']!);
    final teFileName = b['te']!;
    final enFileName = b['en']!;

    final teUrl = 'https://raw.githubusercontent.com/aruljohn/Bible-telugu/main/$teFileName';
    final enUrl = 'https://raw.githubusercontent.com/aruljohn/Bible-kjv/master/$enFileName';

    Map<String, String> teVerseMap = {};
    Map<String, String> enVerseMap = {};

    try {
      final res = await client.get(Uri.parse(teUrl));
      if (res.statusCode == 200) {
        final Map<String, dynamic> teData = json.decode(res.body);
        final chapters = teData['chapters'] as List? ?? [];
        for (final ch in chapters) {
          final cNum = int.tryParse(ch['chapter'].toString()) ?? 1;
          final verses = ch['verses'] as List? ?? [];
          for (final v in verses) {
            final vNum = int.tryParse(v['verse'].toString()) ?? 1;
            final text = v['text']?.toString() ?? '';
            teVerseMap['${cNum}_$vNum'] = text;
          }
        }
      } else {
        print('Error fetching Telugu book $bookId ($teFileName): HTTP ${res.statusCode}');
      }
    } catch (e) {
      print('Exception fetching Telugu book $bookId: $e');
    }

    try {
      final res = await client.get(Uri.parse(enUrl));
      if (res.statusCode == 200) {
        final Map<String, dynamic> enData = json.decode(res.body);
        final chapters = enData['chapters'] as List? ?? [];
        for (final ch in chapters) {
          final cNum = int.tryParse(ch['chapter'].toString()) ?? 1;
          final verses = ch['verses'] as List? ?? [];
          for (final v in verses) {
            final vNum = int.tryParse(v['verse'].toString()) ?? 1;
            final text = v['text']?.toString() ?? '';
            enVerseMap['${cNum}_$vNum'] = text;
          }
        }
      } else {
        print('Error fetching KJV book $bookId ($enFileName): HTTP ${res.statusCode}');
      }
    } catch (e) {
      print('Exception fetching KJV book $bookId: $e');
    }

    final Set<String> chapterVerseKeys = {...teVerseMap.keys, ...enVerseMap.keys};

    await db.transaction((txn) async {
      final Batch batch = txn.batch();
      for (final key in chapterVerseKeys) {
        final parts = key.split('_');
        final cNum = int.parse(parts[0]);
        final vNum = int.parse(parts[1]);
        final teText = teVerseMap[key] ?? '';
        final enText = enVerseMap[key] ?? '';

        batch.insert('verses', {
          'book_id': bookId,
          'chapter': cNum,
          'verse': vNum,
          'text_te': teText,
          'text_en': enText,
        });
        totalVersesInserted++;
      }
      await batch.commit(noResult: true);
    });

    print('Book $bookId (${b['en']}) -> Inserted ${chapterVerseKeys.length} verses.');
  }

  // Populate Strong's Concordance Dictionary
  final defaultStrongs = {
    'H7225': {'lemma': 'רֵאשִׁית', 'translit': 'Bereshit', 'pronounce': 'ray-sheeth\'', 'definition': 'First, chief, choice part, beginning time.', 'outline': 'beginning, chiefest, firstfruits.'},
    'H1254': {'lemma': 'בָּרָא', 'translit': 'Bara', 'pronounce': 'baw-raw\'', 'definition': 'To create, shape, form, fashion out of nothing.', 'outline': 'create, make, choose.'},
    'H430': {'lemma': 'אֱלֹהִים', 'translit': 'Elohim', 'pronounce': 'el-o-heem\'', 'definition': 'Rulers, judges, divine ones, supreme God.', 'outline': 'God, judge, deity.'},
    'H853': {'lemma': 'אֵת', 'translit': 'Et', 'pronounce': 'ayth', 'definition': 'Untranslatable grammatical mark of direct object.', 'outline': 'direct object marker.'},
    'H8064': {'lemma': 'שָׁמַיִם', 'translit': 'Shamayim', 'pronounce': 'shaw-mah\'-yim', 'definition': 'Heavens, sky, visible atmosphere, abode of God.', 'outline': 'heaven, air, sky.'},
    'H776': {'lemma': 'אֶרֶץ', 'translit': 'Eretz', 'pronounce': 'eh\'-rets', 'definition': 'Earth, land, country, physical ground.', 'outline': 'earth, land, ground.'},
    'H3068': {'lemma': 'יְהוָה', 'translit': 'Yahweh', 'pronounce': 'yeh-ho-vaw\'', 'definition': 'The Self-Existent One, Covenant LORD God of Israel.', 'outline': 'LORD, Jehovah.'},
    'G3056': {'lemma': 'Λόγος', 'translit': 'Logos', 'pronounce': 'log\'-os', 'definition': 'Divine Expression, Word, Reasoning, Personified Christ.', 'outline': 'Word, treatise, message.'},
    'G2316': {'lemma': 'Θεός', 'translit': 'Theos', 'pronounce': 'the-os\'', 'definition': 'Supreme Divinity, God, Creator and Preserver.', 'outline': 'God, Lord.'},
    'G25': {'lemma': 'ἀγάπάω', 'translit': 'Agapao', 'pronounce': 'ag-ap-ah\'-o', 'definition': 'To love unconditionally, divine selfless affection.', 'outline': 'love, beloved.'},
    'G2889': {'lemma': 'κόσμος', 'translit': 'Kosmos', 'pronounce': 'kos\'-mos', 'definition': 'World, order, universe, humanity.', 'outline': 'world, order, adornment.'},
    'G5485': {'lemma': 'χάρις', 'translit': 'Charis', 'pronounce': 'khar\'-ece', 'definition': 'Grace, unmerited divine favor and spiritual blessing.', 'outline': 'grace, favor, gift.'},
    'G2962': {'lemma': 'Κύριος', 'translit': 'Kurios', 'pronounce': 'koo\'-ree-os', 'definition': 'Lord, Master, Supreme Sovereign, Messiah.', 'outline': 'Lord, Master.'},
  };

  await db.transaction((txn) async {
    final Batch batch = txn.batch();
    defaultStrongs.forEach((tag, entry) {
      batch.insert(
        'strongs',
        {
          'id': tag,
          'lemma': entry['lemma'],
          'translit': entry['translit'],
          'pronounce': entry['pronounce'],
          'definition': entry['definition'],
          'outline': entry['outline'],
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
    await batch.commit(noResult: true);
  });

  client.close();
  await db.close();

  final fileMb = (dbFile.lengthSync() / (1024 * 1024)).toStringAsFixed(2);
  print('====================================================');
  print('SUCCESS: scriptures.db compiled cleanly!');
  print('Total Verses Inserted: $totalVersesInserted');
  print('Database Size: $fileMb MB');
  print('====================================================');
}
