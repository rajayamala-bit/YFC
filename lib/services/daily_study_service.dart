import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/quiz_model.dart';

class DailyPortionData {
  final String title;
  final String passage;
  final String bookName;
  final int startChapter;
  final int startVerse;
  final int endChapter;
  final int endVerse;
  final String studyNotesEn;
  final String studyNotesTe;
  final List<QuizQuestion> quizQuestions;
  final String publishedDate;

  const DailyPortionData({
    required this.title,
    required this.passage,
    required this.bookName,
    required this.startChapter,
    required this.startVerse,
    required this.endChapter,
    required this.endVerse,
    required this.studyNotesEn,
    required this.studyNotesTe,
    required this.quizQuestions,
    required this.publishedDate,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'passage': passage,
      'book_name': bookName,
      'start_chapter': startChapter,
      'start_verse': startVerse,
      'end_chapter': endChapter,
      'end_verse': endVerse,
      'study_notes_en': studyNotesEn,
      'study_notes_te': studyNotesTe,
      'published_date': publishedDate,
      'quiz_questions': quizQuestions.map((q) => {
        'id': q.id,
        'question_en': q.questionEn,
        'question_te': q.questionTe,
        'options_en': q.optionsEn,
        'options_te': q.optionsTe,
        'correct_index': q.correctIndex,
        'explanation_en': q.explanationEn,
        'explanation_te': q.explanationTe,
      }).toList(),
    };
  }

  factory DailyPortionData.fromJson(Map<String, dynamic> json) {
    final questionsRaw = json['quiz_questions'] as List? ?? [];
    final questions = questionsRaw.map((q) {
      return QuizQuestion(
        id: q['id'] is int ? q['id'] as int : int.tryParse(q['id']?.toString() ?? '1') ?? 1,
        questionEn: q['question_en']?.toString() ?? q['question']?.toString() ?? '',
        questionTe: q['question_te']?.toString() ?? q['question']?.toString() ?? '',
        optionsEn: List<String>.from(q['options_en'] ?? q['options'] ?? []),
        optionsTe: List<String>.from(q['options_te'] ?? q['options'] ?? []),
        correctIndex: q['correct_index'] is int ? q['correct_index'] as int : 0,
        explanationEn: q['explanation_en']?.toString() ?? q['explanation']?.toString() ?? '',
        explanationTe: q['explanation_te']?.toString() ?? q['explanation']?.toString() ?? '',
      );
    }).toList();

    return DailyPortionData(
      title: json['title']?.toString() ?? 'Daily Scripture Study',
      passage: json['passage']?.toString() ?? 'Genesis 31:1–55',
      bookName: json['book_name']?.toString() ?? 'Genesis',
      startChapter: json['start_chapter'] is int ? json['start_chapter'] as int : 31,
      startVerse: json['start_verse'] is int ? json['start_verse'] as int : 1,
      endChapter: json['end_chapter'] is int ? json['end_chapter'] as int : 31,
      endVerse: json['end_verse'] is int ? json['end_verse'] as int : 55,
      studyNotesEn: json['study_notes_en']?.toString() ?? '''
Genesis 31 details Jacob's departure from Laban's household, Rachel taking the household idols, God warning Laban in a dream, and the Mizpah covenant sealed between Jacob and Laban.

### Key Scripture Highlights:
1. **Divine Mandate:** God commands Jacob: "Return to the land of your fathers and to your relatives, and I will be with you."
2. **Divine Protection:** God warns Laban in a dream: "Be careful not to say anything to Jacob, either good or bad."
3. **Mizpah Covenant:** "The LORD watch between you and me when we are absent one from another."
''',
      studyNotesTe: json['study_notes_te']?.toString() ?? '''
ఆదికాండము 31వ అధ్యాయంలో యాకోబు లాబాను ఇంట నుండి బయలుదేరడం, దేవుడు స్వప్నంలో లాబానును హెచ్చరించడం మరియు వారు మిస్పా వద్ద చేసుకున్న సమాధాన ఒడంబడిక గురించి వివరించబడింది.

### ముఖ్య వాక్య ముఖ్యాంశాలు:
1. **దైవిక ఆజ్ఞ:** "నీ పితరుల దేశమునకు తిరిగి వెళ్లుము, నేను నీకు తోడైయుండెదను" అని దేవుడు యాకోబుతో చెప్పెను.
2. **దైవిక రక్షణ:** రాత్రి స్వప్నంలో దేవుడు లాబానును హెచ్చరించి యాకోబుకు ఏ హానీ చేయవద్దని ఆజ్ఞాపించెను.
3. **మిస్పా ఒడంబడిక:** "మనము ఒకరికొకరము దూరముగా ఉన్నప్పుడు యెహోవా మన ఇద్దరి మధ్య కాపలా ఉండును గాక."
''',
      quizQuestions: questions,
      publishedDate: json['published_date']?.toString() ?? DateFormat('yyyy-MM-dd').format(DateTime.now()),
    );
  }
}

class DailyStudyService {
  static DailyPortionData? _cachedPortion;

  // Stream real-time daily study & quiz questions from Firestore `daily_studies` collection
  static Stream<DailyPortionData?> streamDailyStudy(String dateStr) {
    return FirebaseFirestore.instance
        .collection('daily_studies')
        .doc(dateStr)
        .snapshots()
        .map((snap) {
      if (snap.exists && snap.data() != null) {
        return DailyPortionData.fromJson(snap.data()!);
      }
      return null;
    });
  }

  static Future<DailyPortionData> getActiveDailyPortion() async {
    if (_cachedPortion != null) return _cachedPortion!;

    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // 0. Try fetching from Cloud Firestore collection `daily_studies`
    try {
      final docSnap = await FirebaseFirestore.instance
          .collection('daily_studies')
          .doc(todayStr)
          .get();
      if (docSnap.exists && docSnap.data() != null) {
        _cachedPortion = DailyPortionData.fromJson(docSnap.data()!);
        return _cachedPortion!;
      }
    } catch (_) {}

    // 1. Try fetching from Supabase database table `daily_portions`
    try {
      final supabase = Supabase.instance.client;
      final res = await supabase
          .from('daily_portions')
          .select()
          .eq('published_date', todayStr)
          .maybeSingle();

      if (res != null) {
        _cachedPortion = DailyPortionData.fromJson(res);
        return _cachedPortion!;
      }
    } catch (_) {}

    // 2. Try fetching from SharedPreferences persistent local cache
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('custom_daily_portion');
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final Map<String, dynamic> data = jsonDecode(jsonStr);
        _cachedPortion = DailyPortionData.fromJson(data);
        return _cachedPortion!;
      }
    } catch (_) {}

    // 3. Fallback default daily portion
    _cachedPortion = DailyPortionData.fromJson({});
    return _cachedPortion!;
  }

  static Future<bool> publishDailyPortion(DailyPortionData portion) async {
    _cachedPortion = portion;
    final todayDoc = portion.publishedDate.isNotEmpty
        ? portion.publishedDate
        : DateFormat('yyyy-MM-dd').format(DateTime.now());

    // 1. Save to Cloud Firestore `daily_studies` collection
    try {
      await FirebaseFirestore.instance
          .collection('daily_studies')
          .doc(todayDoc)
          .set(portion.toJson(), SetOptions(merge: true));
    } catch (e) {
      debugPrint("[DailyStudyService] Firestore publish error: $e");
    }

    // 2. Save to SharedPreferences locally
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('custom_daily_portion', jsonEncode(portion.toJson()));
    } catch (_) {}

    // 3. Publish to Supabase table `daily_portions`
    try {
      final supabase = Supabase.instance.client;
      await supabase.from('daily_portions').upsert(portion.toJson());
    } catch (_) {}

    return true;
  }
}
