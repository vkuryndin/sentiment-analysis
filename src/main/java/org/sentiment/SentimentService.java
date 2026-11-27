package org.sentiment;

import ai.onnxruntime.OrtException;
import jakarta.annotation.PreDestroy;
import io.micrometer.core.instrument.MeterRegistry;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

import java.nio.file.Path;
import java.util.Locale;
import java.util.Map;

@Service
public class SentimentService {
    private final FastTextModel english;
    private final RubertModel russian;
    private final MeterRegistry metrics;

    public SentimentService(@Value("${sentiment.model.en-path}") String modelPath,
                            @Value("${sentiment.model.ru-dir}") String russianDir,
                            MeterRegistry metrics) {
        this.metrics = metrics;
        this.english = new FastTextModel(Path.of(modelPath),
                Map.of("__label__1", "negative", "__label__2", "positive"),
                FastTextModel::normalizeEnglish);
        try {
            this.russian = new RubertModel(Path.of(russianDir));
        } catch (RuntimeException | Error e) {
            english.close();
            throw e;
        }
    }

    public String analyze(String text, String lang) {
        if (text == null || text.isBlank() || text.length() > 2000) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                    "Text must contain 1 to 2000 characters");
        }

        String language = lang.strip().toLowerCase(Locale.ROOT);
        String sentiment = switch (language) {
            case "en" -> english.predict(text);
            case "ru" -> russian.predict(text);
            default -> throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Unsupported language");
        };
        metrics.counter("sentiment.predictions", "language", language, "sentiment", sentiment)
                .increment();
        return sentiment;
    }
    @PreDestroy
    public void close() throws OrtException {
        try {
            russian.close();
        } finally {
            english.close();
        }
    }
}
