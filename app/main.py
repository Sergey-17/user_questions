"""
FastAPI приложение для работы с LLM
"""

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from app.routers import llm
from app.services.analyzer import SiteAnalyzer
import logging

# Настройка логирования
logger = logging.getLogger(__name__)

# Создаем экземпляр FastAPI приложения
app = FastAPI(
    title="LLM API",
    description="API для работы с языковыми моделями",
    version="1.0.0"
)

# Настройка CORS для фронтенда
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:5173", "http://127.0.0.1:5173"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Подключаем роутер для работы с LLM
app.include_router(llm.router, prefix="/api/v1", tags=["LLM"])

# Создаем экземпляр анализатора сайтов
site_analyzer = SiteAnalyzer()

# Модель для запроса анализа сайта
class AnalyzeRequest(BaseModel):
    url: str

@app.get("/")
async def root():
    """Корневой эндпоинт"""
    return {"message": "LLM API работает!", "version": "1.0.0"}

@app.get("/health")
async def health_check():
    """Проверка состояния API"""
    return {"status": "healthy", "service": "LLM API"}

@app.post("/analyze-site")
async def analyze_site(request: AnalyzeRequest) -> dict:
    """
    Анализ сайта и генерация вопросов
    
    Args:
        request: Объект с URL сайта для анализа
        
    Returns:
        dict: Результат анализа с URL и списком вопросов
    """
    try:
        logger.info(f"Получен запрос на анализ сайта: {request.url}")
        
        result = site_analyzer.analyze_site(request.url)
        
        logger.info("Анализ сайта выполнен успешно")
        return result
        
    except Exception as e:
        logger.error(f"Ошибка при анализе сайта {request.url}: {str(e)}")
        raise HTTPException(status_code=400, detail=f"Ошибка при анализе сайта: {str(e)}")
