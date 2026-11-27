package org.sentiment;

import com.github.jfasttext.FastTextWrapper;
import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;

import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Locale;
import java.util.Map;
import java.util.function.UnaryOperator;

public class FastTextModel implements AutoCloseable {
    private final FastTextWrapper.FastTextApi model;
    private final Map<String, String> labels;
    private final UnaryOperator<String> normalize;

    public FastTextModel(Path path, Map<String, String> labels, UnaryOperator<String> normalize) {
        if (!Files.isRegularFile(path) || !Files.isReadable(path)) {
            throw new IllegalStateException("Model not found or unreadable: " + path.toAbsolutePath());
        }
        this.labels = Map.copyOf(labels);
        this.normalize = normalize;
        this.model = new FastTextWrapper.FastTextApi();
        try {
            this.model.loadModel(path.toAbsolutePath().toString());
        } catch (RuntimeException | Error e) {
            this.model.close();
            throw e;
        }
    }

    // Serialize calls to a model instance because its native wrapper's thread safety is not guaranteed.
    public synchronized String predict(String text) {
        String normalized = normalize.apply(text);
        if (normalized.isBlank()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Text is empty after normalization");
        }
        String label;
        try (var predictions = model.predict(normalized + "\n", 1)) {
            label = predictions.size() > 0
                    ? predictions.get(0).getString()
                    : null;
        }
        String sentiment = label == null ? null : labels.get(label);
        if (sentiment == null) {
            throw new IllegalStateException("Unexpected model label: " + label);
        }
        return sentiment;
    }

    @Override
    public synchronized void close() {
        model.close();
    }

    // Match the text normalization used to train the published Yelp model.
    static String normalizeEnglish(String text) {
        return text.toLowerCase(Locale.ROOT)
                .replace("<br />", " ")
                .replace("\"", "")
                .replaceAll("([.,()!?'])", " $1 ")
                .replaceAll("[;:]", " ")
                .replaceAll("(?U)\\s+", " ")
                .strip();
    }
}
