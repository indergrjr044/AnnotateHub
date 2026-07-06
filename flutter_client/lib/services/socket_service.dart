import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../models/user.dart';
import '../models/annotation.dart';

typedef PresenceCallback = void Function(List<dynamic> users);
typedef AnnotationCallback = void Function(Annotation annotation);
typedef AnnotationDeleteCallback = void Function(String annotationId);
typedef CursorUpdateCallback = void Function(Map<String, dynamic> cursorData);
typedef CursorRemoveCallback = void Function(String socketId);
typedef SelectionUpdateCallback = void Function(Map<String, dynamic> selectionData);
typedef SelectionRemoveCallback = void Function(String socketId);

class SocketService {
  IO.Socket? _socket;
  String? _socketId;

  String? get socketId => _socketId;
  bool get isConnected => _socket?.connected ?? false;

  void connect(String url, {required Function() onConnect}) {
    if (_socket != null) {
      _socket!.disconnect();
    }

    _socket = IO.io(url, IO.OptionBuilder()
      .setTransports(['websocket'])
      .disableAutoConnect()
      .build());

    _socket!.onConnect((_) {
      final s = _socket;
      if (s != null) {
        _socketId = (s as dynamic).id;
        print('Socket connected: $_socketId');
        onConnect();
      }
    });

    _socket!.onDisconnect((_) {
      print('Socket disconnected');
      _socketId = null;
    });

    _socket!.connect();
  }

  void disconnect() {
    _socket?.disconnect();
    _socket = null;
    _socketId = null;
  }

  void joinDocument(String documentId, User user) {
    if (_socket == null || !_socket!.connected) return;
    _socket!.emit('join-document', {
      'documentId': documentId,
      'user': user.toJson(),
    });
  }

  void leaveDocument(String documentId) {
    if (_socket == null || !_socket!.connected) return;
    _socket!.emit('leave-document', {
      'documentId': documentId,
    });
  }

  void emitCursorMove(double xRatio, double yRatio) {
    if (_socket == null || !_socket!.connected) return;
    _socket!.emit('cursor-move', {
      'xRatio': xRatio,
      'yRatio': yRatio,
    });
  }

  void emitSelectionChange(int? startOffset, int? endOffset) {
    if (_socket == null || !_socket!.connected) return;
    _socket!.emit('selection-change', {
      'startOffset': startOffset,
      'endOffset': endOffset,
    });
  }

  void listenToEvents({
    required PresenceCallback onPresenceUpdate,
    required AnnotationCallback onAnnotationCreated,
    required AnnotationCallback onAnnotationUpdated,
    required AnnotationDeleteCallback onAnnotationDeleted,
    required CursorUpdateCallback onCursorUpdate,
    required CursorRemoveCallback onCursorRemove,
    required SelectionUpdateCallback onSelectionUpdate,
    required SelectionRemoveCallback onSelectionRemove,
  }) {
    if (_socket == null) return;

    _socket!.off('presence:update');
    _socket!.off('annotation:created');
    _socket!.off('annotation:updated');
    _socket!.off('annotation:deleted');
    _socket!.off('cursor:update');
    _socket!.off('cursor:remove');
    _socket!.off('selection:update');
    _socket!.off('selection:remove');

    _socket!.on('presence:update', (data) {
      if (data is List) {
        onPresenceUpdate(data);
      }
    });

    _socket!.on('annotation:created', (data) {
      if (data is Map<String, dynamic>) {
        onAnnotationCreated(Annotation.fromJson(data));
      }
    });

    _socket!.on('annotation:updated', (data) {
      if (data is Map<String, dynamic>) {
        onAnnotationUpdated(Annotation.fromJson(data));
      }
    });

    _socket!.on('annotation:deleted', (data) {
      if (data is Map<String, dynamic> && data['annotationId'] != null) {
        onAnnotationDeleted(data['annotationId'] as String);
      }
    });

    _socket!.on('cursor:update', (data) {
      if (data is Map) {
        onCursorUpdate(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on('cursor:remove', (data) {
      if (data is Map && data['socketId'] != null) {
        onCursorRemove(data['socketId'] as String);
      }
    });

    _socket!.on('selection:update', (data) {
      if (data is Map) {
        onSelectionUpdate(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on('selection:remove', (data) {
      if (data is Map && data['socketId'] != null) {
        onSelectionRemove(data['socketId'] as String);
      }
    });
  }
}
