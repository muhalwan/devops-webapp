const mongoose = require('mongoose');
const app = require('./app');
const env = require('./config/env');

const PORT = env.PORT || 3000; // Default to port 3000 if PORT is not set
const DATABASE_URL = env.DATABASE_URL;

// Connect to MongoDB
mongoose
  .connect(DATABASE_URL, {
    useNewUrlParser: true,
    useUnifiedTopology: true,
  })
  .then(() => {
    console.log('✅ Database connected successfully');
    // Start the server only after successful DB connection
    app.listen(PORT, '0.0.0.0', () => {
      console.log(`🚀 Server is running on port ${PORT}`);
    });
  })
  .catch((err) => {
    console.error('❌ Database connection error:', err);
    process.exit(1);
  });