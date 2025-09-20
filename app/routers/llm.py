"""
Роутер для работы с LLM API
"""

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import Dict, Any
import logging

from app.services.openai_module import LLMClient
from app.services.analyzer import SiteAnalyzer

# Настройка логирования
logger = logging.getLogger(__name__)

# Создаем роутер
router = APIRouter()

# Создаем экземпляр клиента LLM
llm_client = LLMClient()

# Создаем экземпляр анализатора сайтов
site_analyzer = SiteAnalyzer()

# Модели для запросов
class ChatRequest(BaseModel):
    prompt: str

class ChatWithSystemRequest(BaseModel):
    system_prompt: str
    user_prompt: str

class ChatJsonRequest(BaseModel):
    system_prompt: str
    user_prompt: str
    json_standard: str = ""

class AnalyzeRequest(BaseModel):
    url: str

@router.post("/chat")
async def chat(request: ChatRequest):
    """
    Простой запрос к LLM
    
    Args:
        request: Объект с промптом
        
    Returns:
        Ответ от LLM
    """
    try:
        logger.info(f"Получен запрос на простой чат: {request.prompt[:50]}...")
        
        response = llm_client.chat(request.prompt)
        
        logger.info("Запрос выполнен успешно")
        return {"response": response}
        
    except Exception as e:
        logger.error(f"Ошибка при выполнении простого чата: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Ошибка при выполнении запроса: {str(e)}")

@router.post("/chat-with-system")
async def chat_with_system(request: ChatWithSystemRequest):
    """
    Запрос к LLM с системным промптом
    
    Args:
        request: Объект с системным и пользовательским промптами
        
    Returns:
        Ответ от LLM
    """
    try:
        logger.info(f"Получен запрос с системным промптом: {request.user_prompt[:50]}...")
        
        response = llm_client.chat_with_system(
            request.system_prompt, 
            request.user_prompt
        )
        
        logger.info("Запрос с системным промптом выполнен успешно")
        return {"response": response}
        
    except Exception as e:
        logger.error(f"Ошибка при выполнении запроса с системным промптом: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Ошибка при выполнении запроса: {str(e)}")

@router.post("/chat-json")
async def chat_json(request: ChatJsonRequest):
    """
    Запрос к LLM с системным промптом и парсингом ответа в JSON
    
    Args:
        request: Объект с системным промптом, пользовательским промптом и стандартом JSON
        
    Returns:
        Ответ от LLM в виде словаря
    """
    try:
        logger.info(f"Получен JSON запрос: {request.user_prompt[:50]}...")
        
        # Если указан json_standard, добавляем его к системному промпту
        system_prompt = request.system_prompt
        if request.json_standard:
            system_prompt = f"{system_prompt}\n\nСтандарт JSON: {request.json_standard}"
        
        response = llm_client.chat_json(system_prompt, request.user_prompt)
        
        logger.info("JSON запрос выполнен успешно")
        return {"response": response}
        
    except Exception as e:
        logger.error(f"Ошибка при выполнении JSON запроса: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Ошибка при выполнении JSON запроса: {str(e)}")

@router.post("/analyze-site")
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
