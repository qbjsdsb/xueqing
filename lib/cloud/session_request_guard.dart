/// Guards asynchronous work that depends on the currently signed-in user.
///
/// A session can change while a network request is in flight. Callers start a
/// new generation when they begin a request and invalidate it on sign-out or
/// another session event. Results from an older generation must be ignored.
class SessionRequestGuard {
  int _generation = 0;

  int begin() => ++_generation;

  void invalidate() {
    _generation++;
  }

  bool isCurrent(
    int requestGeneration, {
    required String expectedUserId,
    required String? currentUserId,
  }) {
    return requestGeneration == _generation && expectedUserId == currentUserId;
  }
}
