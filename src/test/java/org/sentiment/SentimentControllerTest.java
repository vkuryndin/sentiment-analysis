package org.sentiment;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.server.LocalServerPort;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;

import static org.junit.jupiter.api.Assertions.assertEquals;

@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
class SentimentControllerTest {
    @LocalServerPort
    private int port;

    private final HttpClient client = HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(5))
            .build();

    private HttpResponse<String> post(String json) throws Exception {
        HttpRequest request = HttpRequest.newBuilder(endpoint())
                .timeout(Duration.ofSeconds(10))
                .header("Content-Type", "application/json")
                .POST(HttpRequest.BodyPublishers.ofString(json))
                .build();
        return client.send(request, HttpResponse.BodyHandlers.ofString());
    }

    private URI endpoint() {
        return URI.create("http://localhost:" + port + "/api/sentiment");
    }

    private void assertSentiment(HttpResponse<String> response, String sentiment) {
        assertEquals(200, response.statusCode(), response.body());
        assertEquals("{\"sentiment\":\"" + sentiment + "\"}", response.body());
    }

    @Test
    void positiveMultilineReviewWithDefaultLanguage() throws Exception {
        assertSentiment(post("""
                {"text":"Excellent food and friendly service.\\nI absolutely loved this restaurant!"}
                """), "positive");
    }

    @Test
    void negativeReviewWithExplicitLanguage() throws Exception {
        assertSentiment(post("""
                {"text":"Terrible food, rude staff and horrible service. I will never come back.","lang":"en"}
                """), "negative");
    }

    @Test
    void getAndPostReturnSameResultForHello() throws Exception {
        HttpRequest request = HttpRequest.newBuilder(URI.create(endpoint() + "?text=hello"))
                .timeout(Duration.ofSeconds(10))
                .GET()
                .build();
        HttpResponse<String> get = client.send(request, HttpResponse.BodyHandlers.ofString());
        HttpResponse<String> post = post("{\"text\":\"hello\"}");
        assertSentiment(get, "positive");
        assertSentiment(post, "positive");
    }

    @Test
    void rejectsMissingOrBlankText() throws Exception {
        for (String json : new String[]{"{}", "{\"text\":\"\"}", "{\"text\":\"  \\n  \"}"}) {
            assertEquals(400, post(json).statusCode(), json);
        }
    }

    @Test
    void rejectsUnsupportedLanguage() throws Exception {
        assertEquals(400, post("{\"text\":\"Hello\",\"lang\":\"de\"}").statusCode());
    }

    @Test
    void rejectsMalformedJson() throws Exception {
        assertEquals(400, post("{\"text\": }").statusCode());
    }

    @Test
    void rejectsTextOverLimit() throws Exception {
        assertEquals(400, post("{\"text\":\"" + "a".repeat(2001) + "\"}").statusCode());
    }
    @Test
    void russianPositiveReview() throws Exception {
        assertSentiment(post("""
                {"text":"Очень вкусная еда! Прекрасное обслуживание, всем рекомендую!","lang":"ru"}
                """), "positive");
    }

    @Test
    void russianNegativeReview() throws Exception {
        assertSentiment(post("""
                {"text":"Ужасный ресторан. Еда отвратительная, обслуживание ужасное!","lang":"ru"}
                """), "negative");
    }

    @Test
    void russianGetMatchesPost() throws Exception {
        String text = "Сегодня понедельник. Магазин открывается в девять часов.";
        String encoded = java.net.URLEncoder.encode(text, java.nio.charset.StandardCharsets.UTF_8);
        var request = HttpRequest.newBuilder(URI.create(endpoint() + "?lang=ru&text=" + encoded))
                .timeout(Duration.ofSeconds(10)).GET().build();
        var get = client.send(request, HttpResponse.BodyHandlers.ofString());
        var post = post("{\"text\":\"" + text + "\",\"lang\":\"ru\"}");
        assertEquals(200, get.statusCode(), get.body());
        assertEquals(200, post.statusCode(), post.body());
        assertEquals(get.body(), post.body());
    }
}
