package org.sentiment;

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
    private final Map<String, FastTextModel> models;
    private final MeterRegistry metrics;

    public SentimentService(@Value("${sentiment.model.en-path}") String modelPath,
                            MeterRegistry metrics) {
        this.metrics = metrics;
        // Register the Russian model here when it is ready (version 1.1).
        this.models = Map.of("en", new FastTextModel(Path.of(modelPath),
                Map.of("__label__1", "negative", "__label__2", "positive"),
                FastTextModel::normalizeEnglish));
    }

    public String analyze(String text, String lang) {
        if (text == null || text.isBlank() || text.length() > 2000) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                    "Text must contain 1 to 2000 characters");
        }

        String language = lang.strip().toLowerCase(Locale.ROOT);
        FastTextModel model = models.get(language);
        if (model == null) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Unsupported language");
        }

        String sentiment = model.predict(text);
        metrics.counter("sentiment.predictions", "language", language, "sentiment", sentiment)
                .increment();
        return sentiment;
    }
}
