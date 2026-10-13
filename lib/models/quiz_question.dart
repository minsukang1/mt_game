class QuizQuestion {
  final String category;
  final String question;
  final String answer;

  QuizQuestion.fromJson(Map<String, dynamic> j)
      : category = j['category'] as String,
        question = j['question'] as String,
        answer = j['answer'] as String;
}