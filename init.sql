-- Initialize the Magic Eight Ball database

-- Create questions table
CREATE TABLE IF NOT EXISTS questions (
    id SERIAL PRIMARY KEY,
    question TEXT NOT NULL,
    response TEXT NOT NULL,
    asked_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create index on asked_at for faster queries
CREATE INDEX IF NOT EXISTS idx_questions_asked_at ON questions (asked_at);

-- Insert some sample data for demonstration
INSERT INTO questions (question, response, asked_at) VALUES 
    ('Will this CI/CD demo go well?', 'Signs point to yes', NOW() - INTERVAL '1 hour'),
    ('Is Docker the future?', 'It is certain', NOW() - INTERVAL '30 minutes'),
    ('Should we use Terraform?', 'Most likely', NOW() - INTERVAL '15 minutes');

-- Create a view for recent questions (optional)
CREATE OR REPLACE VIEW recent_questions AS
SELECT 
    question,
    response,
    asked_at
FROM questions 
ORDER BY asked_at DESC 
LIMIT 10; 