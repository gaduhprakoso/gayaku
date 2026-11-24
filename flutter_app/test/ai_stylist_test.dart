import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/models/wardrobe.dart';
import 'package:flutter_app/screens/ai_stylist_chat_screen.dart';
import 'package:flutter_app/screens/home_screen.dart';
import 'package:flutter_app/services/ai_stylist_service.dart';
import 'package:flutter_app/state/wardrobe_store.dart';

void main() {
  group('AiStylistService Intent Parsing', () {
    const service = AiStylistService();

    test('parses semi-formal wisuda query with navy color', () {
      final intent = service.parseIntent('Rekomendasi pakaian ke wisuda teman warna navy');
      expect(intent.occasion, 'Smart-Casual');
      expect(intent.targetFormality, 4);
      expect(intent.preferredColors, contains('Biru'));
    });

    test('parses formal interview query', () {
      final intent = service.parseIntent('Baju untuk interview kerja di kantor');
      expect(intent.occasion, 'Formal');
      expect(intent.targetFormality, 5);
      expect(intent.preferredCategories, contains('Tops'));
    });

    test('parses casual campus query with black t-shirt', () {
      final intent = service.parseIntent('Outfit santai ngampus pakai kaos hitam');
      expect(intent.occasion, 'Kasual');
      expect(intent.targetFormality, 2);
      expect(intent.preferredColors, contains('Hitam'));
      expect(intent.preferredCategories, contains('Tops'));
    });

    test('parses sporty running query', () {
      final intent = service.parseIntent('Mau lari pagi olahraga santai');
      expect(intent.occasion, 'Sport');
      expect(intent.targetFormality, 1);
    });

    test('parses expanded topics: kondangan malam, sidang, kafe, netral, hitam putih, terbaru', () {
      final kondangan = service.parseIntent('Kondangan malam');
      expect(kondangan.occasion, 'Smart-Casual');
      expect(kondangan.targetFormality, 4);

      final sidang = service.parseIntent('Sidang & interview');
      expect(sidang.occasion, 'Formal');
      expect(sidang.targetFormality, 5);

      final kafe = service.parseIntent('Nongkrong di kafe');
      expect(kafe.occasion, 'Kasual');
      expect(kafe.targetFormality, 2);

      final hitamPutih = service.parseIntent('Padu padan hitam & putih');
      expect(hitamPutih.preferredColors, containsAll(['Hitam', 'Putih']));

      final netral = service.parseIntent('Outfit warna netral');
      expect(netral.preferredTone, 'netral');

      final terbaru = service.parseIntent('Rekomendasi dari baju terbaruku');
      expect(terbaru.preferNewest, isTrue);

      final sepatu = service.parseIntent('Padukan sepatu santai');
      expect(sepatu.preferredCategories, contains('Footwear'));
    });
  });

  group('AiStylistService Recommendations', () {
    const service = AiStylistService();

    test('returns fallback advice when wardrobe is empty', () async {
      final response = await service.recommend(
        query: 'Rekomendasi pakaian ke wisuda teman',
        wardrobe: [],
      );

      expect(response.options, isEmpty);
      expect(response.generalAdvice, isNotNull);
      expect(response.generalAdvice, contains('semi-formal'));
    });

    test('assembles matching outfit when items exist', () async {
      final demoWardrobe = [
        const WardrobeItem(
          id: 'top-1',
          name: 'Kemeja Oxford Putih',
          category: 'Tops',
          imagePath: '',
          colorName: 'Putih',
          color: Color(0xFFFFFFFF),
          formality: 4,
          occasions: ['Smart-Casual', 'Formal'],
        ),
        const WardrobeItem(
          id: 'bottom-1',
          name: 'Celana Chino Navy',
          category: 'Bottoms',
          imagePath: '',
          colorName: 'Navy',
          color: Color(0xFF000080),
          formality: 4,
          occasions: ['Smart-Casual'],
        ),
        const WardrobeItem(
          id: 'shoe-1',
          name: 'Sepatu Loafers Cokelat',
          category: 'Footwear',
          imagePath: '',
          colorName: 'Cokelat',
          color: Color(0xFF8B4513),
          formality: 4,
          occasions: ['Smart-Casual'],
        ),
      ];

      final response = await service.recommend(
        query: 'Acara wisuda teman',
        wardrobe: demoWardrobe,
      );

      expect(response.options, isNotEmpty);
      expect(response.options.first.items.length, greaterThanOrEqualTo(2));
      expect(response.options.first.matchScore, greaterThan(60));
      expect(response.options.first.stylingReason, isNotEmpty);
    });
  });

  group('HomeScreen AI Stylist Entry & Chat Screen UI', () {
    setUp(() {
      wardrobeItems.value = [
        const WardrobeItem(
          id: 'item-top',
          name: 'Kemeja Katun',
          category: 'Tops',
          imagePath: '',
          colorName: 'Putih',
          color: Colors.white,
          formality: 4,
        ),
        const WardrobeItem(
          id: 'item-bot',
          name: 'Celana Chino',
          category: 'Bottoms',
          imagePath: '',
          colorName: 'Hitam',
          color: Colors.black,
          formality: 4,
        ),
      ];
    });

    testWidgets('HomeScreen renders clean AI Stylist card and opens chat on tap', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(640, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const MaterialApp(home: HomeScreen(showNav: false)),
      );
      await tester.pump();

      expect(find.text('AI Stylist GAYAKU'), findsOneWidget);
      expect(find.text('TANYA GAYA'), findsOneWidget);
      expect(
        find.text("Tanya AI: 'Outfit wisuda, ngampus, atau kondangan'..."),
        findsOneWidget,
      );

      await tester.tap(
        find.text("Tanya AI: 'Outfit wisuda, ngampus, atau kondangan'..."),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AiStylistChatScreen), findsOneWidget);
    });

    testWidgets('AiStylistChatScreen displays friendly opening guide and supports free text', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(640, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const MaterialApp(home: AiStylistChatScreen()),
      );
      await tester.pump();

      expect(find.text('AI Stylist GAYAKU'), findsOneWidget);
      expect(
        find.textContaining('Halo! Aku AI Stylist pribadimu'),
        findsOneWidget,
      );
      expect(
        find.textContaining('bebas menanyakan rekomendasi outfit untuk acara apa saja'),
        findsOneWidget,
      );

      await tester.enterText(
        find.byType(TextField),
        'Mau outfit kasual ngampus',
      );
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Mau outfit kasual ngampus'), findsOneWidget);
    });
  });
}
