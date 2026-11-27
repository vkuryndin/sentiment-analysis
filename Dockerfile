# syntax=docker/dockerfile:1
FROM eclipse-temurin:17-jdk-jammy AS build
WORKDIR /build

COPY gradlew build.gradle.kts settings.gradle.kts ./
COPY gradle/ ./gradle/
COPY src/ ./src/

# The same official model as prepare.ps1; no model binary is committed to Git.
ADD https://dl.fbaipublicfiles.com/fasttext/supervised-models/yelp_review_polarity.ftz /build/models/yelp_review_polarity.ftz
RUN test -s models/yelp_review_polarity.ftz && \
    sh ./gradlew --no-daemon clean test bootJar && \
    cp build/libs/sentiment-analysis-*.jar /build/app.jar

# Java 17 runtime with the modules needed by Spring, Tomcat and Actuator.
RUN jlink \
    --add-modules java.base,java.desktop,java.instrument,java.logging,java.management,java.naming,java.net.http,java.security.jgss,java.sql,java.xml,jdk.crypto.ec,jdk.management,jdk.management.agent,jdk.unsupported,jdk.zipfs \
    --strip-debug --no-header-files --no-man-pages --compress=2 \
    --output /opt/java-runtime

# glibc runtime and native dependencies for JFastText / JavaCPP (not Alpine).
FROM gcr.io/distroless/java-base-debian13:nonroot
ENV JAVA_HOME=/opt/java \
    PATH=/opt/java/bin:$PATH \
    SENTIMENT_MODEL_EN_PATH=/app/models/yelp_review_polarity.ftz
WORKDIR /app
COPY --from=build /opt/java-runtime/ /opt/java/
COPY --from=build --chmod=644 /build/app.jar /app/app.jar
COPY --from=build --chmod=644 /build/models/yelp_review_polarity.ftz /app/models/yelp_review_polarity.ftz
USER 65532:65532
EXPOSE 8085
ENTRYPOINT ["/opt/java/bin/java", "-Djava.awt.headless=true", "-Dorg.bytedeco.javacpp.cachedir=/tmp/javacpp", "-jar", "/app/app.jar"]
