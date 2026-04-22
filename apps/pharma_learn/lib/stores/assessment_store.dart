import 'package:injectable/injectable.dart';
import 'package:mobx/mobx.dart';

import '../repositories/assessment_repository.dart';

part 'assessment_store.g.dart';

/// Store for managing assessments.
/// Handles attempt lifecycle, timer, answers, and proctoring.
@singleton
class AssessmentStore = _AssessmentStoreBase with _$AssessmentStore;

abstract class _AssessmentStoreBase with Store {
  final AssessmentRepository _repository;
  
  _AssessmentStoreBase(this._repository);
  
  // ---------------------------------------------------------------------------
  // Observable State
  // ---------------------------------------------------------------------------
  
  @observable
  bool isLoading = false;
  
  @observable
  String? errorMessage;
  
  @observable
  ObservableList<Assessment> availableAssessments = ObservableList<Assessment>();
  
  @observable
  AssessmentAttempt? currentAttempt;
  
  @observable
  ObservableList<Question> questions = ObservableList<Question>();
  
  @observable
  int currentQuestionIndex = 0;
  
  @observable
  ObservableMap<String, dynamic> answers = ObservableMap<String, dynamic>();
  
  @observable
  int? timeRemainingSeconds;
  
  @observable
  bool isSubmitting = false;
  
  @observable
  AssessmentResult? result;
  
  // ---------------------------------------------------------------------------
  // Computed
  // ---------------------------------------------------------------------------
  
  @computed
  Question? get currentQuestion {
    if (questions.isEmpty || currentQuestionIndex >= questions.length) {
      return null;
    }
    return questions[currentQuestionIndex];
  }
  
  @computed
  int get totalQuestions => questions.length;
  
  @computed
  int get answeredQuestions => answers.length;
  
  @computed
  double get progress {
    if (totalQuestions == 0) return 0.0;
    return answeredQuestions / totalQuestions;
  }
  
  @computed
  bool get isFirstQuestion => currentQuestionIndex == 0;
  
  @computed
  bool get isLastQuestion => currentQuestionIndex == totalQuestions - 1;
  
  @computed
  bool get canSubmit => answeredQuestions > 0;
  
  @computed
  bool get isTimerExpired => timeRemainingSeconds != null && timeRemainingSeconds! <= 0;
  
  @computed
  String get formattedTimeRemaining {
    if (timeRemainingSeconds == null) return '--:--';
    final minutes = timeRemainingSeconds! ~/ 60;
    final seconds = timeRemainingSeconds! % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  
  @computed
  bool get isAttemptActive => 
      currentAttempt != null && 
      currentAttempt!.status == 'in_progress' &&
      !isTimerExpired;
  
  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------
  
  @action
  Future<void> loadAvailableAssessments() async {
    isLoading = true;
    errorMessage = null;
    
    try {
      final list = await _repository.getAvailableAssessments();
      availableAssessments = ObservableList.of(list);
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isLoading = false;
    }
  }
  
  @action
  Future<bool> startAttempt(String assessmentId) async {
    isLoading = true;
    errorMessage = null;
    
    try {
      currentAttempt = await _repository.startAttempt(assessmentId);
      
      // Load questions for this attempt
      final questionList = await _repository.getQuestions(currentAttempt!.id);
      questions = ObservableList.of(questionList);
      
      // Calculate time remaining from attempt end time
      if (currentAttempt!.endsAt != null) {
        final remaining = currentAttempt!.endsAt!.difference(DateTime.now());
        timeRemainingSeconds = remaining.inSeconds > 0 ? remaining.inSeconds : 0;
      }
      
      currentQuestionIndex = 0;
      answers.clear();
      
      return true;
    } catch (e) {
      errorMessage = e.toString();
      return false;
    } finally {
      isLoading = false;
    }
  }
  
  @action
  void goToQuestion(int index) {
    if (index >= 0 && index < totalQuestions) {
      currentQuestionIndex = index;
    }
  }
  
  @action
  void nextQuestion() {
    if (!isLastQuestion) {
      currentQuestionIndex++;
    }
  }
  
  @action
  void previousQuestion() {
    if (!isFirstQuestion) {
      currentQuestionIndex--;
    }
  }
  
  @action
  Future<void> saveAnswer(String questionId, dynamic answer) async {
    answers[questionId] = answer;
    
    // Persist to server
    if (currentAttempt != null) {
      try {
        await _repository.submitAnswer(currentAttempt!.id, questionId, answer);
      } catch (e) {
        // Log but don't fail - answer is saved locally
        print('Failed to sync answer: $e');
      }
    }
  }
  
  @action
  void updateTimer(int seconds) {
    timeRemainingSeconds = seconds;
  }
  
  @action
  void decrementTimer() {
    if (timeRemainingSeconds != null && timeRemainingSeconds! > 0) {
      timeRemainingSeconds = timeRemainingSeconds! - 1;
    }
  }
  
  @action
  Future<bool> submitAssessment({
    required String esigPassword,
    required String meaning,
  }) async {
    if (currentAttempt == null) return false;
    
    isSubmitting = true;
    errorMessage = null;
    
    try {
      result = await _repository.submitAssessment(
        currentAttempt!.id,
        esigPassword: esigPassword,
        meaning: meaning,
      );
      
      currentAttempt = null;
      return true;
    } catch (e) {
      errorMessage = e.toString();
      return false;
    } finally {
      isSubmitting = false;
    }
  }
  
  @action
  Future<void> loadResult(String attemptId) async {
    isLoading = true;
    errorMessage = null;
    
    try {
      result = await _repository.getResult(attemptId);
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isLoading = false;
    }
  }
  
  @action
  void reset() {
    currentAttempt = null;
    questions.clear();
    answers.clear();
    currentQuestionIndex = 0;
    timeRemainingSeconds = null;
    result = null;
    errorMessage = null;
  }
  
  @action
  void clearError() {
    errorMessage = null;
  }
}
