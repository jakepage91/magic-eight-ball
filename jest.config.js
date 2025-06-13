module.exports = {
  testEnvironment: 'node',
  testTimeout: 30000,
  setupFilesAfterEnv: ['<rootDir>/test-setup.js'],
  testMatch: ['**/__tests__/**/*.test.js'],
  verbose: true,
  collectCoverage: false,
  forceExit: true,
  detectOpenHandles: true
}; 