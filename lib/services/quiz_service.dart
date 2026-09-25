import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class QuizScoreModel {
  final String id;
  final String memberId;
  final String memberName;
  final int score;
  final int total;
  final String date;
  final DateTime completedAt;

  QuizScoreModel({
    required this.id,
    required this.memberId,
    required this.memberName,
    required this.score,
    required this.total,
    required this.date,
    required this.completedAt,
  });
}

class QuizService {
  static final QuizService _instance = QuizService._internal();
  factory QuizService() => _instance;
  QuizService._internal();

  // Write quiz completion score to Firestore `quiz_scores` collection
  Future<void> saveQuizScore({
    required int finalScore,
    required int totalQuestions,
    required String currentMemberName,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);

    await FirebaseFirestore.instance.collection('quiz_scores').add({
      'memberId': user?.uid,
      'memberName': currentMemberName,
      'score': finalScore,
      'total': totalQuestions,
      'completedAt': FieldValue.serverTimestamp(),
      'date': todayStr,
    });
  }

  // Stream today's quiz scores ordered by score descending
  Stream<QuerySnapshot> streamTodayLeaderboard() {
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    return FirebaseFirestore.instance
        .collection('quiz_scores')
        .where('date', isEqualTo: todayStr)
        .orderBy('score', descending: true)
        .snapshots();
  }
}
