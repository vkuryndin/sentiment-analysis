# Sentiment Analysis Service 1.0.2

Учебное REST-приложение для анализа тональности текстов на английском и русском языках. Использует две предварительно обученные модели, загружаемые при старте приложения.

| Язык | Модель | Классы |
|---|---|---|
| `en` | fastText Yelp Review Polarity | positive, negative |
| `ru` | RuBERT Tiny Sentiment Balanced (ONNX INT8) | positive, negative, neutral |

## Технологии

Java 17, Spring Boot 4.1.2, Gradle 8.14.3 (Kotlin DSL), JFastText 0.5, ONNX Runtime 1.20.0, DJL Tokenizers 0.34.0, Spring Boot Actuator, Micrometer Prometheus, Docker, GitHub Actions, GHCR.

## Локальный запуск

Требуется JDK 17. В PowerShell из корня проекта:

```powershell
powershell -ExecutionPolicy Bypass -File .\prepare.ps1
.\gradlew.bat clean test
.\gradlew.bat bootRun
```

Скрипт подготовки загружает Gradle Wrapper и обе модели. Уже скачанные файлы используются повторно. В IntelliJ IDEA можно запускать `org.sentiment.SentimentApplication` с JDK 17 и рабочим каталогом в корне проекта.

Модели находятся в `models/yelp_review_polarity.ftz` и `models/rubert/` (`model.onnx`, `tokenizer.json`, `config.json`). Пути переопределяются переменными среды `SENTIMENT_MODEL_EN_PATH` и `SENTIMENT_MODEL_RU_DIR`. Файлы моделей исключены из Git.

## REST API

| Метод | Путь | Назначение |
|---|---|---|
| GET | `/api/sentiment?text=hello&lang=en` | Анализ текста |
| POST | `/api/sentiment` | Анализ текста из JSON |
| GET | `/actuator/health` | Состояние приложения |
| GET | `/actuator/prometheus` | Метрики Prometheus |

Параметр `lang` необязателен, по умолчанию `en`. Поддерживаются `en` и `ru`; автоматического определения языка нет. Пустой текст, текст длиннее 2000 символов и неподдерживаемый язык возвращают HTTP 400. Для RuBERT входная последовательность ограничена 512 токенами, включая служебные токены; токенизатор обрезает более длинную последовательность.

Пример:

```http
POST http://localhost:8085/api/sentiment
Content-Type: application/json

{"text":"Очень вкусная еда! Прекрасное обслуживание, всем рекомендую!","lang":"ru"}
```

Ответ:

```json
{"sentiment":"positive"}
```

Приложение использует один контроллер и сервис; сервис выбирает модель по языку. Английская модель работает через JFastText, русская — через ONNX Runtime и DJL Tokenizers. Обе модели загружаются один раз. Метрика `sentiment_predictions_total` содержит метки `language` и `sentiment` и появляется после первой успешной классификации соответствующего класса. Actuator предоставляет стандартные метрики HTTP, JVM и CPU.

## Тестирование

23 ручных HTTP-запроса находятся в `request.http`. Автоматические тесты: 10 тестов сервиса и 10 HTTP-тестов с реальными моделями. Запуск: `./gradlew test` (Linux) или `.\gradlew.bat test` (Windows). HTML-отчёт: `build/reports/tests/test/index.html`.

## Docker

Образ собирается для Linux AMD64. На этапе сборки скачиваются модели, выполняются 20 автоматических тестов, создаётся Spring Boot JAR и сокращённая Java Runtime (jlink). Скрипт `scripts/slim-linux-jar.py` удаляет из вложенных JAR ONNX Runtime и DJL Tokenizers нативные ресурсы других платформ. Локальная Gradle-сборка остаётся неизменной. Python используется только на этапе сборки и не входит в итоговый образ.

Итоговый образ основан на Distroless Debian 13 (glibc), запускается от UID 65532, содержит обе модели и не требует скачивания моделей при запуске. Порт — 8085. Размер проверяется в CI через `docker image inspect`: строго менее 150 000 000 байт.

Ручная сборка на машине с Docker:

```bash
docker build --platform linux/amd64 -t sentiment-analysis:1.0.2 .
docker image inspect sentiment-analysis:1.0.2 --format '{{.Size}}'
docker run --rm -p 127.0.0.1:8085:8085 sentiment-analysis:1.0.2
```

## GitHub Actions и GHCR

Workflow `.github/workflows/ci.yml` запускается при push в ветку `master` или вручную. Выполняются:

1. Сборка Docker-образа и Gradle-тесты.
2. Проверка запуска контейнера, health, английских и русских GET/POST-запросов, метрик для обоих языков.
3. Проверка размера образа (строго меньше 150 МБ).
4. Публикация в GHCR только при успешных проверках и запуске из `master`.

Тег берётся из `build.gradle.kts`. Для публикации используется встроенный `GITHUB_TOKEN` с разрешением `packages: write`. Gradle Wrapper (`gradlew`, `gradlew.bat`, `gradle/wrapper/gradle-wrapper.jar`, `gradle/wrapper/gradle-wrapper.properties`) должен быть в Git. В Summary отображаются результаты проверок, размер и адрес опубликованного образа.

Публичность исходного репозитория и пакета GHCR настраивается отдельно. До уточнения условий распространения готовых весов моделей пакет следует оставить приватным. Для скачивания приватного пакета требуется токен GitHub (classic) с `read:packages` и доступом к пакету; токен не хранится в репозитории.

### Проверка на Ubuntu VM

После успешной публикации:

```bash
IMAGE=ghcr.io/vkuryndin/sentiment-analysis:1.0.2
docker login ghcr.io -u vkuryndin
# Введите токен с read:packages, если пакет приватный.
docker pull "$IMAGE"
docker image inspect "$IMAGE" --format '{{.Size}}'
docker run -d --name sentiment-analysis -p 127.0.0.1:8085:8085 "$IMAGE"
curl -fsS http://localhost:8085/actuator/health
curl -fsS 'http://localhost:8085/api/sentiment?text=hello'
curl -fsS -H 'Content-Type: application/json' \
  --data '{"text":"Очень вкусная еда! Прекрасное обслуживание, всем рекомендую!","lang":"ru"}' \
  http://localhost:8085/api/sentiment
curl -fsS http://localhost:8085/actuator/prometheus | grep '^sentiment_predictions_total{'
docker rm -f sentiment-analysis
```

Развёртывание в Minikube выполняется отдельно, вручную. Self-hosted Runner не требуется.

## Источники

- [fastText — опубликованные модели](https://fasttext.cc/docs/en/supervised-models.html)
- [JFastText](https://github.com/vinhkhuc/JFastText)
- [RuBERT Tiny Sentiment Balanced](https://huggingface.co/cointegrated/rubert-tiny-sentiment-balanced)
- [ONNX-версия модели](https://huggingface.co/onnx-community/rubert-tiny-sentiment-balanced-ONNX)
- [ONNX Runtime Java](https://onnxruntime.ai/docs/get-started/with-java.html)
- [DJL Tokenizers](https://github.com/deepjavalibrary/djl/tree/v0.34.0/extensions/tokenizers)
- [GitHub Container Registry](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry)
- [Distroless](https://github.com/GoogleContainerTools/distroless)
