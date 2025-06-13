const request = require('supertest');
const app = require('../server');

describe('Magic Eight Ball API', () => {
  describe('GET /health', () => {
    it('should return healthy status', async () => {
      const response = await request(app)
        .get('/health')
        .expect(200);

      expect(response.body).toHaveProperty('status', 'healthy');
      expect(response.body).toHaveProperty('timestamp');
    });
  });

  describe('POST /api/ask', () => {
    it('should return a magic eight ball response', async () => {
      const question = 'Will this test pass?';
      
      const response = await request(app)
        .post('/api/ask')
        .send({ question })
        .expect(200);

      expect(response.body).toHaveProperty('question', question);
      expect(response.body).toHaveProperty('response');
      expect(response.body).toHaveProperty('timestamp');
      expect(typeof response.body.response).toBe('string');
    });

    it('should return 400 for empty question', async () => {
      const response = await request(app)
        .post('/api/ask')
        .send({ question: '' })
        .expect(400);

      expect(response.body).toHaveProperty('error', 'Question is required');
    });

    it('should return 400 for missing question', async () => {
      const response = await request(app)
        .post('/api/ask')
        .send({})
        .expect(400);

      expect(response.body).toHaveProperty('error', 'Question is required');
    });
  });

  describe('GET /api/history', () => {
    it('should return history of questions', async () => {
      const response = await request(app)
        .get('/api/history')
        .expect(200);

      expect(Array.isArray(response.body)).toBe(true);
    });
  });

  describe('GET /', () => {
    it('should serve the main page', async () => {
      const response = await request(app)
        .get('/')
        .expect(200);

      expect(response.headers['content-type']).toContain('text/html');
    });
  });
}); 