const fs = require('fs');
const path = require('path');

const uploadDir = path.join(__dirname, '../../uploads');
if (!fs.existsSync(uploadDir)) {
  fs.mkdirSync(uploadDir, { recursive: true });
}

/**
 * Saves a file. Currently local storage, but can be swapped to S3.
 * @param {Express.Multer.File} file 
 * @returns {Promise<{storagePath: string, originalFilename: string, mimeType: string, size: number}>}
 */
const saveFile = async (file) => {
  // Multer already wrote the file to disk in local mode
  return {
    storagePath: file.path,
    originalFilename: file.originalname,
    mimeType: file.mimetype,
    size: file.size
  };
};

/**
 * Deletes a file.
 * @param {string} filePath 
 * @returns {Promise<void>}
 */
const deleteFile = async (filePath) => {
  try {
    if (fs.existsSync(filePath)) {
      fs.unlinkSync(filePath);
    }
  } catch (error) {
    console.error(`Failed to delete file at ${filePath}:`, error);
  }
};

module.exports = {
  saveFile,
  deleteFile,
  uploadDir
};
