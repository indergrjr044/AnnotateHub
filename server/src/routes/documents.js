const express = require('express');
const router = express.Router();
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const pdfParse = require('pdf-parse');
const authMiddleware = require('../middleware/auth');
const Document = require('../models/Document');
const { saveFile, deleteFile, uploadDir } = require('../services/storage');
const { asyncHandler } = require('../middleware/errorHandler');

// Configure Multer
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, uploadDir);
  },
  filename: (req, file, cb) => {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1e9);
    cb(null, file.fieldname + '-' + uniqueSuffix + path.extname(file.originalname));
  }
});

const fileFilter = (req, file, cb) => {
  const allowedTypes = ['text/plain', 'application/pdf'];
  const ext = path.extname(file.originalname).toLowerCase();
  
  if (allowedTypes.includes(file.mimetype)) {
    cb(null, true);
  } else if ((file.mimetype === 'application/octet-stream' || !file.mimetype) && (ext === '.txt' || ext === '.pdf')) {
    // Override mimetype based on file extension fallback
    file.mimetype = ext === '.txt' ? 'text/plain' : 'application/pdf';
    cb(null, true);
  } else {
    cb(new Error('Invalid file type. Only text/plain and application/pdf are supported.'), false);
  }
};

const upload = multer({
  storage: storage,
  limits: { fileSize: 10 * 1024 * 1024 }, // 10MB limit
  fileFilter: fileFilter
});

// Helper: Extract text from PDF per page
const parsePdfPerPage = async (filePath) => {
  const dataBuffer = fs.readFileSync(filePath);
  const pages = [];
  
  const options = {
    pagerender: function (pageData) {
      return pageData.getTextContent().then((textContent) => {
        let lastY, text = '';
        for (let item of textContent.items) {
          if (lastY === item.transform[5] || !lastY) {
            text += item.str + ' ';
          } else {
            text += '\n' + item.str + ' ';
          }
          lastY = item.transform[5];
        }
        pages.push({
          pageNumber: pageData.pageIndex + 1,
          text: text
        });
        return text;
      });
    }
  };

  const data = await pdfParse(dataBuffer, options);
  // Sort pages chronologically since rendering resolves asynchronously
  pages.sort((a, b) => a.pageNumber - b.pageNumber);

  return {
    extractedText: data.text,
    pages
  };
};

// POST /api/documents/upload
// Note: We catch Multer errors (like fileSize limit) by running upload.single as a custom middleware
router.post('/upload', authMiddleware, (req, res, next) => {
  upload.single('file')(req, res, async (err) => {
    if (err) {
      return res.status(400).json({ error: 'UploadError', message: err.message });
    }
    
    if (!req.file) {
      return res.status(400).json({ error: 'UploadError', message: 'No file uploaded.' });
    }

    try {
      const storageInfo = await saveFile(req.file);
      let extractedText = '';
      let pages = [];

      if (req.file.mimetype === 'text/plain') {
        extractedText = fs.readFileSync(req.file.path, 'utf8');
      } else if (req.file.mimetype === 'application/pdf') {
        const parsed = await parsePdfPerPage(req.file.path);
        extractedText = parsed.extractedText;
        pages = parsed.pages;
      }

      const doc = new Document({
        title: req.body.title || req.file.originalname,
        originalFilename: storageInfo.originalFilename,
        mimeType: storageInfo.mimeType,
        storagePath: storageInfo.storagePath,
        size: storageInfo.size,
        extractedText,
        pages,
        uploadedBy: req.user.id
      });

      await doc.save();
      
      res.status(201).json({
        id: doc._id,
        title: doc.title,
        originalFilename: doc.originalFilename,
        mimeType: doc.mimeType,
        size: doc.size,
        createdAt: doc.createdAt,
        extractedText: doc.extractedText,
        pages: doc.pages
      });
    } catch (parseError) {
      // Clean up uploaded file on failure
      await deleteFile(req.file.path);
      next(parseError);
    }
  });
});

// GET /api/documents
router.get('/', authMiddleware, asyncHandler(async (req, res) => {
  // Omit extractedText and pages for lightweight listing
  const docs = await Document.find()
    .select('-extractedText -pages')
    .sort({ createdAt: -1 })
    .populate('uploadedBy', 'name email');

  res.json(docs);
}));

// GET /api/documents/:id
router.get('/:id', authMiddleware, asyncHandler(async (req, res) => {
  const doc = await Document.findById(req.params.id)
    .populate('uploadedBy', 'name email');

  if (!doc) {
    return res.status(404).json({ error: 'NotFound', message: 'Document not found.' });
  }

  res.json(doc);
}));

// DELETE /api/documents/:id
router.delete('/:id', authMiddleware, asyncHandler(async (req, res) => {
  const doc = await Document.findById(req.params.id);
  if (!doc) {
    return res.status(404).json({ error: 'NotFound', message: 'Document not found.' });
  }

  // Ownership verification
  if (doc.uploadedBy.toString() !== req.user.id) {
    return res.status(403).json({ error: 'Forbidden', message: 'Only the uploader can delete this document.' });
  }

  // Clean up physical file on disk
  await deleteFile(doc.storagePath);

  // Remove document record from database
  await Document.findByIdAndDelete(req.params.id);

  // Clean up all annotations associated with this document
  const Annotation = require('../models/Annotation');
  await Annotation.deleteMany({ documentId: req.params.id });

  res.json({ success: true, message: 'Document and its annotations deleted successfully.' });
}));

module.exports = router;
