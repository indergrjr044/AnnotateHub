import 'user.dart';

class DocumentPage {
  final int pageNumber;
  final String text;

  DocumentPage({
    required this.pageNumber,
    required this.text,
  });

  factory DocumentPage.fromJson(Map<String, dynamic> json) {
    return DocumentPage(
      pageNumber: json['pageNumber'] ?? 1,
      text: json['text'] ?? '',
    );
  }
}

class Document {
  final String id;
  final String title;
  final String originalFilename;
  final String mimeType;
  final int size;
  final DateTime createdAt;
  final String extractedText;
  final List<DocumentPage> pages;
  final User? uploadedBy;

  Document({
    required this.id,
    required this.title,
    required this.originalFilename,
    required this.mimeType,
    required this.size,
    required this.createdAt,
    required this.extractedText,
    required this.pages,
    this.uploadedBy,
  });

  bool get isPdf => mimeType == 'application/pdf';

  factory Document.fromJson(Map<String, dynamic> json) {
    var pagesList = json['pages'] as List? ?? [];
    List<DocumentPage> parsedPages = pagesList
        .map((p) => DocumentPage.fromJson(p as Map<String, dynamic>))
        .toList();

    User? uBy;
    if (json['uploadedBy'] != null) {
      if (json['uploadedBy'] is Map) {
        uBy = User.fromJson(json['uploadedBy'] as Map<String, dynamic>);
      } else if (json['uploadedBy'] is String) {
        uBy = User(id: json['uploadedBy'] as String, name: 'User', email: '');
      }
    }

    return Document(
      id: json['id'] ?? json['_id'] ?? '',
      title: json['title'] ?? '',
      originalFilename: json['originalFilename'] ?? '',
      mimeType: json['mimeType'] ?? '',
      size: json['size'] ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      extractedText: json['extractedText'] ?? '',
      pages: parsedPages,
      uploadedBy: uBy,
    );
  }
}
