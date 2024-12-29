const express = require('express');
const app = express();
const apiRoutes = require('./routes/api');
const bodyParser = require('body-parser');
const mongoose = require('mongoose');
require('dotenv').config();
const dbURI = process.env.DATABASE_URL;

// Middleware
app.use(bodyParser.json());

// Routes
app.use('/api', apiRoutes);

// Connect to Database
mongoose.connect(dbURI, { useNewUrlParser: true, useUnifiedTopology: true })
	.then(() => console.log('Connected to MongoDB'))
	.catch(err => {
		console.error('MongoDB connection error:', err);
		process.exit(1);
	});

// Start the Server
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
	console.log(`Server is running on port ${PORT}`);
});