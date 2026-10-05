import '../../discovery_planning/models/heritage_place.dart';

class GuideContent {
  const GuideContent({
    required this.overview,
    required this.history,
    required this.significance,
    required this.highlights,
  });
  final String overview, history, significance;
  final List<String> highlights;
  static const visitorTips = [
    'Respect local customs',
    'Follow site signage',
    'Carry drinking water where appropriate',
    'Keep heritage areas clean',
  ];
  factory GuideContent.forPlace(HeritagePlace place) {
    final history = switch (place.id) {
      'sigiriya' => 'Sigiriya preserves the remains of a historic rock-top fortress and landscaped gardens.',
      'tooth-temple' => 'Kandy was a royal capital. The Temple of the Sacred Tooth Relic is an important Buddhist cultural site in the city.',
      'galle-fort' => 'Galle Fort reflects the colonial history of Sri Lanka through its fortifications and historic streets.',
      'dambulla' => 'The Dambulla cave-temple complex preserves Buddhist murals and statues.',
      'polonnaruwa' => 'Polonnaruwa was a capital of Sri Lanka. Its archaeological remains include ancient buildings and religious monuments.',
      'anuradhapura' => 'Anuradhapura was an ancient capital and remains a sacred city with Buddhist monuments.',
      _ => place.description,
    };
    final significance = switch (place.category) {
      'Forts' => 'Fortifications and surviving structures help visitors explore the architectural character of this heritage site.',
      'Temples' => 'Religious art and architecture are part of the cultural significance of this site.',
      'Ancient Cities' => 'Archaeological remains provide an introduction to the built heritage of an ancient city.',
      _ => place.description,
    };
    return GuideContent(
      overview: place.description,
      history: history,
      significance: significance,
      highlights: [
        place.category,
        'Architectural character',
        'Cultural significance',
      ],
    );
  }
}
