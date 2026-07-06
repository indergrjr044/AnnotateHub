import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../services/api_service.dart';
import '../models/document.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Document> _documents = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final apiService = Provider.of<ApiService>(context, listen: false);
      if (apiService.token == null || apiService.currentUser == null) {
        Navigator.of(context).pushReplacementNamed('/login');
      } else {
        _loadDocuments();
      }
    });
  }

  Future<void> _loadDocuments() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final docs = await apiService.fetchDocuments();
      setState(() {
        _documents = docs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load documents.';
        _isLoading = false;
      });
    }
  }

  Future<void> _handleUpload() async {
    final titleController = TextEditingController();
    PlatformFile? selectedFile;
    List<int>? fileBytes;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF16162A),
              title: const Text('Upload New Document', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Clickable Upload Box
                  GestureDetector(
                    onTap: () async {
                      try {
                        FilePickerResult? res = await FilePicker.platform.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: ['txt', 'pdf'],
                          withData: true,
                        );
                        if (res != null && res.files.isNotEmpty) {
                          final file = res.files.single;
                          setModalState(() {
                            selectedFile = file;
                            fileBytes = file.bytes;
                            if (titleController.text.isEmpty) {
                              titleController.text = file.name;
                            }
                          });
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text('Error picking file: $e'), backgroundColor: Colors.redAccent),
                        );
                      }
                    },
                    child: Container(
                      width: double.maxFinite,
                      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F0F1A),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: selectedFile != null ? Colors.deepPurpleAccent : Colors.white24,
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            selectedFile != null ? Icons.check_circle : Icons.upload_file,
                            color: selectedFile != null ? Colors.greenAccent : Colors.deepPurpleAccent,
                            size: 40,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            selectedFile != null ? selectedFile!.name : 'Click to Upload Document Here',
                            style: TextStyle(
                              color: selectedFile != null ? Colors.white : Colors.white70,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            selectedFile != null
                                ? 'Size: ${(selectedFile!.size / 1024).toStringAsFixed(1)} KB'
                                : 'Supports PDF and TXT files',
                            style: const TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (selectedFile != null) ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: titleController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Document Title',
                        labelStyle: TextStyle(color: Colors.white54),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.deepPurpleAccent)),
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                ),
                ElevatedButton(
                  onPressed: selectedFile != null && titleController.text.trim().isNotEmpty
                      ? () => Navigator.of(ctx).pop(true)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurpleAccent,
                    disabledBackgroundColor: Colors.white10,
                  ),
                  child: const Text('Upload', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirm == true && selectedFile != null && fileBytes != null) {
      setState(() {
        _isLoading = true;
      });
      try {
        final apiService = Provider.of<ApiService>(context, listen: false);
        await apiService.uploadDocument(
          titleController.text.trim(),
          fileBytes!,
          selectedFile!.name,
        );
        await _loadDocuments();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.redAccent),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleLogout() async {
    final apiService = Provider.of<ApiService>(context, listen: false);
    await apiService.logout();
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  Future<void> _confirmDelete(Document doc) async {
    final apiService = Provider.of<ApiService>(context, listen: false);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF16162A),
        title: const Text('Delete Document', style: TextStyle(color: Colors.white)),
        content: Text('Are you sure you want to delete "${doc.title}"? This will delete all comments and annotations permanently.', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _isLoading = true;
      });
      try {
        await apiService.deleteDocument(doc.id);
        await _loadDocuments();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Document deleted successfully'), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete document: $e'), backgroundColor: Colors.redAccent),
          );
        }
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final apiService = Provider.of<ApiService>(context);
    final user = apiService.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16162A),
        elevation: 0,
        title: const Text('AnnotateHub', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        actions: [
          if (user != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: Row(
                  children: [
                    const Icon(Icons.account_circle, color: Colors.deepPurpleAccent, size: 20),
                    const SizedBox(width: 6),
                    Text(
                      user.name,
                      style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white70),
            onPressed: _handleLogout,
            tooltip: 'Logout',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _handleUpload,
        backgroundColor: Colors.deepPurpleAccent,
        foregroundColor: Colors.white,
        child: const Icon(Icons.upload_file),
      ),
      body: RefreshIndicator(
        onRefresh: _loadDocuments,
        color: Colors.deepPurpleAccent,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.deepPurpleAccent))
            : _errorMessage != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 16)),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadDocuments,
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurpleAccent),
                          child: const Text('Try Again', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  )
                : _documents.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.folder_open, size: 64, color: Colors.white24),
                            SizedBox(height: 16),
                            Text(
                              'No documents uploaded yet.',
                              style: TextStyle(color: Colors.white54, fontSize: 16),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Click the upload button to get started.',
                              style: TextStyle(color: Colors.white30, fontSize: 14),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                        itemCount: _documents.length,
                        itemBuilder: (context, index) {
                          final doc = _documents[index];
                          final isPdf = doc.isPdf;
                          final isOwner = doc.uploadedBy?.id == user?.id;

                          return Card(
                            color: const Color(0xFF16162A),
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: Color(0xFF2C2C4E)),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: (isPdf ? Colors.redAccent : Colors.blueAccent).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  isPdf ? Icons.picture_as_pdf : Icons.description,
                                  color: isPdf ? Colors.redAccent : Colors.blueAccent,
                                  size: 28,
                                ),
                              ),
                              title: Text(
                                doc.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 6.0),
                                child: Text(
                                  'Size: ${_formatSize(doc.size)}  •  Uploaded by: ${doc.uploadedBy?.name ?? "Unknown"}',
                                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isOwner)
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                      onPressed: () => _confirmDelete(doc),
                                      tooltip: 'Delete Document',
                                    ),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.arrow_forward_ios, color: Colors.white30, size: 16),
                                ],
                              ),
                              onTap: () {
                                Navigator.of(context).pushNamed('/document?id=${doc.id}');
                              },
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}
