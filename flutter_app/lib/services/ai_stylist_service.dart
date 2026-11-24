import '../logic/outfit_matcher.dart';
import '../models/wardrobe.dart';
import '../state/wardrobe_store.dart';

/// Structured user intent extracted from conversational text.
class StylistIntent {
  const StylistIntent({
    required this.rawQuery,
    this.occasion,
    this.rawOccasion,
    this.targetFormality = 3,
    this.preferredColors = const [],
    this.preferredCategories = const [],
    this.preferredTone,
    this.preferNewest = false,
  });

  final String rawQuery;
  final String? occasion;
  final String? rawOccasion;
  final int targetFormality;
  final List<String> preferredColors;
  final List<String> preferredCategories;
  final String? preferredTone; // 'cerah', 'gelap', 'netral'
  final bool preferNewest;
}

/// An outfit recommendation assembled by the AI Stylist.
class StylistOutfitOption {
  const StylistOutfitOption({
    required this.title,
    required this.items,
    required this.matchScore,
    required this.stylingReason,
    this.styleTag = 'Kasual',
    this.tips = const [],
  });

  final String title;
  final List<WardrobeItem> items;
  final int matchScore; // 0..100
  final String stylingReason;
  final String styleTag;
  final List<String> tips;
}

/// Complete response from the AI Stylist.
class StylistResponse {
  const StylistResponse({
    required this.message,
    required this.intent,
    this.options = const [],
    this.generalAdvice,
    this.followUpPrompts = const [],
  });

  final String message;
  final StylistIntent intent;
  final List<StylistOutfitOption> options;
  final String? generalAdvice;
  final List<String> followUpPrompts;
}

/// On-device intelligent Stylist service that parses user language and
/// matches garments from the user's wardrobe.
class AiStylistService {
  const AiStylistService();

  /// Parse the user's natural language query into intent attributes.
  StylistIntent parseIntent(String query) {
    final lower = query.toLowerCase();

    String? occasion;
    String? rawOccasion;
    int targetFormality = 3;

    // 1. Detect Occasion & Formality
    // Semi-Formal / Smart-Casual
    if (_containsAny(lower, [
      'kondangan malam',
      'wisuda',
      'graduation',
      'kondangan',
      'lamaran',
      'engagement',
      'resepsi',
      'pesta',
      'party',
      'wedding',
      'nikahan',
      'dinner',
      'gala',
      'prom',
      'smart-casual',
      'smart casual',
    ])) {
      occasion = 'Smart-Casual';
      if (lower.contains('kondangan malam')) {
        rawOccasion = 'kondangan malam';
      } else if (lower.contains('smart-casual') || lower.contains('smart casual')) {
        rawOccasion = 'tampilan smart-casual';
      } else {
        rawOccasion = _matchedKeyword(lower, [
          'wisuda',
          'kondangan',
          'lamaran',
          'resepsi',
          'pesta',
          'wedding',
        ]) ?? 'wisuda';
      }
      targetFormality = (lower.contains('smart') && !lower.contains('kondangan')) ? 3 : 4;
    }
    // Formal
    else if (_containsAny(lower, [
      'sidang & interview',
      'interview',
      'wawancara',
      'sidang',
      'kantor',
      'office',
      'meeting',
      'rapat',
      'kerja',
      'work',
      'formal',
      'presentasi',
      'presentation',
      'seminar',
      'konferensi',
    ])) {
      occasion = 'Formal';
      if (lower.contains('sidang') && lower.contains('interview')) {
        rawOccasion = 'sidang & interview';
      } else {
        rawOccasion = _matchedKeyword(lower, [
          'interview',
          'sidang',
          'kantor',
          'meeting',
          'presentasi',
          'kerja',
        ]) ?? 'kantor';
      }
      targetFormality = 5;
    }
    // Sporty
    else if (_containsAny(lower, [
      'olahraga / gym',
      'olahraga',
      'sport',
      'lari',
      'running',
      'gym',
      'workout',
      'jogging',
      'fitness',
      'sepeda',
      'cycling',
      'badminton',
      'futsal',
    ])) {
      occasion = 'Sport';
      rawOccasion = lower.contains('gym')
          ? 'olahraga / gym'
          : (_matchedKeyword(lower, [
              'olahraga',
              'lari',
              'gym',
              'workout',
              'jogging',
            ]) ?? 'olahraga');
      targetFormality = 1;
    }
    // Kasual (Default / Casual)
    else if (_containsAny(lower, [
      'kafe',
      'cafe',
      'nongkrong di kafe',
      'nongkrong kafe',
      'ngampus',
      'kuliah',
      'campus',
      'college',
      'nongkrong',
      'hangout',
      'jalan',
      'santai',
      'chill',
      'casual',
      'kasual',
      'harian',
      'daily',
      'kencan',
      'date',
      'mall',
      'ngopi',
    ])) {
      occasion = 'Kasual';
      if (lower.contains('kafe') || lower.contains('cafe')) {
        rawOccasion = 'nongkrong di kafe';
      } else {
        rawOccasion = _matchedKeyword(lower, [
          'ngampus',
          'kuliah',
          'nongkrong',
          'santai',
          'kencan',
          'jalan',
        ]) ?? 'kasual';
      }
      targetFormality = 2;
    } else {
      // General inquiry
      occasion = 'Kasual';
      rawOccasion = 'santai';
      targetFormality = 3;
    }

    final preferNewest = lower.contains('terbaru') || lower.contains('terbaruku');

    // 2. Detect Preferred Colors
    final preferredColors = <String>[];
    if (lower.contains('hitam') || lower.contains('black')) {
      preferredColors.add('Hitam');
    }
    if (lower.contains('putih') || lower.contains('white')) {
      preferredColors.add('Putih');
    }
    if (lower.contains('navy') || lower.contains('biru') || lower.contains('blue')) {
      preferredColors.add('Biru');
    }
    if (lower.contains('merah') || lower.contains('red') || lower.contains('maroon')) {
      preferredColors.add('Merah');
    }
    if (lower.contains('pink') || lower.contains('merah muda')) {
      preferredColors.add('Pink');
    }
    if (lower.contains('hijau') || lower.contains('green') || lower.contains('sage') || lower.contains('olive')) {
      preferredColors.add('Hijau');
    }
    if (lower.contains('kuning') || lower.contains('yellow') || lower.contains('mustard')) {
      preferredColors.add('Kuning');
    }
    if (lower.contains('abu') || lower.contains('grey') || lower.contains('gray')) {
      preferredColors.add('Abu-abu');
    }
    if (lower.contains('cokelat') || lower.contains('brown') || lower.contains('krem') || lower.contains('beige') || lower.contains('tan')) {
      preferredColors.add('Cokelat');
    }

    String? tone;
    if (lower.contains('netral') || lower.contains('neutral')) {
      tone = 'netral';
    } else if (lower.contains('cerah') || lower.contains('bright')) {
      tone = 'cerah';
    } else if (lower.contains('gelap') || lower.contains('dark')) {
      tone = 'gelap';
    }

    // 3. Detect Preferred Categories
    final preferredCategories = <String>[];
    if (_containsAny(lower, ['kemeja', 'kaos', 't-shirt', 'shirt', 'blouse', 'polo', 'baju', 'atasan'])) {
      preferredCategories.add('Tops');
    }
    if (_containsAny(lower, ['celana', 'jeans', 'chinos', 'rok', 'kulot', 'trousers', 'pants', 'skirt', 'bawahan'])) {
      preferredCategories.add('Bottoms');
    }
    if (_containsAny(lower, ['jaket', 'blazer', 'cardigan', 'hoodie', 'outer', 'jas', 'jacket', 'coat'])) {
      preferredCategories.add('Outerwear');
    }
    if (_containsAny(lower, ['sepatu', 'sneakers', 'loafers', 'heels', 'boots', 'sandals', 'pantofel', 'shoes', 'sepatu santai'])) {
      preferredCategories.add('Footwear');
    }
    if (_containsAny(lower, ['topi', 'dasi', 'tas', 'bag', 'belt', 'ikat pinggang', 'jam', 'watch'])) {
      preferredCategories.add('Accessories');
    }

    return StylistIntent(
      rawQuery: query,
      occasion: occasion,
      rawOccasion: rawOccasion,
      targetFormality: targetFormality,
      preferredColors: preferredColors,
      preferredCategories: preferredCategories,
      preferredTone: tone,
      preferNewest: preferNewest,
    );
  }

  /// Process query and generate outfit recommendations based on the user's wardrobe.
  Future<StylistResponse> recommend({
    required String query,
    List<WardrobeItem>? wardrobe,
  }) async {
    final intent = parseIntent(query);
    final items = wardrobe ?? wardrobeItems.value;

    final tops = items.where((i) => i.category == 'Tops').toList();
    final bottoms = items.where((i) => i.category == 'Bottoms').toList();
    final outerwear = items.where((i) => i.category == 'Outerwear').toList();
    final footwear = items.where((i) => i.category == 'Footwear').toList();
    final accessories = items.where((i) => i.category == 'Accessories').toList();

    // If wardrobe doesn't have sufficient items for a full outfit, provide fallback advice
    if (tops.isEmpty || bottoms.isEmpty) {
      return _buildFallbackResponse(intent, items);
    }

    // Assemble outfit combinations
    final combinations = <StylistOutfitOption>[];

    // Score and pair Tops & Bottoms
    for (final top in tops) {
      for (final bottom in bottoms) {
        final pairScore = pairSubscores(
          top,
          bottom,
          occasion: intent.occasion ?? 'Kasual',
        );

        // Calculate combined score
        double score = (pairScore.color * 0.40) +
            (pairScore.formality * 0.35) +
            (pairScore.occasion * 0.25);

        // Bonus if matches target formality
        final topFormalityGap = (top.formality - intent.targetFormality).abs();
        final bottomFormalityGap = (bottom.formality - intent.targetFormality).abs();
        final avgFormalityGap = (topFormalityGap + bottomFormalityGap) / 2.0;
        if (avgFormalityGap <= 1.0) {
          score += 0.08;
        }

        // Bonus if matches preferred colors
        if (intent.preferredColors.isNotEmpty) {
          final topColorMatch = intent.preferredColors.any(
            (c) => top.colorName.toLowerCase().contains(c.toLowerCase()),
          );
          final bottomColorMatch = intent.preferredColors.any(
            (c) => bottom.colorName.toLowerCase().contains(c.toLowerCase()),
          );
          if (topColorMatch || bottomColorMatch) {
            score += 0.10;
          }
        }

        // Bonus if matches preferred tone
        if (intent.preferredTone == 'netral' && (isNeutral(top.color) || isNeutral(bottom.color))) {
          score += 0.05;
        }

        // Bonus if prefer newest
        if (intent.preferNewest && (tops.indexOf(top) <= 1 || bottoms.indexOf(bottom) <= 1)) {
          score += 0.12;
        }

        final normalizedScore = (score.clamp(0.0, 1.0) * 100).round();
        if (normalizedScore < 50) continue;

        // Try adding complementary Footwear / Outerwear
        final outfitItems = <WardrobeItem>[top, bottom];

        // Add matching footwear if available
        if (footwear.isNotEmpty) {
          final bestShoe = footwear.reduce((a, b) {
            final aGap = (a.formality - intent.targetFormality).abs();
            final bGap = (b.formality - intent.targetFormality).abs();
            return aGap <= bGap ? a : b;
          });
          outfitItems.add(bestShoe);
        }

        // Add matching outerwear if formal/semi-formal and available
        if ((intent.targetFormality >= 3) && outerwear.isNotEmpty) {
          final matchingOuter = outerwear.firstWhere(
            (o) => (o.formality - intent.targetFormality).abs() <= 1,
            orElse: () => outerwear.first,
          );
          if (!outfitItems.contains(matchingOuter)) {
            outfitItems.add(matchingOuter);
          }
        } else if (accessories.isNotEmpty && outfitItems.length < 4) {
          outfitItems.add(accessories.first);
        }

        // Generate styling justification
        final colorHarmony = harmonyOf(top.color, bottom.color);
        final reason = _generateStylingReason(
          top: top,
          bottom: bottom,
          harmony: colorHarmony,
          occasion: intent.occasion ?? 'Kasual',
          targetFormality: intent.targetFormality,
        );

        final tips = _generateTips(
          top: top,
          bottom: bottom,
          occasion: intent.occasion ?? 'Kasual',
        );

        combinations.add(
          StylistOutfitOption(
            title: _generateOptionTitle(combinations.length + 1, intent.occasion ?? 'Kasual', top, bottom),
            items: outfitItems,
            matchScore: normalizedScore,
            stylingReason: reason,
            styleTag: intent.occasion ?? 'Kasual',
            tips: tips,
          ),
        );
      }
    }

    // Sort by match score descending
    combinations.sort((a, b) => b.matchScore.compareTo(a.matchScore));

    // Pick top 2 or 3 distinct options
    final selectedOptions = <StylistOutfitOption>[];
    final seenTopIds = <String>{};
    for (final opt in combinations) {
      final topId = opt.items.first.id;
      if (!seenTopIds.contains(topId) || selectedOptions.length < 2) {
        selectedOptions.add(opt);
        seenTopIds.add(topId);
      }
      if (selectedOptions.length >= 3) break;
    }

    if (selectedOptions.isEmpty) {
      return _buildFallbackResponse(intent, items);
    }

    final message = _buildStylistIntro(intent, selectedOptions.length);
    final followUpPrompts = _generateFollowUps(intent);

    return StylistResponse(
      message: message,
      intent: intent,
      options: selectedOptions,
      followUpPrompts: followUpPrompts,
    );
  }

  StylistResponse _buildFallbackResponse(
    StylistIntent intent,
    List<WardrobeItem> items,
  ) {
    final occasionLabel = intent.rawOccasion ?? 'acara kamu';
    final String advice;
    if (intent.occasion == 'Smart-Casual' || intent.targetFormality == 4) {
      advice =
          'Untuk acara semi-formal seperti $occasionLabel, paduan ideal adalah kemeja katun polos berkerah rapi (warna putih, biru muda, atau navy) dipadukan dengan celana chino atau celana bahan berpotongan slim-fit. Tambahkan sepatu loafers atau dress shoes untuk sentuhan elegan.';
    } else if (intent.occasion == 'Formal' || intent.targetFormality == 5) {
      advice =
          'Untuk acara formal seperti $occasionLabel, gunakan kemeja berkerah kaku dipadukan dengan celana bahan hitam/charcoal, jas atau blazer, serta sepatu pantofel atau oxfords gelap yang bersih.';
    } else if (intent.occasion == 'Sport') {
      advice =
          'Untuk $occasionLabel, pilih pakaian berbahan breathable jersey atau dri-fit dengan celana training/jogger dan sepatu running yang memiliki bantalan empuk.';
    } else {
      advice =
          'Untuk gaya kasual santai seperti $occasionLabel, kaos polos berkualitas atau polo shirt dipadukan dengan celana jeans atau chinos pendek/panjang serta sneakers bersih akan memberikan kesan effortless stylish.';
    }

    final hasSomeItems = items.isNotEmpty;
    final message = hasSomeItems
        ? 'Lemarimu saat ini belum memiliki pasangan Atasan dan Bawahan yang cukup untuk merakit padu padan lengkap untuk $occasionLabel. Berikut panduan gaya rekomendasi dari Stylist:'
        : 'Lemarimu masih kosong! Unggah atau scan beberapa pakaian terlebih dahulu agar aku bisa mencocokkan outfit langsung dari koleksimu. Sebagai panduan awal untuk $occasionLabel:';

    return StylistResponse(
      message: message,
      intent: intent,
      options: const [],
      generalAdvice: advice,
      followUpPrompts: [
        'Rekomendasi warna netral',
        'Gaya kasual santai',
        'Pakaian untuk presentasi',
      ],
    );
  }

  String _buildStylistIntro(StylistIntent intent, int optionCount) {
    if (intent.preferNewest) {
      return 'Kombinasi padu padan terbaik menggunakan koleksi pakaian terbarumu dari lemari:';
    }
    if (intent.rawQuery.toLowerCase().contains('sepatu santai')) {
      return 'Paduan outfit kasual yang pas dipadukan dengan sepatu santai koleksimu:';
    }

    final occasionName = intent.rawOccasion ?? 'acara kamu';
    final occasionTag = intent.occasion ?? 'Kasual';

    if (intent.targetFormality >= 4) {
      return 'Untuk $occasionName, gaya $occasionTag paling pas agar kamu tampil rapi, percaya diri, dan berkelas. Aku menemukan $optionCount kombinasi terbaik langsung dari lemarimu:';
    } else if (intent.occasion == 'Sport') {
      return 'Untuk aktivitas $occasionName, kenyamanan gerak dan bahan breathable adalah prioritas utama. Ini paduan outfit sporty yang cocok dari lemarimu:';
    } else {
      return 'Pilihan santai tapi tetap modis untuk $occasionName! Berikut $optionCount rekomendasi padu padan seimbang dari lemarimu:';
    }
  }

  String _generateOptionTitle(
    int index,
    String occasion,
    WardrobeItem top,
    WardrobeItem bottom,
  ) {
    if (occasion == 'Smart-Casual') {
      return 'Opsi $index: Setelan Semi-Formal Elegan';
    } else if (occasion == 'Formal') {
      return 'Opsi $index: Setelan Formal Profesional';
    } else if (occasion == 'Sport') {
      return 'Opsi $index: Setelan Sporty Aktif';
    }
    return 'Opsi $index: Paduan Kasual Rapi';
  }

  String _generateStylingReason({
    required WardrobeItem top,
    required WardrobeItem bottom,
    required ColorHarmony harmony,
    required String occasion,
    required int targetFormality,
  }) {
    final harmonyDesc = switch (harmony) {
      ColorHarmony.netral => 'Harmoni warna netral yang bersih dan mudah dipadukan.',
      ColorHarmony.analog => 'Kombinasi warna analog yang senada dan memberikan kesan harmonis lembut.',
      ColorHarmony.komplementer => 'Paduan warna komplementer yang kontras berimbang dan menarik visual.',
      ColorHarmony.triadic => 'Kombinasi dinamis yang seimbang dan segar.',
      ColorHarmony.kontras => 'Sentuhan warna berani yang memberi daya tarik tersendiri.',
    };

    final formalityGap = (top.formality - bottom.formality).abs();
    final formalityDesc = formalityGap <= 1
        ? 'Tingkat formalitas ${top.name} dan ${bottom.name} sangat seimbang.'
        : 'Paduan kasual-smart yang fleksibel dipakai beraktivitas.';

    return '$harmonyDesc $formalityDesc';
  }

  List<String> _generateTips({
    required WardrobeItem top,
    required WardrobeItem bottom,
    required String occasion,
  }) {
    final list = <String>[];
    if (top.category == 'Tops' && top.name.toLowerCase().contains('kemeja')) {
      list.add('Masukkan kemeja ke dalam celana untuk tampilan lebih rapi.');
    }
    if (occasion == 'Smart-Casual' || occasion == 'Formal') {
      list.add('Gunakan ikat pinggang berwarna senada dengan sepatu.');
    } else {
      list.add('Gulung sedikit ujung lengan atau celana untuk gaya santai.');
    }
    return list;
  }

  List<String> _generateFollowUps(StylistIntent intent) {
    final occasion = intent.occasion ?? 'Kasual';
    if (occasion == 'Smart-Casual' || occasion == 'Formal') {
      return [
        'Ingin opsi warna lebih netral',
        'Rekomendasi sepatu yang cocok',
        'Gaya yang sedikit lebih santai',
      ];
    } else if (occasion == 'Sport') {
      return [
        'Rekomendasi sepatu olahraga',
        'Ganti warna lebih gelap',
        'Opsi outfit untuk gym',
      ];
    } else {
      return [
        'Cari paduan yang lebih formal',
        'Pilihan warna pastel / cerah',
        'Tambahkan jaket atau luaran',
      ];
    }
  }

  bool _containsAny(String text, List<String> keywords) {
    for (final kw in keywords) {
      if (text.contains(kw)) return true;
    }
    return false;
  }

  String? _matchedKeyword(String text, List<String> keywords) {
    for (final kw in keywords) {
      if (text.contains(kw)) return kw;
    }
    return null;
  }
}

/// Global singleton instance of AI Stylist Service.
const aiStylistService = AiStylistService();

