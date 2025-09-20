import axios from 'axios';

// Конфигурация API
const API_BASE_URL = 'http://localhost:8000';
const API_ENDPOINT = '/analyze-site';

// Состояние приложения
let isAnalyzing = false;

// Переменные для элементов DOM (будут инициализированы после загрузки DOM)
let urlInput, analyzeBtn, btnText, btnLoader, resultsSection, resultsContent, errorSection, errorText, globalLoader;

// Инициализация
document.addEventListener('DOMContentLoaded', () => {
    // Получаем элементы DOM после загрузки
    urlInput = document.getElementById('urlInput');
    analyzeBtn = document.getElementById('analyzeBtn');
    btnText = document.querySelector('.btn-text');
    btnLoader = document.querySelector('.btn-loader');
    resultsSection = document.getElementById('results');
    resultsContent = document.getElementById('resultsContent');
    errorSection = document.getElementById('error');
    errorText = document.getElementById('errorText');
    globalLoader = document.getElementById('globalLoader');
    
    setupEventListeners();
});

// Настройка обработчиков событий
function setupEventListeners() {
    if (analyzeBtn) {
        analyzeBtn.addEventListener('click', handleAnalyze);
    }
    
    if (urlInput) {
        urlInput.addEventListener('keypress', (e) => {
            if (e.key === 'Enter' && !isAnalyzing) {
                handleAnalyze();
            }
        });
        
        // Валидация URL в реальном времени
        urlInput.addEventListener('input', validateUrl);
    }
}

// Валидация URL
function validateUrl() {
    const url = urlInput.value.trim();
    const isValid = url && isValidUrl(url);
    
    analyzeBtn.disabled = !isValid || isAnalyzing;
    
    if (url && !isValid) {
        urlInput.style.borderColor = '#dc3545';
    } else {
        urlInput.style.borderColor = '#e1e5e9';
    }
}

// Проверка валидности URL
function isValidUrl(string) {
    try {
        const url = new URL(string);
        return url.protocol === 'http:' || url.protocol === 'https:';
    } catch (_) {
        return false;
    }
}

// Основная функция анализа
async function handleAnalyze() {
    const url = urlInput.value.trim();
    
    if (!url || !isValidUrl(url) || isAnalyzing) {
        return;
    }
    
    try {
        setAnalyzingState(true);
        hideResults();
        hideError();
        
        const response = await axios.post(`${API_BASE_URL}${API_ENDPOINT}`, {
            url: url
        }, {
            timeout: 30000, // 30 секунд таймаут
            headers: {
                'Content-Type': 'application/json'
            }
        });
        
        displayResults(response.data);
        
    } catch (error) {
        console.error('Ошибка при анализе:', error);
        handleError(error);
    } finally {
        setAnalyzingState(false);
    }
}

// Установка состояния анализа
function setAnalyzingState(analyzing) {
    isAnalyzing = analyzing;
    
    if (analyzing) {
        analyzeBtn.disabled = true;
        btnText.classList.add('hidden');
        btnLoader.classList.remove('hidden');
        globalLoader.classList.remove('hidden');
    } else {
        analyzeBtn.disabled = false;
        btnText.classList.remove('hidden');
        btnLoader.classList.add('hidden');
        globalLoader.classList.add('hidden');
    }
}

// Отображение результатов
function displayResults(data) {
    resultsContent.innerHTML = '';
    
    // Проверяем, есть ли вопросы в ответе
    if (data.questions && Array.isArray(data.questions)) {
        // Отображаем вопросы
        const questionsBlock = createResultBlock(
            'Вопросы по сайту', 
            '❓', 
            createQuestionsContent(data.questions)
        );
        resultsContent.appendChild(questionsBlock);
    } else {
        // Если нет вопросов, показываем ошибку
        const errorBlock = createResultBlock(
            'Ошибка анализа', 
            '⚠️', 
            '<p>Не удалось сгенерировать вопросы для данного сайта.</p>'
        );
        resultsContent.appendChild(errorBlock);
    }
    
    resultsSection.classList.remove('hidden');
    
    // Плавная прокрутка к результатам
    setTimeout(() => {
        resultsSection.scrollIntoView({ 
            behavior: 'smooth', 
            block: 'start' 
        });
    }, 100);
}

// Создание блока результата
function createResultBlock(title, icon, content) {
    const block = document.createElement('div');
    block.className = 'result-block';
    
    block.innerHTML = `
        <div class="result-title">
            <div class="result-icon">${icon}</div>
            ${title}
        </div>
        <div class="result-content">${content}</div>
    `;
    
    return block;
}

// Создание контента для вопросов
function createQuestionsContent(questions) {
    let content = '<p><strong>Вот вопросы, которые могут возникнуть у пользователей после изучения сайта:</strong></p><ol>';
    
    questions.forEach((question, index) => {
        content += `<li>${question}</li>`;
    });
    
    content += '</ol>';
    
    return content;
}


// Обработка ошибок
function handleError(error) {
    let errorMessage = 'Произошла неизвестная ошибка';
    
    if (error.response) {
        // Ошибка от сервера
        const status = error.response.status;
        const data = error.response.data;
        
        switch (status) {
            case 400:
                errorMessage = 'Некорректный запрос. Проверьте URL.';
                break;
            case 404:
                errorMessage = 'Страница не найдена. Проверьте URL.';
                break;
            case 500:
                errorMessage = 'Ошибка сервера. Попробуйте позже.';
                break;
            default:
                errorMessage = data?.detail || `Ошибка сервера (${status})`;
        }
    } else if (error.request) {
        // Ошибка сети
        errorMessage = 'Ошибка сети. Проверьте подключение к интернету и доступность сервера.';
    } else if (error.code === 'ECONNABORTED') {
        // Таймаут
        errorMessage = 'Превышено время ожидания ответа. Попробуйте позже.';
    }
    
    showError(errorMessage);
}

// Показать ошибку
function showError(message) {
    errorText.textContent = message;
    errorSection.classList.remove('hidden');
    
    // Плавная прокрутка к ошибке
    setTimeout(() => {
        errorSection.scrollIntoView({ 
            behavior: 'smooth', 
            block: 'start' 
        });
    }, 100);
}

// Скрыть результаты
function hideResults() {
    resultsSection.classList.add('hidden');
    resultsContent.innerHTML = '';
}

// Скрыть ошибку
function hideError() {
    errorSection.classList.add('hidden');
}
