package org.sentiment;

import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api")
public class SentimentController {
    private final SentimentService service;

    public SentimentController(SentimentService service) {
        this.service = service;
    }

    @GetMapping("/sentiment")
    public SentimentResponse analyze(@RequestParam("text") String text,
                                     @RequestParam(name = "lang", defaultValue = "en") String lang) {
        return new SentimentResponse(service.analyze(text, lang));
    }

    @PostMapping(value = "/sentiment", consumes = MediaType.APPLICATION_JSON_VALUE)
    public SentimentResponse analyze(@RequestBody SentimentRequest request) {
        String lang = request.lang() == null || request.lang().isEmpty()
                ? "en" : request.lang();
        return new SentimentResponse(service.analyze(request.text(), lang));
    }
}
