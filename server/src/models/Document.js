const mongoose = require('mongoose');

const DocumentSchema = new mongoose.Schema({
  title: { type: String, required: true },
  originalFilename: { type: String, required: true },
  mimeType: { type: String, required: true },
  storagePath: { type: String, required: true },
  size: { type: Number, required: true },
  extractedText: { type: String, required: true },
  pages: [{
    pageNumber: { type: Number, required: true },
    text: { type: String, required: true }
  }],
  uploadedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
  createdAt: { type: Date, default: Date.now }
});

module.exports = mongoose.model('Document', DocumentSchema);
