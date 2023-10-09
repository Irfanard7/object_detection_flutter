/// Represents the recognition output from the model
class Recognition {
  final String result;

  const Recognition({required this.result});

  @override
  String toString() {
    return result;
  }
}
