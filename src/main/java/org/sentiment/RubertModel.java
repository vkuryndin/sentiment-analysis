package org.sentiment;

import ai.djl.huggingface.tokenizers.HuggingFaceTokenizer;
import ai.onnxruntime.OnnxTensor;
import ai.onnxruntime.OrtEnvironment;
import ai.onnxruntime.OrtException;
import ai.onnxruntime.OrtSession;

import java.io.IOException;
import java.nio.file.Path;
import java.util.HashMap;
import java.util.Map;

public final class RubertModel implements AutoCloseable {
    // id2label in the published model's config.json.
    private static final String[] LABELS = {"negative", "neutral", "positive"};
    private final OrtEnvironment environment = OrtEnvironment.getEnvironment();
    private final HuggingFaceTokenizer tokenizer;
    private final OrtSession session;

    public RubertModel(Path directory) {
        try {
            tokenizer = HuggingFaceTokenizer.newInstance(directory.resolve("tokenizer.json"),
                    Map.of("truncation", "true", "maxLength", "512", "padding", "false"));
        } catch (IOException e) {
            throw new IllegalStateException("Cannot load RuBERT tokenizer", e);
        }
        try (var options = new OrtSession.SessionOptions()) {
            options.setIntraOpNumThreads(1);
            options.setInterOpNumThreads(1);
            session = environment.createSession(directory.resolve("model.onnx").toAbsolutePath().toString(), options);
        } catch (OrtException | RuntimeException e) {
            tokenizer.close();
            throw new IllegalStateException("Cannot load RuBERT model", e);
        }
    }

    public synchronized String predict(String text) {
        var encoding = tokenizer.encode(text);
        try (var ids = OnnxTensor.createTensor(environment, new long[][]{encoding.getIds()});
             var mask = OnnxTensor.createTensor(environment, new long[][]{encoding.getAttentionMask()});
             var types = OnnxTensor.createTensor(environment, new long[][]{encoding.getTypeIds()})) {
            Map<String, OnnxTensor> inputs = new HashMap<>();
            inputs.put("input_ids", ids);
            inputs.put("attention_mask", mask);
            if (session.getInputNames().contains("token_type_ids")) {
                inputs.put("token_type_ids", types);
            }
            try (var result = session.run(inputs)) {
                float[][] logits = (float[][]) result.get("logits").orElseThrow().getValue();
                if (logits.length != 1 || logits[0].length != LABELS.length) {
                    throw new IllegalStateException("Unexpected RuBERT output shape");
                }
                int best = 0;
                for (int i = 1; i < LABELS.length; i++) {
                    if (logits[0][i] > logits[0][best]) best = i;
                }
                return LABELS[best];
            }
        } catch (OrtException e) {
            throw new IllegalStateException("RuBERT inference failed", e);
        }
    }

    @Override
    public synchronized void close() throws OrtException {
        try {
            session.close();
        } finally {
            tokenizer.close();
        }
    }
}
