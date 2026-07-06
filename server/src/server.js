require('dotenv').config();
const express = require('express');
const http = require('http');
const cors = require('cors');
const path = require('path');
const connectDB = require('./config/db');
const { initSocket } = require('./services/socket');
const { errorHandler } = require('./middleware/errorHandler');

// Initialize database connection
connectDB();

const app = express();
const server = http.createServer(app);

// Initialize Socket.io
initSocket(server);

// Middleware
app.use(cors({
  origin: '*', // Allow client connections
  methods: ['GET', 'POST', 'PATCH', 'DELETE', 'PUT'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Socket-ID']
}));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Serve Uploaded Files Statically
app.use('/uploads', express.static(path.join(__dirname, '../uploads')));

// Routes
const authRoutes = require('./routes/auth');
const documentRoutes = require('./routes/documents');
const annotationRoutes = require('./routes/annotations');

app.use('/api/auth', authRoutes);
app.use('/api/documents', documentRoutes);
app.use('/api', annotationRoutes);

// Root test endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'ok', time: new Date() });
});

// Serve Flutter Web Build Statically
const webBuildPath = path.join(__dirname, '../../flutter_client/build/web');
app.use(express.static(webBuildPath));

// Fallback routing for SPA history routing: serve index.html for any non-API route
app.get('*', (req, res, next) => {
  if (req.path.startsWith('/api') || req.path.startsWith('/uploads')) {
    return next();
  }
  res.sendFile(path.join(webBuildPath, 'index.html'));
});

// Centralized error handling middleware
app.use(errorHandler);

const PORT = process.env.PORT || 5000;
server.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
