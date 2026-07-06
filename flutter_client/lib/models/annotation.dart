class Annotation {
  final String id;
  final String documentId;
  final String userId;
  final String userName;
  final int? pageNumber;
  final int startOffset;
  final int endOffset;
  final String selectedText;
  final String comment;
  final DateTime createdAt;
  final DateTime updatedAt;

  Annotation({
    required this.id,
    required this.documentId,
    required this.userId,
    required this.userName,
    this.pageNumber,
    required this.startOffset,
    required this.endOffset,
    required this.selectedText,
    required this.comment,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Annotation.fromJson(Map<String, dynamic> json) {
    return Annotation(
      id: json['id'] ?? json['_id'] ?? '',
      documentId: json['documentId'] ?? '',
      userId: json['userId'] ?? '',
      userName: json['userName'] ?? '',
      pageNumber: json['pageNumber'],
      startOffset: json['startOffset'] ?? 0,
      endOffset: json['endOffset'] ?? 0,
      selectedText: json['selectedText'] ?? '',
      comment: json['comment'] ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'documentId': documentId,
      'userId': userId,
      'userName': userName,
      'pageNumber': pageNumber,
      'startOffset': startOffset,
      'endOffset': endOffset,
      'selectedText': selectedText,
      'comment': comment,
    };
  }
}
