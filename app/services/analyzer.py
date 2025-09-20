"""
Сервис для анализа веб-сайтов
"""

import requests
from bs4 import BeautifulSoup
from typing import List, Dict, Any
import logging

from app.services.openai_module import LLMClient

logger = logging.getLogger(__name__)


class SiteAnalyzer:
    """
    Класс для анализа веб-сайтов и генерации вопросов
    """
    
    def __init__(self):
        """
        Инициализация анализатора сайтов
        """
        try:
            self.llm_client = LLMClient()
            self.llm_available = True
            logger.info("LLM клиент успешно инициализирован")
        except Exception as e:
            logger.warning(f"LLM клиент недоступен: {str(e)}")
            self.llm_client = None
            self.llm_available = False
        
        self.session = requests.Session()
        self.session.headers.update({
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
        })
    
    def download_html(self, url: str) -> str:
        """
        Скачивает HTML-код сайта по URL
        
        Args:
            url (str): URL сайта для скачивания
            
        Returns:
            str: HTML-код сайта
            
        Raises:
            Exception: Если не удалось скачать сайт
        """
        try:
            logger.info(f"Скачивание HTML с URL: {url}")
            
            response = self.session.get(url, timeout=30)
            response.raise_for_status()
            
            logger.info(f"HTML успешно скачан, размер: {len(response.text)} символов")
            return response.text
            
        except requests.exceptions.RequestException as e:
            logger.error(f"Ошибка при скачивании сайта {url}: {str(e)}")
            raise Exception(f"Не удалось скачать сайт: {str(e)}")
    
    def extract_text_from_html(self, html: str) -> str:
        """
        Извлекает текст из HTML, удаляя все теги
        
        Args:
            html (str): HTML-код
            
        Returns:
            str: Очищенный текст
        """
        try:
            logger.info("Извлечение текста из HTML")
            
            soup = BeautifulSoup(html, 'html.parser')
            
            # Удаляем скрипты и стили
            for script in soup(["script", "style"]):
                script.decompose()
            
            # Получаем текст
            text = soup.get_text()
            
            # Очищаем от лишних пробелов и переносов строк
            lines = (line.strip() for line in text.splitlines())
            chunks = (phrase.strip() for line in lines for phrase in line.split("  "))
            text = ' '.join(chunk for chunk in chunks if chunk)
            
            logger.info(f"Текст извлечен, длина: {len(text)} символов")
            return text
            
        except Exception as e:
            logger.error(f"Ошибка при извлечении текста из HTML: {str(e)}")
            raise Exception(f"Не удалось извлечь текст из HTML: {str(e)}")
    
    def generate_questions(self, text: str) -> List[str]:
        """
        Генерирует список из 5 вопросов на основе текста сайта
        
        Args:
            text (str): Текст сайта
            
        Returns:
            List[str]: Список из 5 вопросов
        """
        # Если LLM недоступен, сразу возвращаем резервные вопросы
        if not self.llm_available:
            logger.info("LLM недоступен, используем резервные вопросы")
            return self._generate_fallback_questions()
        
        try:
            logger.info("Генерация вопросов с помощью LLM")
            
            system_prompt = """Ты пользователь сайта. Вот текст сайта: {site_text}

В ответе в формате JSON выдай список из 5 вопросов, которые возникли после посещения сайта.

Формат ответа:
{{
    "questions": [
        "Вопрос 1",
        "Вопрос 2", 
        "Вопрос 3",
        "Вопрос 4",
        "Вопрос 5"
    ]
}}"""

            user_prompt = f"Проанализируй текст сайта и сформулируй 5 вопросов, которые могут возникнуть у пользователя после его изучения."
            
            # Ограничиваем длину текста для промпта (чтобы не превысить лимиты токенов)
            if len(text) > 8000:
                text = text[:8000] + "..."
            
            formatted_system_prompt = system_prompt.format(site_text=text)
            
            response = self.llm_client.chat_json(formatted_system_prompt, user_prompt)
            
            # Извлекаем вопросы из ответа
            if isinstance(response, dict) and "questions" in response:
                questions = response["questions"]
                if isinstance(questions, list) and len(questions) >= 5:
                    logger.info("Вопросы успешно сгенерированы")
                    return questions[:5]  # Берем первые 5 вопросов
                else:
                    logger.warning("LLM вернул некорректный формат вопросов")
                    return self._generate_fallback_questions()
            else:
                logger.warning("LLM вернул некорректный ответ")
                return self._generate_fallback_questions()
                
        except Exception as e:
            logger.error(f"Ошибка при генерации вопросов: {str(e)}")
            return self._generate_fallback_questions()
    
    def _generate_fallback_questions(self) -> List[str]:
        """
        Генерирует резервные вопросы в случае ошибки LLM
        
        Returns:
            List[str]: Список из 5 стандартных вопросов
        """
        return [
            "Какова основная цель этого сайта?",
            "Какие услуги или продукты предлагаются?",
            "Как связаться с компанией?",
            "Какие есть способы оплаты?",
            "Есть ли скидки или специальные предложения?"
        ]
    
    def analyze_site(self, url: str) -> Dict[str, Any]:
        """
        Полный анализ сайта: скачивание, извлечение текста и генерация вопросов
        
        Args:
            url (str): URL сайта для анализа
            
        Returns:
            Dict[str, Any]: Результат анализа с URL и списком вопросов
            
        Raises:
            Exception: Если анализ не удался
        """
        try:
            logger.info(f"Начало анализа сайта: {url}")
            
            # Скачиваем HTML
            html = self.download_html(url)
            
            # Извлекаем текст
            text = self.extract_text_from_html(html)
            
            if not text.strip():
                raise Exception("Не удалось извлечь текст из сайта")
            
            # Генерируем вопросы
            questions = self.generate_questions(text)
            
            result = {
                "url": url,
                "questions": questions
            }
            
            logger.info(f"Анализ сайта {url} завершен успешно")
            return result
            
        except Exception as e:
            logger.error(f"Ошибка при анализе сайта {url}: {str(e)}")
            raise Exception(f"Ошибка при анализе сайта: {str(e)}")
