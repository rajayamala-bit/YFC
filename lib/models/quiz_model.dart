class QuizQuestion {
  final int id;
  final String questionEn;
  final String questionTe;
  final List<String> optionsEn;
  final List<String> optionsTe;
  final int correctIndex;
  final String explanationEn;
  final String explanationTe;

  QuizQuestion({
    required this.id,
    required this.questionEn,
    required this.questionTe,
    required this.optionsEn,
    required this.optionsTe,
    required this.correctIndex,
    required this.explanationEn,
    required this.explanationTe,
  });

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    return QuizQuestion(
      id: json['id'] ?? 1,
      questionEn: json['question_en'] ?? '',
      questionTe: json['question_te'] ?? '',
      optionsEn: List<String>.from(json['options_en'] ?? []),
      optionsTe: List<String>.from(json['options_te'] ?? []),
      correctIndex: json['correct_index'] ?? 0,
      explanationEn: json['explanation_en'] ?? '',
      explanationTe: json['explanation_te'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'question_en': questionEn,
      'question_te': questionTe,
      'options_en': optionsEn,
      'options_te': optionsTe,
      'correct_index': correctIndex,
      'explanation_en': explanationEn,
      'explanation_te': explanationTe,
    };
  }
}

class DailyQuiz {
  final String id;
  final String quizDate;
  final String book;
  final int chapter;
  final String verses;
  final List<QuizQuestion> questions;

  DailyQuiz({
    required this.id,
    required this.quizDate,
    required this.book,
    required this.chapter,
    required this.verses,
    required this.questions,
  });

  factory DailyQuiz.fromJson(Map<String, dynamic> json) {
    var questionsList = (json['questions'] as List? ?? [])
        .map((q) => QuizQuestion.fromJson(q as Map<String, dynamic>))
        .toList();

    return DailyQuiz(
      id: json['id'] ?? '',
      quizDate: json['quiz_date'] ?? '',
      book: json['book'] ?? '',
      chapter: json['chapter'] ?? 1,
      verses: json['verses'] ?? '',
      questions: questionsList,
    );
  }
}

class ChampionLeaderboardUser {
  final String fullName;
  final String avatarUrl;
  final int score;
  final int elapsedSeconds;
  final int rank;

  ChampionLeaderboardUser({
    required this.fullName,
    required this.avatarUrl,
    required this.score,
    required this.elapsedSeconds,
    required this.rank,
  });
}
