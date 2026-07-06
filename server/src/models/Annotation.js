const mongoose = require('mongoose');

const AnnotationSchema = new mongoose.Schema({
  documentId: { type: mongoose.Schema.Types.ObjectId, ref: 'Document', required: true, index: true },
  userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  userName: { type: String, required: true },
  pageNumber: { type: Number, default: null }, // Null for plain text docs
  startOffset: { type: Number, required: true },
  endOffset: { type: Number, required: true },
  selectedText: { type: String, required: true },
  comment: { type: String, required: true },
  createdAt: { type: Date, default: Date.now },
  updatedAt: { type: Date, default: Date.now }
});

// Compound unique index: prevents same user from making identical annotations
AnnotationSchema.index({ documentId: 1, userId: 1, startOffset: 1, endOffset: 1 }, { unique: true });

// Query index: speeds up fetching and sorting by offset
AnnotationSchema.index({ documentId: 1, startOffset: 1 });

module.exports = mongoose.model('Annotation', AnnotationSchema);
