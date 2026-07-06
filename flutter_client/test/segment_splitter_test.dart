import 'package:flutter_test/flutter_test.dart';
import 'package:annotatehub/models/annotation.dart';
import 'package:annotatehub/utils/segment_splitter.dart';

void main() {
  group('Segment Splitting Algorithm Tests', () {
    test('Empty text returns empty segments', () {
      final annotations = <Annotation>[];
      final segments = splitTextIntoSegments('', annotations);
      expect(segments, isEmpty);
    });

    test('Text with no annotations returns a single full segment', () {
      final annotations = <Annotation>[];
      const text = 'Hello world';
      final segments = splitTextIntoSegments(text, annotations);
      
      expect(segments.length, equals(1));
      expect(segments[0].start, equals(0));
      expect(segments[0].end, equals(11));
      expect(segments[0].text, equals('Hello world'));
      expect(segments[0].coveringAnnotations, isEmpty);
    });

    test('Single annotation splits text into 3 segments', () {
      final annotations = [
        Annotation(
          id: '1',
          documentId: 'doc1',
          userId: 'user1',
          userName: 'Virat',
          startOffset: 6,
          endOffset: 11,
          selectedText: 'world',
          comment: 'Greeting',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];
      const text = 'Hello world!';
      final segments = splitTextIntoSegments(text, annotations);

      // Segments: "Hello " (0-6), "world" (6-11), "!" (11-12)
      expect(segments.length, equals(3));
      
      expect(segments[0].text, equals('Hello '));
      expect(segments[0].coveringAnnotations, isEmpty);

      expect(segments[1].text, equals('world'));
      expect(segments[1].coveringAnnotations.length, equals(1));
      expect(segments[1].coveringAnnotations[0].id, equals('1'));

      expect(segments[2].text, equals('!'));
      expect(segments[2].coveringAnnotations, isEmpty);
    });

    test('Overlapping annotations split correctly', () {
      final ann1 = Annotation(
        id: '1',
        documentId: 'doc1',
        userId: 'user1',
        userName: 'Virat',
        startOffset: 0,
        endOffset: 10,
        selectedText: '0123456789',
        comment: 'A',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final ann2 = Annotation(
        id: '2',
        documentId: 'doc1',
        userId: 'user2',
        userName: 'Rohit',
        startOffset: 5,
        endOffset: 15,
        selectedText: '56789abcde',
        comment: 'B',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      const text = '0123456789abcdef';
      final segments = splitTextIntoSegments(text, [ann1, ann2]);

      // Boundaries: 0, 5, 10, 15, 16
      // Segments:
      // 1. "01234" (0-5) - covered by ann1
      // 2. "56789" (5-10) - covered by ann1 & ann2
      // 3. "abcde" (10-15) - covered by ann2
      // 4. "f" (15-16) - covered by none
      expect(segments.length, equals(4));

      expect(segments[0].text, equals('01234'));
      expect(segments[0].coveringAnnotations.length, equals(1));
      expect(segments[0].coveringAnnotations[0].id, equals('1'));

      expect(segments[1].text, equals('56789'));
      expect(segments[1].coveringAnnotations.length, equals(2));
      expect(segments[1].coveringAnnotations.any((a) => a.id == '1'), isTrue);
      expect(segments[1].coveringAnnotations.any((a) => a.id == '2'), isTrue);

      expect(segments[2].text, equals('abcde'));
      expect(segments[2].coveringAnnotations.length, equals(1));
      expect(segments[2].coveringAnnotations[0].id, equals('2'));

      expect(segments[3].text, equals('f'));
      expect(segments[3].coveringAnnotations, isEmpty);
    });
  });
}
