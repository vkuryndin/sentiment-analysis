# Sentiment Analysis Service 1.0.1

Учебное Java-приложение для анализа тональности английского текста. Использует предварительно обученную модель fastText Yelp Review Polarity, а не mock. REST API возвращает `positive` или `negative`.

## Стек

Java 17, Spring Boot 4.1.2, Gradle 8.14.3 (Kotlin DSL), JFastText 0.5, Actuator, Micrometer Prometheus.

## Локальный запуск (Windows, PowerShell)

Требуются JDK 17 (64-bit), IntelliJ IDEA и интернет для первой загрузки зависимостей и модели. Выполните из корня распакованного проекта:

```powershell
powershell -ExecutionPolicy Bypass -File .\prepare.ps1
```

Скрипт скачивает официальные файлы Gradle Wrapper и модель `models/yelp_review_polarity.ftz`. Файлы Gradle Wrapper после загрузки можно добавить в Git. Файл модели исключён из Git до уточнения условий его распространения. При запуске без модели приложение завершится с ошибкой; фиктивного классификатора нет.

Откройте каталог проекта в IntelliJ IDEA как Gradle-проект; выберите JDK 17 для Project SDK и Gradle JVM. Рабочий каталог — корень проекта. Запуск: `SentimentApplication` либо из терминала:

```powershell
.\gradlew.bat bootRun
```

Приложение запускается на порту 8085.

## Проверки

Откройте `request.http` в IntelliJ IDEA и последовательно выполните 19 запросов. Для положительных и отрицательных отзывов указаны ожидаемые ответы модели. Классификация произвольного короткого текста может отличаться от человеческой оценки; `hello` не является гарантированно положительным примером.

Автоматические тесты (6 тестов сервиса и 7 HTTP-тестов с реальной моделью):

```powershell
.\gradlew.bat clean test
```

Отчёт: `build/reports/tests/test/index.html`.

## API

| Метод | Путь | Назначение |
|---|---|---|
| GET | `/api/sentiment?text=...&lang=en` | Анализ текста |
| POST | `/api/sentiment` | Анализ текста из JSON |
| GET | `/actuator/health` | Состояние приложения |
| GET | `/actuator/prometheus` | Метрики Prometheus |

Параметр `lang` необязателен в обоих методах, по умолчанию `en`. В версии 1.0 доступен только английский. Пустой текст, текст длиннее 2000 символов и неподдерживаемый язык дают HTTP 400. Автоматическое определение языка отсутствует. Пример ответа: `{"sentiment":"positive"}`.

Пример POST-запроса (IntelliJ HTTP Client):

```http
POST http://localhost:8085/api/sentiment
Content-Type: application/json

{
  "text": "Excellent food and friendly service. I absolutely loved this restaurant!",
  "lang": "en"
}
```

Для многострочного текста используйте `\n` внутри JSON-строки. Оба метода вызывают один сервис и учитываются одной метрикой.

## Модель и расширение

Модель загружается один раз при старте через `FastTextWrapper.FastTextApi`, поскольку высокоуровневый JFastText отклоняет формат версии 11. Перед вызовом предсказания добавляется символ окончания строки `\n`. Метки `__label__1` и `__label__2` соответствуют отрицательной и положительной тональности. Текст нормализуется по схеме обучения fastText. В `SentimentService` модели хранятся по языковому ключу; для русского языка позже можно добавить ещё один экземпляр `FastTextModel` с собственной картой меток и нормализацией. Путь к английской модели можно переопределить переменной среды `SENTIMENT_MODEL_EN_PATH`.

Дополнительная метрика `sentiment_predictions_total` содержит метки `language` и `sentiment`, появляется после первого успешного анализа. Стандартные метрики HTTP, CPU и JVM предоставляет Actuator.

Ссылки:
- [fastText — опубликованные модели](https://fasttext.cc/docs/en/supervised-models.html)
- [Файл модели Yelp Review Polarity](https://dl.fbaipublicfiles.com/fasttext/supervised-models/yelp_review_polarity.ftz)
- [JFastText](https://github.com/vinhkhuc/JFastText)
- [Bag of Tricks for Efficient Text Classification](https://arxiv.org/abs/1607.01759)

Docker, GitHub Actions и Kubernetes будут добавлены после локальной проверки.
