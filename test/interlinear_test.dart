import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:yfc_app/services/bible_engine_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  test('Verify unique verse-specific interlinear tokens for Genesis 1:1 and Genesis 1:2', () async {
    final List<Map<String, dynamic>> gen1 = await BibleEngineService.getVerses(1, 1);
    expect(gen1.isNotEmpty, isTrue);

    final verse1 = gen1.firstWhere((v) => v['verse'] == 1);
    final verse2 = gen1.firstWhere((v) => v['verse'] == 2);

    final List<InterlinearWord> words1 = verse1['interlinearWords'];
    final List<InterlinearWord> words2 = verse2['interlinearWords'];

    expect(words1.isNotEmpty, isTrue);
    expect(words2.isNotEmpty, isTrue);

    // Verification Target 1: Genesis 1:1 words
    final v1Tags = words1.map((w) => w.strongsTag).toList();
    expect(v1Tags, contains('H7225'));
    expect(v1Tags, contains('H1254'));
    expect(v1Tags, contains('H430'));
    expect(v1Tags, contains('H8064'));
    expect(v1Tags, contains('H776'));

    final v1Originals = words1.map((w) => w.originalWord).toList();
    expect(v1Originals.any((w) => w.contains('בראשית') || w.contains('בְּרֵאשִׁית')), isTrue);

    // Verification Target 2: Genesis 1:2 words (MUST BE DIFFERENT)
    final v2Tags = words2.map((w) => w.strongsTag).toList();
    expect(v2Tags, contains('H1961'));
    expect(v2Tags, contains('H8414'));
    expect(v2Tags, contains('H922'));
    expect(v2Tags, contains('H2822'));
    expect(v2Tags, contains('H7307'));
    expect(v2Tags, contains('H7363'));

    final v2Originals = words2.map((w) => w.originalWord).toList();
    expect(v2Originals.any((w) => w.contains('תֹהוּ')), isTrue);

    // Tokens between verse 1 and verse 2 must NOT be identical lists
    expect(v1Originals, isNot(equals(v2Originals)));
  });
}
