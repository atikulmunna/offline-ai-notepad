/// Synthesizes a short answer to a question, grounded strictly in the supplied
/// [context] assembled from the user's own notes. Implementations run fully
/// on-device and always return usable text when context is present, so an
/// answer is available even without a native model.
abstract class GroundedAnswerer {
  Future<String> answer({
    required String question,
    required String context,
  });
}
