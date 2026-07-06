import '../models/annotation.dart';

class TextSegment {
  final int start;
  final int end;
  final String text;
  final List<Annotation> coveringAnnotations;

  TextSegment({
    required this.start,
    required this.end,
    required this.text,
    required this.coveringAnnotations,
  });
}

List<TextSegment> splitTextIntoSegments(
  String fullText, 
  List<Annotation> annotations, {
  int? activeStart,
  int? activeEnd,
  List<Map<String, dynamic>> peerSelections = const [],
}) {
  if (fullText.isEmpty) return [];

  final Set<int> boundaries = {0, fullText.length};
  for (var ann in annotations) {
    if (ann.startOffset >= 0 && ann.startOffset <= fullText.length) {
      boundaries.add(ann.startOffset);
    }
    if (ann.endOffset >= 0 && ann.endOffset <= fullText.length) {
      boundaries.add(ann.endOffset);
    }
  }

  if (activeStart != null && activeStart >= 0 && activeStart <= fullText.length) {
    boundaries.add(activeStart);
  }
  if (activeEnd != null && activeEnd >= 0 && activeEnd <= fullText.length) {
    boundaries.add(activeEnd);
  }

  for (var peer in peerSelections) {
    final start = peer['startOffset'] as int?;
    final end = peer['endOffset'] as int?;
    if (start != null && start >= 0 && start <= fullText.length) {
      boundaries.add(start);
    }
    if (end != null && end >= 0 && end <= fullText.length) {
      boundaries.add(end);
    }
  }

  final sortedBoundaries = boundaries.toList()..sort();

  final List<TextSegment> segments = [];
  for (int i = 0; i < sortedBoundaries.length - 1; i++) {
    final start = sortedBoundaries[i];
    final end = sortedBoundaries[i + 1];
    if (start == end) continue;

    final segmentText = fullText.substring(start, end);
    final covering = annotations.where((ann) {
      return ann.startOffset <= start && ann.endOffset >= end;
    }).toList();

    segments.add(TextSegment(
      start: start,
      end: end,
      text: segmentText,
      coveringAnnotations: covering,
    ));
  }

  return segments;
}
