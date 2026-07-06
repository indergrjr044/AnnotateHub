import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';
import '../models/document.dart';
import '../models/annotation.dart';
import '../models/user.dart';
import '../widgets/annotation_card.dart';
import '../utils/segment_splitter.dart';

class DocumentDetailScreen extends StatefulWidget {
  final String documentId;

  const DocumentDetailScreen({super.key, required this.documentId});

  @override
  State<DocumentDetailScreen> createState() => _DocumentDetailScreenState();
}

class _DocumentDetailScreenState extends State<DocumentDetailScreen> {
  Document? _document;
  List<Annotation> _annotations = [];
  List<Annotation> _selectedAnnotations = [];
  List<dynamic> _activeUsers = [];
  bool _isLoading = true;
  String? _errorMessage;

  final SocketService _socketService = SocketService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _sidebarScrollController = ScrollController();

  // Selection states
  int? _selStart;
  int? _selEnd;
  String _selText = '';
  String? _hoveredAnnotationId;
  final Map<String, Map<String, dynamic>> _activeCursors = {};
  final Map<String, Map<String, dynamic>> _peerSelections = {};
  DateTime? _lastEmitTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final apiService = Provider.of<ApiService>(context, listen: false);
      if (apiService.token == null || apiService.currentUser == null) {
        Navigator.of(context).pushReplacementNamed('/login');
      } else {
        _loadDocumentAndAnnotations();
        _searchController.addListener(() => setState(() {}));
      }
    });
  }

  @override
  void dispose() {
    _socketService.emitSelectionChange(null, null);
    _socketService.leaveDocument(widget.documentId);
    _socketService.disconnect();
    _searchController.dispose();
    _sidebarScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadDocumentAndAnnotations() async {
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final doc = await apiService.fetchDocumentDetail(widget.documentId);
      final list = await apiService.fetchAnnotations(widget.documentId);

      setState(() {
        _document = doc;
        _annotations = list;
        _isLoading = false;
      });

      _initRealtimeConnection(doc, apiService.currentUser);
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load document details.';
        _isLoading = false;
      });
    }
  }

  void _initRealtimeConnection(Document doc, User? currentUser) {
    if (currentUser == null) return;

    final apiService = Provider.of<ApiService>(context, listen: false);
    _socketService.connect(apiService.baseUrl, onConnect: () {
      _socketService.joinDocument(doc.id, currentUser);
    });

    _socketService.listenToEvents(
      onPresenceUpdate: (users) {
        if (mounted) {
          setState(() {
            _activeUsers = users;
          });
        }
      },
      onAnnotationCreated: (ann) {
        if (mounted) {
          setState(() {
            _annotations.add(ann);
            _annotations.sort((a, b) => a.startOffset.compareTo(b.startOffset));
          });
        }
      },
      onAnnotationUpdated: (ann) {
        if (mounted) {
          setState(() {
            final idx = _annotations.indexWhere((element) => element.id == ann.id);
            if (idx != -1) {
              _annotations[idx] = ann;
            }
          });
        }
      },
      onAnnotationDeleted: (annId) {
        if (mounted) {
          setState(() {
            _annotations.removeWhere((element) => element.id == annId);
            _selectedAnnotations.removeWhere((element) => element.id == annId);
          });
        }
      },
      onCursorUpdate: (cursorData) {
        if (mounted) {
          setState(() {
            final socketId = cursorData['socketId'] as String;
            _activeCursors[socketId] = cursorData;
          });
        }
      },
      onCursorRemove: (socketId) {
        if (mounted) {
          setState(() {
            _activeCursors.remove(socketId);
          });
        }
      },
      onSelectionUpdate: (selectionData) {
        if (mounted) {
          setState(() {
            final socketId = selectionData['socketId'] as String;
            if (selectionData['startOffset'] == null || selectionData['endOffset'] == null) {
              _peerSelections.remove(socketId);
            } else {
              _peerSelections[socketId] = selectionData;
            }
          });
        }
      },
      onSelectionRemove: (socketId) {
        if (mounted) {
          setState(() {
            _peerSelections.remove(socketId);
          });
        }
      },
    );
  }







  Future<void> _addAnnotation() async {
    if (_selText.isEmpty || _selStart == null || _selEnd == null) return;

    final commentController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16162A),
        title: const Text('Add Annotation Note', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.white10,
              child: Text(
                '"$_selText"',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, fontStyle: FontStyle.italic),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: commentController,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Enter your comments...',
                hintStyle: TextStyle(color: Colors.white30),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.deepPurpleAccent)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurpleAccent),
            child: const Text('Add Note', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true && commentController.text.trim().isNotEmpty) {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final currentUser = apiService.currentUser;
      if (currentUser != null) {
        final hasDuplicate = _annotations.any((ann) =>
            ann.userId == currentUser.id &&
            ann.startOffset == _selStart! &&
            ann.endOffset == _selEnd!);
        if (hasDuplicate) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You have already annotated this exact selection range.'),
              backgroundColor: Colors.orangeAccent,
            ),
          );
          return;
        }
      }

      try {
        final newAnn = await apiService.createAnnotation(
          documentId: widget.documentId,
          startOffset: _selStart!,
          endOffset: _selEnd!,
          selectedText: _selText,
          comment: commentController.text.trim(),
          socketId: _socketService.socketId,
        );

        setState(() {
          _annotations.add(newAnn);
          _annotations.sort((a, b) => a.startOffset.compareTo(b.startOffset));
          _selText = '';
          _selStart = null;
          _selEnd = null;
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save annotation: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _editAnnotation(String id, String comment) async {
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final updated = await apiService.updateAnnotation(
        id,
        comment,
        socketId: _socketService.socketId,
      );

      setState(() {
        final idx = _annotations.indexWhere((element) => element.id == id);
        if (idx != -1) {
          _annotations[idx] = updated;
        }
        final selIdx = _selectedAnnotations.indexWhere((element) => element.id == id);
        if (selIdx != -1) {
          _selectedAnnotations[selIdx] = updated;
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Edit failed: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  Future<void> _deleteAnnotation(String id) async {
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      await apiService.deleteAnnotation(id, socketId: _socketService.socketId);

      setState(() {
        _annotations.removeWhere((element) => element.id == id);
        _selectedAnnotations.removeWhere((element) => element.id == id);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deletion failed: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  List<Annotation> _getFilteredAnnotations() {
    final query = _searchController.text.toLowerCase().trim();
    if (query.isEmpty) return _annotations;

    return _annotations.where((ann) {
      return ann.selectedText.toLowerCase().contains(query) ||
          ann.comment.toLowerCase().contains(query) ||
          ann.userName.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F0F1A),
        body: Center(child: CircularProgressIndicator(color: Colors.deepPurpleAccent)),
      );
    }

    if (_errorMessage != null || _document == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F0F1A),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_errorMessage ?? 'Document not found.', style: const TextStyle(color: Colors.redAccent, fontSize: 16)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurpleAccent),
                child: const Text('Back to Dashboard', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    final apiService = Provider.of<ApiService>(context);
    final user = apiService.currentUser;
    final textSegments = splitTextIntoSegments(
      _document!.extractedText,
      _annotations,
      activeStart: _selStart,
      activeEnd: _selEnd,
      peerSelections: _peerSelections.values.toList(),
    );
    final filteredAnnotations = _getFilteredAnnotations();

    // Render Text Widget representing highlights & selectable regions
    Widget textWidget = SelectableText.rich(
      TextSpan(
        children: textSegments.map((seg) {
          final isSelectedSegment = _selectedAnnotations.any((s) =>
              seg.coveringAnnotations.any((c) => c.id == s.id));
          final isHoveredSegment = _hoveredAnnotationId != null &&
              seg.coveringAnnotations.any((c) => c.id == _hoveredAnnotationId);
          final isInsideActiveSelection = _selStart != null &&
              _selEnd != null &&
              seg.start >= _selStart! &&
              seg.end <= _selEnd!;

          // Find if there is a peer selecting this segment
          Map<String, dynamic>? peerSel;
          for (var p in _peerSelections.values) {
            if (p['startOffset'] != null &&
                p['endOffset'] != null &&
                seg.start >= (p['startOffset'] as int) &&
                seg.end <= (p['endOffset'] as int)) {
              peerSel = p;
              break;
            }
          }

          Color bgColor;
          TextDecoration decoration = TextDecoration.none;
          TextDecorationStyle? decorationStyle;
          Color? decorationColor;

          if (isSelectedSegment) {
            bgColor = Colors.deepPurpleAccent.withValues(alpha: 0.5);
            decoration = TextDecoration.underline;
          } else if (isHoveredSegment) {
            bgColor = Colors.deepPurpleAccent.withValues(alpha: 0.25);
            decoration = TextDecoration.underline;
          } else if (isInsideActiveSelection) {
            bgColor = Colors.blue.withValues(alpha: 0.35);
          } else if (peerSel != null) {
            final color = _getCursorColor(peerSel['socketId'] as String);
            bgColor = color.withValues(alpha: 0.18);
            decoration = TextDecoration.underline;
            decorationStyle = TextDecorationStyle.dashed;
            decorationColor = color;
          } else {
            bgColor = Colors.transparent;
          }

          final List<InlineSpan> inlineSpans = [
            TextSpan(
              text: seg.text,
              style: TextStyle(
                color: const Color(0xFFEEEEF5),
                backgroundColor: bgColor,
                decoration: decoration,
                decorationStyle: decorationStyle,
                decorationColor: decorationColor ?? Colors.deepPurpleAccent.withValues(alpha: 0.8),
              ),
              recognizer: TapGestureRecognizer()
                ..onTap = () {
                  if (seg.coveringAnnotations.isNotEmpty) {
                    setState(() {
                      _selectedAnnotations = seg.coveringAnnotations;
                    });
                  }
                },
            ),
          ];

          // If this segment is the end of the peer's selection range, append an inline name badge
          if (peerSel != null && seg.end == (peerSel['endOffset'] as int)) {
            final color = _getCursorColor(peerSel['socketId'] as String);
            final String name = peerSel['userName'] as String;
            inlineSpans.add(
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Container(
                  margin: const EdgeInsets.only(left: 6, right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 3),
                      const Icon(
                        Icons.edit,
                        color: Colors.white,
                        size: 9,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          return TextSpan(children: inlineSpans);
        }).toList(),
      ),
      selectionColor: Colors.blue.withValues(alpha: 0.4),
      style: const TextStyle(
        color: Color(0xFFE2E2E9),
        fontSize: 16,
        height: 1.6,
        fontFamily: 'Roboto',
      ),
      onSelectionChanged: (selection, cause) {
        final start = selection.start;
        final end = selection.end;
        if (start >= 0 && end > start) {
          final selectedText = _document!.extractedText.substring(start, end);
          setState(() {
            _selStart = start;
            _selEnd = end;
            _selText = selectedText;
          });
          _socketService.emitSelectionChange(start, end);
        } else {
          setState(() {
            _selStart = null;
            _selEnd = null;
            _selText = '';
          });
          _socketService.emitSelectionChange(null, null);
        }
      },
    );

    // Sidebar Widgets
    Widget sidebarWidget = Container(
      width: 380,
      color: const Color(0xFF16162A),
      padding: const EdgeInsets.only(top: 20, left: 16, right: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Notes (${_annotations.length})',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              ),
              if (_selectedAnnotations.isNotEmpty)
                TextButton(
                  onPressed: () => setState(() => _selectedAnnotations = []),
                  child: const Text('Clear Selection', style: TextStyle(color: Colors.deepPurpleAccent, fontSize: 13)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Filter notes...',
              hintStyle: const TextStyle(color: Colors.white30),
              prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 20),
              filled: true,
              fillColor: const Color(0xFF1E1E38),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF2C2C4E)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.deepPurpleAccent),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _selectedAnnotations.isNotEmpty
                ? ListView.builder(
                    controller: _sidebarScrollController,
                    itemCount: _selectedAnnotations.length,
                    itemBuilder: (context, idx) {
                      final ann = _selectedAnnotations[idx];
                      return MouseRegion(
                        onEnter: (_) {
                          setState(() {
                            _hoveredAnnotationId = ann.id;
                          });
                        },
                        onExit: (_) {
                          setState(() {
                            _hoveredAnnotationId = null;
                          });
                        },
                        child: AnnotationCard(
                          annotation: ann,
                          currentUser: user,
                          isSelected: true,
                          onTap: () {},
                          onEdit: (comment) => _editAnnotation(ann.id, comment),
                          onDelete: () => _deleteAnnotation(ann.id),
                        ),
                      );
                    },
                  )
                : filteredAnnotations.isEmpty
                    ? const Center(
                        child: Text(
                          'No comments available.',
                          style: TextStyle(color: Colors.white38, fontSize: 14),
                        ),
                      )
                    : ListView.builder(
                        controller: _sidebarScrollController,
                        itemCount: filteredAnnotations.length,
                        itemBuilder: (context, idx) {
                          final ann = filteredAnnotations[idx];
                          return MouseRegion(
                            onEnter: (_) {
                              setState(() {
                                _hoveredAnnotationId = ann.id;
                              });
                            },
                            onExit: (_) {
                              setState(() {
                                _hoveredAnnotationId = null;
                              });
                            },
                            child: AnnotationCard(
                              annotation: ann,
                              currentUser: user,
                              isSelected: false,
                              onTap: () {
                                setState(() {
                                  _selectedAnnotations = [ann];
                                });
                              },
                              onEdit: (comment) => _editAnnotation(ann.id, comment),
                              onDelete: () => _deleteAnnotation(ann.id),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16162A),
        title: Text(_document!.title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white70),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          // Active users presence count indicator dropdown
          PopupMenuButton<String>(
            tooltip: 'View active users',
            color: const Color(0xFF1E1E38),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: Color(0xFF2C2C4E)),
            ),
            offset: const Offset(0, 48),
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.greenAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${_activeUsers.length} viewing',
                    style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_drop_down, color: Colors.white70, size: 20),
                ],
              ),
            ),
            itemBuilder: (BuildContext context) {
              if (_activeUsers.isEmpty) {
                return [
                  const PopupMenuItem<String>(
                    enabled: false,
                    child: Text(
                      'No other users online',
                      style: TextStyle(color: Colors.white38, fontSize: 13),
                    ),
                  )
                ];
              }
              return _activeUsers.map((userObj) {
                final name = (userObj as Map)['userName'] as String? ?? 'Anonymous';
                return PopupMenuItem<String>(
                  enabled: false,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.person_outline, color: Colors.deepPurpleAccent, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        name,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ],
                  ),
                );
              }).toList();
            },
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 800;

          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left Panel: Document Viewer
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Tool helper bar
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          margin: const EdgeInsets.only(bottom: 24),
                          decoration: BoxDecoration(
                            color: const Color(0xFF16162A),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF2C2C4E)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline, color: Colors.deepPurpleAccent, size: 18),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Tap on highlighted text to view annotation notes, or double-tap to copy/select.',
                                  style: TextStyle(color: Colors.white54, fontSize: 13),
                                ),
                              ),
                              // Selection annotation button
                              if (_selText.isNotEmpty) ...[
                                const SizedBox(width: 12),
                                ElevatedButton.icon(
                                  onPressed: _addAnnotation,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.deepPurpleAccent,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                  icon: const Icon(Icons.note_add, size: 16, color: Colors.white),
                                  label: const Text('Add Note', style: TextStyle(fontSize: 12, color: Colors.white)),
                                ),
                              ]
                            ],
                          ),
                        ),
                        // Plain Text Reader
                        LayoutBuilder(
                          builder: (context, constraints) {
                            return MouseRegion(
                              onHover: (event) {
                                final now = DateTime.now();
                                if (_lastEmitTime == null || 
                                    now.difference(_lastEmitTime!) > const Duration(milliseconds: 35)) {
                                  _lastEmitTime = now;
                                  final double xRatio = event.localPosition.dx / constraints.maxWidth;
                                  final double yRatio = event.localPosition.dy / constraints.maxHeight;
                                  _socketService.emitCursorMove(xRatio, yRatio);
                                }
                              },
                              child: Stack(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(24),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF16162A),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: const Color(0xFF2C2C4E)),
                                    ),
                                    child: textWidget,
                                  ),
                                  ..._buildLiveCursors(constraints.maxWidth, constraints.maxHeight),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                // Vertical divider line
                Container(width: 1, color: const Color(0xFF2C2C4E)),
                // Right Panel: Annotation Sidebar
                sidebarWidget,
              ],
            );
          } else {
            // Narrow view (Mobile) -> Tabs layout or scrollable views
            return DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  const Material(
                    color: Color(0xFF16162A),
                    child: TabBar(
                      tabs: [
                        Tab(text: 'Reader'),
                        Tab(text: 'Notes'),
                      ],
                      labelColor: Colors.deepPurpleAccent,
                      unselectedLabelColor: Colors.white54,
                      indicatorColor: Colors.deepPurpleAccent,
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (_selText.isNotEmpty) ...[
                                ElevatedButton.icon(
                                  onPressed: _addAnnotation,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.deepPurpleAccent,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                  icon: const Icon(Icons.note_add, color: Colors.white),
                                  label: const Text('Annotate Selected Text', style: TextStyle(color: Colors.white)),
                                ),
                                const SizedBox(height: 16),
                              ],
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  return MouseRegion(
                                    onHover: (event) {
                                      final now = DateTime.now();
                                      if (_lastEmitTime == null || 
                                          now.difference(_lastEmitTime!) > const Duration(milliseconds: 35)) {
                                        _lastEmitTime = now;
                                        final double xRatio = event.localPosition.dx / constraints.maxWidth;
                                        final double yRatio = event.localPosition.dy / constraints.maxHeight;
                                        _socketService.emitCursorMove(xRatio, yRatio);
                                      }
                                    },
                                    child: Stack(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(20),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF16162A),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: const Color(0xFF2C2C4E)),
                                          ),
                                          child: textWidget,
                                        ),
                                        ..._buildLiveCursors(constraints.maxWidth, constraints.maxHeight),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        sidebarWidget,
                      ],
                    ),
                  ),
                ],
              ),
            );
          }
        },
      ),
    );
  }

  List<Widget> _buildLiveCursors(double maxWidth, double maxHeight) {
    final List<Widget> list = [];
    
    _activeCursors.forEach((socketId, data) {
      final double xRatio = (data['xRatio'] as num).toDouble();
      final double yRatio = (data['yRatio'] as num).toDouble();
      final String name = data['userName'] as String;
      
      // Calculate coordinates relative to container size
      final double x = xRatio * maxWidth;
      final double y = yRatio * maxHeight;
      
      // Assign distinct colors based on socketId hash
      final color = _getCursorColor(socketId);
      
      list.add(
        AnimatedPositioned(
          key: ValueKey(socketId),
          duration: const Duration(milliseconds: 55),
          left: x,
          top: y,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Transform.rotate(
                angle: -0.5,
                child: Icon(
                  Icons.navigation,
                  color: color,
                  size: 20,
                ),
              ),
              Container(
                margin: const EdgeInsets.only(left: 12),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    )
                  ],
                ),
                child: Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
    
    return list;
  }

  Color _getCursorColor(String socketId) {
    final colors = [
      Colors.orangeAccent,
      Colors.blueAccent,
      Colors.greenAccent,
      Colors.pinkAccent,
      Colors.deepOrangeAccent,
      Colors.tealAccent,
      Colors.purpleAccent,
    ];
    final index = socketId.hashCode % colors.length;
    return colors[index.abs()];
  }
}


