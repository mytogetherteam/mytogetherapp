class FoodWordItem {
  final String id;
  final String name;
  final List<String> syllables;
  final List<String> distractors;
  final String category;
  final String emoji;
  final String hint;
  final String funFact;

  const FoodWordItem({
    required this.id,
    required this.name,
    required this.syllables,
    required this.distractors,
    required this.category,
    required this.emoji,
    required this.hint,
    required this.funFact,
  });
}
