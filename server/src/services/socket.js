const { Server } = require('socket.io');

let io = null;

// Track presence: documentId -> Array of { socketId, userId, userName }
const roomUsers = {};

const initSocket = (server) => {
  io = new Server(server, {
    cors: {
      origin: '*', // Allow all origins for the take-home demo
      methods: ['GET', 'POST', 'PATCH', 'DELETE']
    }
  });

  io.on('connection', (socket) => {
    console.log(`Socket connected: ${socket.id}`);

    // Join a document room
    socket.on('join-document', ({ documentId, user }) => {
      if (!documentId || !user) return;
      
      socket.join(documentId);
      socket.documentId = documentId;
      socket.user = user; // { id, name, email }

      if (!roomUsers[documentId]) {
        roomUsers[documentId] = [];
      }

      // Avoid duplicate presence listings for the same socket connection
      if (!roomUsers[documentId].some((u) => u.socketId === socket.id)) {
        roomUsers[documentId].push({
          socketId: socket.id,
          userId: user.id,
          userName: user.name
        });
      }

      console.log(`User ${user.name} joined room: ${documentId}`);

      // Broadcast active user list to the room
      io.to(documentId).emit('presence:update', getUniqueUsersInRoom(documentId));
    });

    // Leave a document room explicitly
    socket.on('leave-document', ({ documentId }) => {
      if (!documentId) return;
      socket.leave(documentId);
      removeUserFromRoom(socket.id, documentId);
      io.to(documentId).emit('cursor:remove', { socketId: socket.id });
      io.to(documentId).emit('selection:remove', { socketId: socket.id });
    });

    // Handle cursor moves
    socket.on('cursor-move', ({ xRatio, yRatio }) => {
      if (socket.documentId) {
        socket.to(socket.documentId).emit('cursor:update', {
          socketId: socket.id,
          userName: socket.user?.name || 'Anonymous',
          xRatio,
          yRatio
        });
      }
    });

    // Handle active text selections
    socket.on('selection-change', ({ startOffset, endOffset }) => {
      if (socket.documentId) {
        socket.to(socket.documentId).emit('selection:update', {
          socketId: socket.id,
          userName: socket.user?.name || 'Anonymous',
          startOffset,
          endOffset
        });
      }
    });

    // Handle disconnect
    socket.on('disconnect', () => {
      console.log(`Socket disconnected: ${socket.id}`);
      if (socket.documentId) {
        removeUserFromRoom(socket.id, socket.documentId);
        io.to(socket.documentId).emit('cursor:remove', { socketId: socket.id });
        io.to(socket.documentId).emit('selection:remove', { socketId: socket.id });
      }
    });
  });

  return io;
};

// Helper: Remove user from active room trackers
const removeUserFromRoom = (socketId, documentId) => {
  if (roomUsers[documentId]) {
    roomUsers[documentId] = roomUsers[documentId].filter((u) => u.socketId !== socketId);
    
    // Broadcast updated presence list
    io.to(documentId).emit('presence:update', getUniqueUsersInRoom(documentId));
    
    if (roomUsers[documentId].length === 0) {
      delete roomUsers[documentId];
    }
  }
};

// Helper: Get unique users by userId in a room to present a clean viewer count/list
const getUniqueUsersInRoom = (documentId) => {
  const users = roomUsers[documentId] || [];
  const unique = [];
  const visited = new Set();
  for (const u of users) {
    if (!visited.has(u.userId)) {
      visited.add(u.userId);
      unique.push({ userId: u.userId, userName: u.userName });
    }
  }
  return unique;
};

// Broadcasts an event to a document room, optionally excluding the sender
const emitToDocumentRoom = (documentId, event, data, excludeSocketId = null) => {
  if (!io) return;
  if (excludeSocketId) {
    // Socket.io syntax to emit to all in room except sender
    io.to(documentId).except(excludeSocketId).emit(event, data);
  } else {
    io.to(documentId).emit(event, data);
  }
};

module.exports = {
  initSocket,
  emitToDocumentRoom
};
