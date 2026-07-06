const express = require('express');
const router = express.Router();
const authMiddleware = require('../middleware/auth');
const Annotation = require('../models/Annotation');
const Document = require('../models/Document');
const { emitToDocumentRoom } = require('../services/socket');
const { asyncHandler } = require('../middleware/errorHandler');

// POST /api/documents/:id/annotations
router.post('/documents/:id/annotations', authMiddleware, asyncHandler(async (req, res) => {
  const documentId = req.params.id;
  const { pageNumber, startOffset, endOffset, selectedText, comment } = req.body;

  if (startOffset === undefined || endOffset === undefined || !selectedText || !comment) {
    return res.status(400).json({ error: 'ValidationError', message: 'Missing required annotation fields.' });
  }

  const docExists = await Document.exists({ _id: documentId });
  if (!docExists) {
    return res.status(404).json({ error: 'NotFound', message: 'Document not found.' });
  }

  const annotation = new Annotation({
    documentId,
    userId: req.body.userId || req.user.id,
    userName: req.body.userName || req.user.name,
    pageNumber: pageNumber || null,
    startOffset,
    endOffset,
    selectedText,
    comment
  });

  await annotation.save();

  // Broadcast to other users in the room
  const socketId = req.headers['x-socket-id'];
  emitToDocumentRoom(documentId, 'annotation:created', annotation, socketId);

  res.status(201).json(annotation);
}));

// GET /api/documents/:id/annotations
router.get('/documents/:id/annotations', authMiddleware, asyncHandler(async (req, res) => {
  const documentId = req.params.id;
  const page = parseInt(req.query.page);
  const limit = parseInt(req.query.limit);

  const query = { documentId };

  if (page && limit) {
    const skip = (page - 1) * limit;
    const [annotations, total] = await Promise.all([
      Annotation.find(query).sort({ startOffset: 1 }).skip(skip).limit(limit),
      Annotation.countDocuments(query)
    ]);

    res.json({
      annotations,
      pagination: {
        total,
        pages: Math.ceil(total / limit),
        page,
        limit
      }
    });
  } else {
    const annotations = await Annotation.find(query).sort({ startOffset: 1 });
    res.json({ annotations });
  }
}));

// PATCH /api/annotations/:annotationId
router.patch('/annotations/:annotationId', authMiddleware, asyncHandler(async (req, res) => {
  const { comment } = req.body;
  if (!comment) {
    return res.status(400).json({ error: 'ValidationError', message: 'Comment is required.' });
  }

  const annotation = await Annotation.findById(req.params.annotationId);
  if (!annotation) {
    return res.status(404).json({ error: 'NotFound', message: 'Annotation not found.' });
  }

  if (annotation.userId.toString() !== req.user.id) {
    return res.status(403).json({ error: 'Forbidden', message: 'You can only edit your own annotations.' });
  }

  annotation.comment = comment;
  annotation.updatedAt = Date.now();
  await annotation.save();

  const socketId = req.headers['x-socket-id'];
  emitToDocumentRoom(annotation.documentId.toString(), 'annotation:updated', annotation, socketId);

  res.json(annotation);
}));

// DELETE /api/annotations/:annotationId
router.delete('/annotations/:annotationId', authMiddleware, asyncHandler(async (req, res) => {
  const annotation = await Annotation.findById(req.params.annotationId);
  if (!annotation) {
    return res.status(404).json({ error: 'NotFound', message: 'Annotation not found.' });
  }

  if (annotation.userId.toString() !== req.user.id) {
    return res.status(403).json({ error: 'Forbidden', message: 'You can only delete your own annotations.' });
  }

  await Annotation.deleteOne({ _id: annotation._id });

  const socketId = req.headers['x-socket-id'];
  emitToDocumentRoom(annotation.documentId.toString(), 'annotation:deleted', { annotationId: annotation._id }, socketId);

  res.json({ message: 'Annotation deleted successfully.' });
}));

module.exports = router;
