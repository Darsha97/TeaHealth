import '../core/localization/app_localizations.dart';

/// Disease treatment recommendations database
class DiseaseTreatment {
  final String disease;
  final List<String> treatments;

  const DiseaseTreatment({
    required this.disease,
    required this.treatments,
  });
}

/// Localized disease treatment
class LocalizedDiseaseTreatment {
  final String disease;
  final List<String> treatments;

  LocalizedDiseaseTreatment({
    required this.disease,
    required this.treatments,
  });
}

class DiseasesTreatmentsDB {
  static final Map<String, DiseaseTreatment> _treatments = {
    // Diseases
    'black blight': DiseaseTreatment(
      disease: 'Black Blight',
      treatments: [
        'Remove and destroy infected leaves and branches',
        'Apply copper-based fungicides (Copper oxychloride at 0.5%)',
        'Improve air circulation by proper pruning',
        'Avoid overhead irrigation',
      ],
    ),
    'blister blight': DiseaseTreatment(
      disease: 'Blister Blight',
      treatments: [
        'Apply copper fungicides (Copper oxychloride 50% WP at 4-5 g/L)',
        'Spray systemic fungicides like Hexaconazole or Propiconazole',
        'Remove infected leaves immediately',
        'Apply fungicides every 7-10 days during wet season',
      ],
    ),
    'brown blight': DiseaseTreatment(
      disease: 'Brown Blight',
      treatments: [
        'Use copper-based fungicides',
        'Improve drainage to reduce moisture',
        'Prune infected parts',
        'Apply Mancozeb or Zineb fungicides',
      ],
    ),
    'grey blight': DiseaseTreatment(
      disease: 'Grey Blight',
      treatments: [
        'Apply systemic fungicides',
        'Remove infected plant parts',
        'Ensure proper spacing for air circulation',
        'Use copper fungicides preventively',
      ],
    ),
    'lichen': DiseaseTreatment(
      disease: 'Lichen',
      treatments: [
        'Usually indicates poor plant vigor',
        'Apply lime sulfur solution',
        'Improve plant nutrition and health',
        'Manual removal by brushing',
        'Prune to increase light penetration',
      ],
    ),
    'red rust': DiseaseTreatment(
      disease: 'Red Rust',
      treatments: [
        'Apply copper-based fungicides',
        'Spray Bordeaux mixture (1%)',
        'Improve air circulation',
        'Reduce humidity around plants',
      ],
    ),
    'mites': DiseaseTreatment(
      disease: 'Mites',
      treatments: [
        'Apply acaricides (Propargite, Fenpyroximate)',
        'Use neem oil as organic alternative',
        'Introduce predatory mites',
        'Spray water to dislodge mites',
      ],
    ),
    'mita': DiseaseTreatment(
      disease: 'Mites',
      treatments: [
        'Apply acaricides (Propargite, Fenpyroximate)',
        'Use neem oil as organic alternative',
        'Introduce predatory mites',
        'Spray water to dislodge mites',
      ],
    ),
    'sunburn': DiseaseTreatment(
      disease: 'Sunburn',
      treatments: [
        'Provide shade netting (30-50% shade)',
        'Plant shade trees',
        'Ensure adequate irrigation during hot periods',
        'Apply mulch to retain soil moisture',
        'No chemical treatment needed',
      ],
    ),
    
    // Nutrient Deficiencies
    'nitrogen': DiseaseTreatment(
      disease: 'Nitrogen Deficiency',
      treatments: [
        'Apply urea (45-46% N) at 50-100 kg/ha',
        'Use ammonium sulfate (21% N)',
        'Apply in split doses (3-4 times per year)',
        'Organic: Add compost or green manure',
      ],
    ),
    'nitrogen deficiency': DiseaseTreatment(
      disease: 'Nitrogen Deficiency',
      treatments: [
        'Apply urea (45-46% N) at 50-100 kg/ha',
        'Use ammonium sulfate (21% N)',
        'Apply in split doses (3-4 times per year)',
        'Organic: Add compost or green manure',
      ],
    ),
    'potassium': DiseaseTreatment(
      disease: 'Potassium Deficiency',
      treatments: [
        'Apply Muriate of Potash (KCl) at 40-60 kg/ha',
        'Use Sulfate of Potash for better quality',
        'Apply 2-3 times annually',
        'Organic: Wood ash, banana peels compost',
      ],
    ),
    'potassium deficiency': DiseaseTreatment(
      disease: 'Potassium Deficiency',
      treatments: [
        'Apply Muriate of Potash (KCl) at 40-60 kg/ha',
        'Use Sulfate of Potash for better quality',
        'Apply 2-3 times annually',
        'Organic: Wood ash, banana peels compost',
      ],
    ),
    'magnesium': DiseaseTreatment(
      disease: 'Magnesium Deficiency',
      treatments: [
        'Apply Magnesium sulfate (Epsom salt) at 25-50 kg/ha',
        'Foliar spray: 2% Magnesium sulfate solution',
        'Apply Dolomite lime (contains Mg and Ca)',
        'Repeat every 3-4 months if needed',
      ],
    ),
    'magnesium deficiency': DiseaseTreatment(
      disease: 'Magnesium Deficiency',
      treatments: [
        'Apply Magnesium sulfate (Epsom salt) at 25-50 kg/ha',
        'Foliar spray: 2% Magnesium sulfate solution',
        'Apply Dolomite lime (contains Mg and Ca)',
        'Repeat every 3-4 months if needed',
      ],
    ),
    'sulfur': DiseaseTreatment(
      disease: 'Sulfur Deficiency',
      treatments: [
        'Apply Ammonium sulfate (24% S)',
        'Use Gypsum (18% S)',
        'Apply elemental sulfur at 20-30 kg/ha',
        'Potassium sulfate also provides sulfur',
      ],
    ),
    'sulfur deficiency': DiseaseTreatment(
      disease: 'Sulfur Deficiency',
      treatments: [
        'Apply Ammonium sulfate (24% S)',
        'Use Gypsum (18% S)',
        'Apply elemental sulfur at 20-30 kg/ha',
        'Potassium sulfate also provides sulfur',
      ],
    ),
    
    // Healthy case
    'healthy': DiseaseTreatment(
      disease: 'Healthy Tea Plant',
      treatments: [
        'Continue regular monitoring',
        'Maintain proper nutrition and irrigation',
        'Practice preventive measures',
        'Keep good air circulation through pruning',
      ],
    ),
    'healthy / no visible disease': DiseaseTreatment(
      disease: 'Healthy Tea Plant',
      treatments: [
        'Continue regular monitoring',
        'Maintain proper nutrition and irrigation',
        'Practice preventive measures',
        'Keep good air circulation through pruning',
      ],
    ),
  };

  /// Get treatment for a disease label
  /// Returns null if disease not found
  static DiseaseTreatment? getTreatment(String label) {
    final normalizedLabel = label.toLowerCase().trim();
    
    // Try exact match first
    if (_treatments.containsKey(normalizedLabel)) {
      return _treatments[normalizedLabel];
    }
    
    // Try partial matches for diseases with multiple words
    for (final entry in _treatments.entries) {
      if (normalizedLabel.contains(entry.key) || entry.key.contains(normalizedLabel)) {
        return entry.value;
      }
    }
    
    // Try matching individual words
    final words = normalizedLabel.split(RegExp(r'[\s,]+'));
    for (final word in words) {
      if (word.length > 3 && _treatments.containsKey(word)) {
        return _treatments[word];
      }
    }
    
    return null;
  }

  /// Get formatted treatment text
  static String getTreatmentText(String label) {
    final treatment = getTreatment(label);
    
    if (treatment == null) {
      return 'Treatment information not available for this condition. Please consult with a tea cultivation expert.';
    }
    
    final buffer = StringBuffer();
    buffer.writeln('**${treatment.disease}**\n');
    
    for (int i = 0; i < treatment.treatments.length; i++) {
      buffer.writeln('${i + 1}. ${treatment.treatments[i]}');
    }
    
    return buffer.toString();
  }

  /// Get all available diseases
  static List<String> getAllDiseases() {
    return _treatments.keys.toList();
  }

  /// Map disease label to localization key
  static String _getDiseaseKey(String label) {
    final normalized = label.toLowerCase().trim();
    
    // Direct mappings
    final mappings = {
      'black blight': 'blackBlight',
      'blister blight': 'blisterBlight',
      'brown blight': 'brownBlight',
      'grey blight': 'greyBlight',
      'lichen': 'lichen',
      'red rust': 'redRust',
      'mites': 'mites',
      'mita': 'mites', // Alternative spelling
      'sunburn': 'sunburn',
      'nitrogen': 'nitrogenDeficiency',
      'nitrogen deficiency': 'nitrogenDeficiency',
      'potassium': 'potassiumDeficiency',
      'potassium deficiency': 'potassiumDeficiency',
      'magnesium': 'magnesiumDeficiency',
      'magnesium deficiency': 'magnesiumDeficiency',
      'sulfur': 'sulfurDeficiency',
      'sulfur deficiency': 'sulfurDeficiency',
      'healthy': 'healthy',
      'healthy / no visible disease': 'healthy',
    };
    
    // Try exact match
    if (mappings.containsKey(normalized)) {
      return mappings[normalized]!;
    }
    
    // Try partial matches
    for (final entry in mappings.entries) {
      if (normalized.contains(entry.key) || entry.key.contains(normalized)) {
        return entry.value;
      }
    }
    
    // Try individual words
    final words = normalized.split(RegExp(r'[\s,]+'));
    for (final word in words) {
      if (word.length > 3 && mappings.containsKey(word)) {
        return mappings[word]!;
      }
    }
    
    return '';
  }

  /// Get localized treatment for a disease label
  /// Returns null if disease not found or localizations not available
  static LocalizedDiseaseTreatment? getLocalizedTreatment(
    String label,
    AppLocalizations? localizations,
  ) {
    if (localizations == null) return null;
    
    final diseaseKey = _getDiseaseKey(label);
    if (diseaseKey.isEmpty) return null;
    
    // Get disease name
    final diseaseNameKey = 'disease_$diseaseKey';
    final diseaseName = localizations.translate(diseaseNameKey);
    if (diseaseName == diseaseNameKey) return null; // Key not found
    
    // Get treatments
    final treatments = <String>[];
    int treatmentNum = 1;
    while (true) {
      final treatmentKey = 'treatment_${diseaseKey}_$treatmentNum';
      final treatment = localizations.translate(treatmentKey);
      if (treatment == treatmentKey) break; // No more treatments
      treatments.add(treatment);
      treatmentNum++;
    }
    
    if (treatments.isEmpty) return null;
    
    return LocalizedDiseaseTreatment(
      disease: diseaseName,
      treatments: treatments,
    );
  }

  /// Get formatted localized treatment text
  static String getLocalizedTreatmentText(
    String label,
    AppLocalizations? localizations,
  ) {
    final treatment = getLocalizedTreatment(label, localizations);
    
    if (treatment == null) {
      return localizations?.translate('treatmentNotAvailable') ?? 
             'Treatment information not available for this condition. Please consult with a tea cultivation expert or use the "Ask More Questions" feature for detailed advice.';
    }
    
    final buffer = StringBuffer();
    buffer.writeln('**${treatment.disease}**\n');
    
    for (int i = 0; i < treatment.treatments.length; i++) {
      buffer.writeln('${i + 1}. ${treatment.treatments[i]}');
    }
    
    return buffer.toString();
  }
}

