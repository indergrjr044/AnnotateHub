const errorHandler = (err, req, res, next) => {
  console.error(err);

  // Mongoose Duplicate Key Error (compound unique index clash)
  if (err.code === 11000) {
    return res.status(409).json({
      error: 'DuplicateEntry',
      message: 'You have already created an annotation on this exact range.'
    });
  }

  // Mongoose Validation Error
  if (err.name === 'ValidationError') {
    return res.status(400).json({
      error: 'ValidationError',
      message: Object.values(err.errors).map(e => e.message).join(', ')
    });
  }

  // Cast Error (e.g., invalid ObjectId)
  if (err.name === 'CastError') {
    return res.status(400).json({
      error: 'InvalidId',
      message: `Invalid ID format for ${err.path}`
    });
  }

  // Default server error
  res.status(err.status || 500).json({
    error: 'InternalServerError',
    message: err.message || 'An unexpected server error occurred.'
  });
};

const asyncHandler = (fn) => (req, res, next) => {
  Promise.resolve(fn(req, res, next)).catch(next);
};

module.exports = { errorHandler, asyncHandler };
