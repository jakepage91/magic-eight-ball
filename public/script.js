class MagicEightBall {
    constructor() {
        this.eightBall = document.getElementById('eightBall');
        this.questionInput = document.getElementById('questionInput');
        this.askButton = document.getElementById('askButton');
        this.answerText = document.getElementById('answerText');
        this.loading = document.getElementById('loading');
        this.historyList = document.getElementById('historyList');
        
        this.initializeEventListeners();
        this.loadHistory();
    }

    initializeEventListeners() {
        this.askButton.addEventListener('click', () => this.askQuestion());
        this.eightBall.addEventListener('click', () => this.askQuestion());
        
        this.questionInput.addEventListener('keypress', (e) => {
            if (e.key === 'Enter') {
                this.askQuestion();
            }
        });

        this.questionInput.addEventListener('input', () => {
            this.askButton.disabled = this.questionInput.value.trim().length === 0;
        });
    }

    async askQuestion() {
        const question = this.questionInput.value.trim();
        
        if (!question) {
            this.showError('Please enter a question first!');
            return;
        }

        this.setLoading(true);
        this.shakeEightBall();

        try {
            const response = await fetch('/api/ask', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({ question })
            });

            if (!response.ok) {
                throw new Error(`HTTP error! status: ${response.status}`);
            }

            const data = await response.json();
            
            setTimeout(() => {
                this.displayAnswer(data.response);
                this.questionInput.value = '';
                this.loadHistory();
                this.setLoading(false);
            }, 1500); // Wait for shake animation to complete

        } catch (error) {
            console.error('Error asking question:', error);
            this.showError('Something went wrong. The spirits are not responding!');
            this.setLoading(false);
        }
    }

    shakeEightBall() {
        this.eightBall.classList.add('shaking');
        setTimeout(() => {
            this.eightBall.classList.remove('shaking');
        }, 800);
    }

    displayAnswer(answer) {
        this.answerText.textContent = answer;
        this.answerText.style.animation = 'none';
        setTimeout(() => {
            this.answerText.style.animation = 'fadeIn 0.5s ease-in';
        }, 10);
    }

    setLoading(isLoading) {
        this.loading.style.display = isLoading ? 'block' : 'none';
        this.askButton.disabled = isLoading || this.questionInput.value.trim().length === 0;
        
        if (isLoading) {
            this.answerText.textContent = 'Consulting the mystical forces...';
        }
    }

    showError(message) {
        this.answerText.textContent = message;
        this.answerText.style.color = '#ff6b6b';
        setTimeout(() => {
            this.answerText.style.color = 'white';
            this.answerText.textContent = 'Ask a question...';
        }, 3000);
    }

    async loadHistory() {
        try {
            const response = await fetch('/api/history');
            if (!response.ok) {
                throw new Error(`HTTP error! status: ${response.status}`);
            }
            
            const history = await response.json();
            this.displayHistory(history);
        } catch (error) {
            console.error('Error loading history:', error);
        }
    }

    displayHistory(history) {
        this.historyList.innerHTML = '';
        
        if (history.length === 0) {
            this.historyList.innerHTML = '<p style="text-align: center; color: #999;">No questions asked yet. Be the first!</p>';
            return;
        }

        history.forEach(item => {
            const historyItem = document.createElement('div');
            historyItem.className = 'history-item';
            
            const timestamp = new Date(item.asked_at).toLocaleString();
            
            historyItem.innerHTML = `
                <div class="question">Q: ${this.escapeHtml(item.question)}</div>
                <div class="response">A: ${this.escapeHtml(item.response)}</div>
                <div class="timestamp">${timestamp}</div>
            `;
            
            this.historyList.appendChild(historyItem);
        });
    }

    escapeHtml(text) {
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    }
}

// Add fade in animation CSS
const style = document.createElement('style');
style.textContent = `
    @keyframes fadeIn {
        from { opacity: 0; transform: scale(0.9); }
        to { opacity: 1; transform: scale(1); }
    }
`;
document.head.appendChild(style);

// Initialize the Magic Eight Ball when the page loads
document.addEventListener('DOMContentLoaded', () => {
    new MagicEightBall();
}); 