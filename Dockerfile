# syntax=docker/dockerfile:1
FROM eclipse-temurin:17-jdk-jammy AS build
WORKDIR /build

RUN apt-get update && apt-get install -y --no-install-recommends python3 && rm -rf /var/lib/apt/lists/*
COPY gradlew build.gradle.kts settings.gradle.kts ./
COPY gradle/ ./gradle/
COPY src/ ./src/
COPY scripts/slim-linux-jar.py ./scripts/
COPY models.sha256 ./

# Download both models; local model binaries are excluded from the build context.
ADD https://dl.fbaipublicfiles.com/fasttext/supervised-models/yelp_review_polarity.ftz /build/models/yelp_review_polarity.ftz
ADD https://huggingface.co/onnx-community/rubert-tiny-sentiment-balanced-ONNX/resolve/main/onnx/model_quantized.onnx /build/models/rubert/model.onnx
ADD https://huggingface.co/onnx-community/rubert-tiny-sentiment-balanced-ONNX/resolve/main/tokenizer.json /build/models/rubert/tokenizer.json
ADD https://huggingface.co/onnx-community/rubert-tiny-sentiment-balanced-ONNX/resolve/main/config.json /build/models/rubert/config.json
RUN sha256sum --strict --check models.sha256 && \
    sh ./gradlew --no-daemon clean test bootJar && \
    python3 scripts/slim-linux-jar.py build/libs/sentiment-analysis.jar /build/app.jar

# Same Java runtime as the verified English-only image.
RUN jlink \
    --add-modules java.base,java.desktop,java.instrument,java.logging,java.management,java.naming,java.net.http,java.security.jgss,java.sql,java.xml,jdk.crypto.ec,jdk.management,jdk.management.agent,jdk.unsupported,jdk.zipfs \
    --strip-debug --no-header-files --no-man-pages --compress=2 \
    --output /opt/java-runtime

FROM gcr.io/distroless/java-base-debian13:nonroot
ENV JAVA_HOME=/opt/java \
    PATH=/opt/java/bin:$PATH \
    SENTIMENT_MODEL_EN_PATH=/app/models/yelp_review_polarity.ftz \
    SENTIMENT_MODEL_RU_DIR=/app/models/rubert \
    DJL_CACHE_DIR=/tmp/djl \
    DJL_OFFLINE=true \
    RUST_FLAVOR=cpu
WORKDIR /app
COPY --from=build /opt/java-runtime/ /opt/java/
COPY --from=build --chmod=644 /build/app.jar /app/app.jar
COPY --from=build --chmod=644 /build/models/yelp_review_polarity.ftz /app/models/yelp_review_polarity.ftz
COPY --from=build --chmod=644 /build/models/rubert/model.onnx /app/models/rubert/model.onnx
COPY --from=build --chmod=644 /build/models/rubert/tokenizer.json /app/models/rubert/tokenizer.json
COPY --from=build --chmod=644 /build/models/rubert/config.json /app/models/rubert/config.json
USER 65532:65532
EXPOSE 8085
ENTRYPOINT ["/opt/java/bin/java", "-Djava.awt.headless=true", "-Dorg.bytedeco.javacpp.cachedir=/tmp/javacpp", "-jar", "/app/app.jar"]
