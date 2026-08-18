import 'package:flutter_test/flutter_test.dart';
import 'package:retinascreen/rag/rag_service.dart';

void main() {
  test('returns nothing before init', () {
    expect(RagService().retrieve('anything'), isEmpty);
  });

  test('retrieves an in-language passage for a related query', () async {
    final rag = RagService();
    await rag.init();
    final hits = rag.retrieve(
      'bring report to the eye appointment',
      lang: 'en',
    );
    expect(hits, isNotEmpty);
    expect(hits.every((h) => h.lang == 'en'), isTrue);
    expect(hits.any((h) => h.topic == 'prepare-visit'), isTrue);
  });

  test('an attendance query surfaces the attendance passage', () async {
    final rag = RagService();
    await rag.init();
    final hits = rag.retrieve(
      'attending is important to prevent vision loss',
      lang: 'en',
    );
    expect(hits.map((h) => h.topic), contains('why-attend'));
  });
}
