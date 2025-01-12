const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const morgan = require('morgan');
const apiRoutes = require('./routes/api');

const app = express();

// Middleware
app.use(helmet()); // Enhance security
app.use(cors()); // Enable CORS
app.use(morgan('combined')); // HTTP request logging
app.use(express.json()); // Parse JSON bodies

// Routes
app.use('/api', apiRoutes);

// Handle undefined routes
app.use((req, res) => {
  res.status(404).json({ message: 'Route not found' });
});

// Global Error Handler
app.use((err, req, res, next) => {
  console.error('❌ Global Error Handler:', err.stack);
  res.status(500).json({ message: 'Internal Server Error' });
});

module.exports = app;
