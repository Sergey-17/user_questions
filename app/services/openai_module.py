import os
import json
from openai import OpenAI
from dotenv import load_dotenv


class LLMClient:
    """
    Клиент для работы с LLM через Proxy API
    """
    
    def __init__(self):
        """
        Инициализация клиента с загрузкой параметров из .env файла
        """
        # Загружаем переменные окружения из .env файла
        load_dotenv()
        
        # Обязательные параметры
        self.api_key = os.environ.get("OPENAI_API_KEY")
        self.base_url = os.environ.get("OPENAI_BASE_URL", "https://openai.api.proxyapi.ru/v1")
        self.model = os.environ.get("OPENAI_MODEL", "gpt-4o")
        
        # Необязательные параметры
        self.system_prompt = os.environ.get("OPENAI_SYSTEM_PROMPT", "")
        self.max_tokens = int(os.environ.get("OPENAI_MAX_TOKENS", "1000"))
        
        # Проверяем наличие обязательных параметров
        if not self.api_key:
            raise ValueError("OPENAI_API_KEY не найден в переменных окружения")
        
        # Создаем клиент OpenAI
        self.client = OpenAI(
            api_key=self.api_key,
            base_url=self.base_url
        )
    
    def set_system_prompt(self, system_prompt: str):
        """
        Динамически изменить системный промпт
        
        Args:
            system_prompt (str): Новый системный промпт
        """
        self.system_prompt = system_prompt
    
    def set_max_tokens(self, max_tokens: int):
        """
        Динамически изменить максимальное количество токенов
        
        Args:
            max_tokens (int): Новое максимальное количество токенов
        """
        self.max_tokens = max_tokens
    
    def chat(self, prompt: str) -> str:
        """
        Простой запрос к LLM
        
        Args:
            prompt (str): Пользовательский промпт
            
        Returns:
            str: Ответ от LLM
        """
        try:
            chat_completion = self.client.chat.completions.create(
                model=self.model,
                messages=[
                    {
                        "role": "user",
                        "content": prompt
                    }
                ],
                max_tokens=self.max_tokens
            )
            
            return chat_completion.choices[0].message.content
            
        except Exception as e:
            raise Exception(f"Ошибка при выполнении запроса: {str(e)}")
    
    def chat_with_system(self, system_prompt: str, user_prompt: str) -> str:
        """
        Запрос к LLM с системным промптом
        
        Args:
            system_prompt (str): Системный промпт
            user_prompt (str): Пользовательский промпт
            
        Returns:
            str: Ответ от LLM
        """
        try:
            chat_completion = self.client.chat.completions.create(
                model=self.model,
                messages=[
                    {
                        "role": "system",
                        "content": system_prompt
                    },
                    {
                        "role": "user",
                        "content": user_prompt
                    }
                ],
                max_tokens=self.max_tokens
            )
            
            return chat_completion.choices[0].message.content
            
        except Exception as e:
            raise Exception(f"Ошибка при выполнении запроса с системным промптом: {str(e)}")
    
    def chat_json(self, system_prompt: str, user_prompt: str, json_standard: str = "json") -> dict:
        """
        Запрос к LLM с системным промптом и парсингом ответа в JSON
        
        Args:
            system_prompt (str): Системный промпт
            user_prompt (str): Пользовательский промпт
            json_standard (str): Стандарт JSON (по умолчанию "json")
            
        Returns:
            dict: Ответ от LLM в виде Python словаря
        """
        try:
            # Добавляем инструкцию для JSON ответа к системному промпту
            json_system_prompt = f"{system_prompt}\n\nОтветь строго в формате JSON."
            
            chat_completion = self.client.chat.completions.create(
                model=self.model,
                messages=[
                    {
                        "role": "system",
                        "content": json_system_prompt
                    },
                    {
                        "role": "user",
                        "content": user_prompt
                    }
                ],
                max_tokens=self.max_tokens
            )
            
            response_content = chat_completion.choices[0].message.content
            
            # Пытаемся распарсить JSON
            try:
                # Убираем markdown блоки если есть
                json_content = response_content.strip()
                if json_content.startswith("```json"):
                    json_content = json_content[7:]  # Убираем ```json
                if json_content.endswith("```"):
                    json_content = json_content[:-3]  # Убираем ```
                json_content = json_content.strip()
                
                return json.loads(json_content)
            except json.JSONDecodeError:
                # Если не удалось распарсить JSON, возвращаем как строку
                return {"response": response_content, "error": "Не удалось распарсить JSON"}
            
        except Exception as e:
            raise Exception(f"Ошибка при выполнении JSON запроса: {str(e)}")


if __name__ == "__main__":
    """
    Тестовые запуски методов
    """
    try:
        # Создаем экземпляр клиента
        print("Создание клиента LLM...")
        client = LLMClient()
        print("Клиент успешно создан!")
        
        # Тест 1: Простой запрос
        print("\n=== Тест 1: Простой запрос ===")
        response1 = client.chat("Привет! Как дела?")
        print(f"Ответ: {response1}")
        
        # Тест 2: Запрос с системным промптом
        print("\n=== Тест 2: Запрос с системным промптом ===")
        system_prompt = "Ты полезный ассистент, который отвечает кратко и по делу."
        user_prompt = "Объясни, что такое искусственный интеллект в двух предложениях."
        response2 = client.chat_with_system(system_prompt, user_prompt)
        print(f"Ответ: {response2}")
        
        # Тест 3: JSON запрос
        print("\n=== Тест 3: JSON запрос ===")
        json_system_prompt = "Ты помощник для создания структурированных данных."
        json_user_prompt = "Создай информацию о городе Москва в формате JSON с полями: название, страна, население."
        response3 = client.chat_json(json_system_prompt, json_user_prompt)
        print(f"JSON ответ: {response3}")
        
        # Тест 4: Динамическое изменение параметров
        print("\n=== Тест 4: Динамическое изменение параметров ===")
        client.set_system_prompt("Ты поэт, который пишет стихи.")
        client.set_max_tokens(500)
        
        response4 = client.chat("Напиши короткое стихотворение о программировании.")
        print(f"Стихотворение: {response4}")
        
        print("\nВсе тесты выполнены успешно!")
        
    except Exception as e:
        print(f"Ошибка при выполнении тестов: {str(e)}")
        print("Убедитесь, что файл .env содержит необходимые переменные:")
        print("- OPENAI_API_KEY")
        print("- OPENAI_BASE_URL (опционально)")
        print("- OPENAI_MODEL (опционально)")
        print("- OPENAI_SYSTEM_PROMPT (опционально)")
        print("- OPENAI_MAX_TOKENS (опционально)")