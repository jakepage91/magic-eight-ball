// Test setup configuration
process.env.NODE_ENV = 'test';

// Set test database configuration
if (!process.env.DATABASE_URL) {
  process.env.DATABASE_URL = 'postgresql://magic8ball:testpassword@localhost:5432/magic_eight_ball';
}
if (!process.env.DB_HOST) {
  process.env.DB_HOST = 'localhost';
}
if (!process.env.DB_PORT) {
  process.env.DB_PORT = '5432';
}
if (!process.env.DB_NAME) {
  process.env.DB_NAME = 'magic_eight_ball';
}
if (!process.env.DB_USER) {
  process.env.DB_USER = 'magic8ball';
}
if (!process.env.DB_PASSWORD) {
  process.env.DB_PASSWORD = 'testpassword';
}

// Global test timeout
jest.setTimeout(30000);

// Handle async operations cleanup
afterAll(async () => {
  // Close any open database connections
  try {
    const { pool } = require('./server');
    if (pool) {
      await pool.end();
    }
  } catch (error) {
    console.log('Error closing database connection:', error);
  }
}); 