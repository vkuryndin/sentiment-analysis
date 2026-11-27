package org.sentiment;

import io.micrometer.core.instrument.simple.SimpleMeterRegistry;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.BeforeAll;
import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

class SentimentServiceTest {
    private static final SimpleMeterRegistry METRICS = new SimpleMeterRegistry();
    private static SentimentService service;

    @BeforeAll
    static void loadModel() {
        String path = System.getenv().getOrDefault("SENTIMENT_MODEL_EN_PATH",
                "models/yelp_review_polarity.ftz");
        service = new SentimentService(path, METRICS);
    }

    @Test
    void positiveReview() {
        assertEquals("positive", service.analyze(
                "Excellent food and friendly service. I absolutely loved this restaurant!", "en"));
    }

    @Test
    void negativeReview() {
        assertEquals("negative", service.analyze(
                "Terrible food, rude staff and horrible service. I will never come back.", "en"));
    }

    @Test
    void shortTextFromAssignment() {
        assertEquals("positive", service.analyze("hello", "en"));
    }

    @Test
    void rejectsEmptyText() {
        assertEquals(HttpStatus.BAD_REQUEST,
                assertThrows(ResponseStatusException.class, () -> service.analyze("  ", "en")).getStatusCode());
    }

    @Test
    void rejectsUnsupportedLanguage() {
        assertEquals(HttpStatus.BAD_REQUEST,
                assertThrows(ResponseStatusException.class, () -> service.analyze("Hello", "ru")).getStatusCode());
    }

    @Test
    void recordsPredictionMetric() {
        double before = METRICS.counter("sentiment.predictions", "language", "en", "sentiment", "positive").count();
        service.analyze("Excellent food and friendly service. I absolutely loved this restaurant!", "en");
        assertEquals(before + 1, METRICS.counter("sentiment.predictions", "language", "en", "sentiment", "positive").count());
    }
}
