"""
Модуль для веб-скрапинга и извлечения текста из HTML.
"""

import asyncio
import aiohttp
from typing import Optional
import logging
from tenacity import retry, stop_after_attempt, wait_exponential, retry_if_exception_type

from bs4 import BeautifulSoup
from exceptions import ScrapingError

logger = logging.getLogger(__name__)


class WebScraper:
    """Класс для загрузки и извлечения текста из веб-страниц."""
    
    def __init__(self, timeout: int = 30, max_retries: int = 3):
        """
        Инициализация скрапера.
        
        Args:
            timeout: Таймаут запроса в секундах
            max_retries: Максимальное количество попыток
        """
        self.timeout = timeout
        self.max_retries = max_retries
        
        # Заголовки для имитации браузера
        self.headers = {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
            'Accept-Language': 'ru-RU,ru;q=0.8,en-US;q=0.5,en;q=0.3',
            'Accept-Encoding': 'gzip, deflate',
            'Connection': 'keep-alive',
            'Upgrade-Insecure-Requests': '1',
        }
    
    @retry(
        stop=stop_after_attempt(3),
        wait=wait_exponential(multiplier=1, min=2, max=10),
        retry=retry_if_exception_type((aiohttp.ClientError, asyncio.TimeoutError))
    )
    async def extract_text(self, url: str) -> str:
        """
        Загружает HTML и извлекает текстовое содержимое.
        
        Args:
            url: URL страницы для загрузки
            
        Returns:
            Извлеченный текст
            
        Raises:
            ScrapingError: Ошибка при загрузке или обработке страницы
        """
        try:
            logger.info(f"Загружаю страницу: {url}")
            
            async with aiohttp.ClientSession(
                timeout=aiohttp.ClientTimeout(total=self.timeout),
                headers=self.headers
            ) as session:
                
                async with session.get(url) as response:
                    if response.status != 200:
                        raise ScrapingError(f"HTTP {response.status}: {response.reason}")
                    
                    # Проверяем тип контента
                    content_type = response.headers.get('content-type', '').lower()
                    if 'text/html' not in content_type:
                        raise ScrapingError(f"Неверный тип контента: {content_type}")
                    
                    # Читаем HTML
                    html_content = await response.text()
                    
                    if not html_content:
                        raise ScrapingError("Пустой HTML контент")
                    
                    logger.info(f"Загружено {len(html_content)} символов HTML")
                    
                    # Извлекаем текст
                    text_content = self._extract_text_from_html(html_content)
                    
                    if not text_content or len(text_content.strip()) < 50:
                        raise ScrapingError("Не удалось извлечь достаточное количество текста")
                    
                    return text_content
                    
        except aiohttp.ClientError as e:
            raise ScrapingError(f"Ошибка HTTP клиента: {str(e)}")
        except asyncio.TimeoutError:
            raise ScrapingError(f"Таймаут при загрузке {url}")
        except Exception as e:
            raise ScrapingError(f"Неожиданная ошибка при загрузке: {str(e)}")
    
    def _extract_text_from_html(self, html_content: str) -> str:
        """
        Извлекает текстовое содержимое из HTML.
        
        Args:
            html_content: HTML контент
            
        Returns:
            Извлеченный текст
        """
        try:
            # Парсим HTML
            soup = BeautifulSoup(html_content, 'html.parser')
            
            # Удаляем скрипты и стили
            for script in soup(["script", "style", "nav", "header", "footer", "aside"]):
                script.decompose()
            
            # Удаляем комментарии
            for comment in soup.find_all(string=lambda text: isinstance(text, str) and text.strip().startswith('<!--')):
                comment.extract()
            
            # Извлекаем текст
            text = soup.get_text()
            
            # Очищаем текст
            lines = (line.strip() for line in text.splitlines())
            chunks = (phrase.strip() for line in lines for phrase in line.split("  "))
            text = ' '.join(chunk for chunk in chunks if chunk)
            
            # Убираем лишние пробелы
            text = ' '.join(text.split())
            
            return text
            
        except Exception as e:
            logger.error(f"Ошибка при парсинге HTML: {str(e)}")
            # Возвращаем сырой текст если парсинг не удался
            return html_content
    
    async def close(self):
        """Закрывает ресурсы скрапера."""
        # В текущей реализации ресурсы закрываются автоматически
        pass
