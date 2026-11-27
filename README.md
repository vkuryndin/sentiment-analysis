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

## Docker и GitHub Actions

Dockerfile собирает приложение в Linux с Java 17 и Gradle Wrapper, скачивает ту же английскую модель с официального сайта fastText и запускает 13 автоматических тестов. В итоговый образ входят сокращённая Java Runtime (jlink), приложение и модель. Базовый образ Distroless использует glibc; контейнер запускается от непривилегированного пользователя. Порт приложения — 8085.

Workflow `.github/workflows/ci.yml` запускается при push в ветку `main` или вручную через Actions. Он собирает образ для `linux/amd64`, проверяет размер через `docker image inspect` (строго меньше 150 000 000 байт), запускает контейнер и проверяет health, GET, два POST и метрики. Только после успешных проверок образ публикуется в `ghcr.io/<владелец>/<репозиторий>:1.0.1` (имя в нижнем регистре, тег берётся из `build.gradle.kts`). Используется встроенный `GITHUB_TOKEN`, дополнительные секреты для публикации не нужны.

### Подготовка репозитория

Создайте пустой репозиторий GitHub `sentiment-analysis` (без автоматически создаваемых README и .gitignore). В локальном проекте должны присутствовать `gradlew`, `gradlew.bat`, `gradle/wrapper/gradle-wrapper.jar` и `gradle/wrapper/gradle-wrapper.properties` — они были скачаны скриптом `prepare.ps1`. Проверьте, что они включены в коммит. Модель остаётся исключённой из Git. `.gitattributes` задаёт LF для Linux-скрипта Gradle Wrapper.

Если проект ещё не находится под управлением Git, выполните в PowerShell из его корня (замените `USERNAME` на свой логин GitHub):

```powershell
git init -b main
git add .
git status
git commit -m "Sentiment Analysis 1.0.1: Docker and CI"
git remote add origin https://github.com/USERNAME/sentiment-analysis.git
git push -u origin main
```

Если Git уже настроен, используйте существующий репозиторий и remote, не выполняя повторно `git init` и `git remote add`.

В GitHub откройте вкладку Actions → Build, test and publish. В Summary будут указаны тег образа, размер в байтах и результат проверки контейнера. При ошибке образ не публикуется.

### Доступ к образу

GHCR по умолчанию создаёт новый пакет с приватной видимостью. Публичный репозиторий кода и видимость пакета — отдельные настройки. Официальная страница скачивания Yelp Review Polarity не указывает явно лицензию на распространение готового файла модели; до уточнения условий не меняйте видимость содержащего модель пакета на Public. Для приватного образа на Ubuntu потребуется персональный токен GitHub (classic) с разрешением `read:packages`, принадлежащий аккаунту с доступом к пакету. Токен не включается в Git.

### Ручная проверка на Ubuntu VM

После успешного workflow замените `username` на логин владельца в нижнем регистре (и имя репозитория, если отличается). Проверьте, что архитектура VM — x86_64 (`uname -m`).

```bash
IMAGE=ghcr.io/username/sentiment-analysis:1.0.1
docker login ghcr.io -u USERNAME
# В поле Password введите токен read:packages.
# Для публичного образа docker login не нужен.
docker pull "$IMAGE"
docker image inspect "$IMAGE" --format '{{.Size}}'
docker run -d --name sentiment-analysis -p 127.0.0.1:8085:8085 "$IMAGE"
docker logs sentiment-analysis
```

После запуска выполните:

```bash
curl -fsS http://localhost:8085/actuator/health
curl -fsS 'http://localhost:8085/api/sentiment?text=hello'
curl -fsS -H 'Content-Type: application/json' \
  --data '{"text":"Terrible food, rude staff and horrible service. I will never come back."}' \
  http://localhost:8085/api/sentiment
curl -fsS http://localhost:8085/actuator/prometheus | grep '^sentiment_predictions_total{'
```

Ожидаются `UP`, `positive`, `negative` и метрики классификаций. Для доступа с Windows без изменения сетевых настроек можно использовать SSH-туннель на свободный локальный порт, если SSH на VM уже настроен. По окончании проверки остановите и удалите только тестовый контейнер:

```bash
docker rm -f sentiment-analysis
```

Развёртывание в Minikube выполняется отдельно, вручную. Self-hosted Runner и входящий доступ GitHub к VM не требуются. Файлы Kubernetes и подключение русской модели будут добавлены после проверки контейнера.

Ссылки: [GitHub Container Registry](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry), [Distroless](https://github.com/GoogleContainerTools/distroless).

