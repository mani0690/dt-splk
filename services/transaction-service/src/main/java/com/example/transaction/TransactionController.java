package com.example.transaction;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.client.HttpStatusCodeException;
import org.springframework.web.client.RestClientException;
import org.springframework.web.client.RestTemplate;

import java.util.Map;

@RestController
@RequestMapping("/api/transactions")
public class TransactionController {

    private static final Logger log = LoggerFactory.getLogger(TransactionController.class);

    private final RestTemplate restTemplate;

    @Value("${debit.service.url}")
    private String debitServiceUrl;

    @Value("${credit.service.url}")
    private String creditServiceUrl;

    public TransactionController(RestTemplate restTemplate) {
        this.restTemplate = restTemplate;
    }

    @PostMapping("/transfer")
    public ResponseEntity<Map<String, Object>> transfer(@RequestBody TransferRequest request) {
        log.info("Transfer requested: from={} to={} amount={}",
                request.fromAccount(), request.toAccount(), request.amount());

        // Step 1: debit the source account. This call, and the one below,
        // are the spans you'll see chained together in the distributed trace.
        Map<String, Object> debitResult;
        try {
            debitResult = restTemplate.postForObject(
                    debitServiceUrl + "/api/debit",
                    Map.of("account", request.fromAccount(), "amount", request.amount()),
                    Map.class
            );
        } catch (HttpStatusCodeException ex) {
            log.warn("Debit failed for account {}: {}", request.fromAccount(), ex.getStatusText());
            return ResponseEntity.status(HttpStatus.UNPROCESSABLE_ENTITY).body(Map.of(
                    "status", "FAILED",
                    "stage", "DEBIT",
                    "reason", ex.getStatusText()
            ));
        } catch (RestClientException ex) {
            log.error("Debit call failed (no response - timeout or unreachable) for account {}: {}",
                    request.fromAccount(), ex.getMessage());
            return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE).body(Map.of(
                    "status", "FAILED",
                    "stage", "DEBIT",
                    "reason", "debit-service unreachable"
            ));
        }

        // Step 2: only credit the destination if the debit actually succeeded.
        Map<String, Object> creditResult;
        try {
            creditResult = restTemplate.postForObject(
                    creditServiceUrl + "/api/credit",
                    Map.of("account", request.toAccount(), "amount", request.amount()),
                    Map.class
            );
        } catch (HttpStatusCodeException ex) {
            log.error("Credit failed AFTER debit succeeded for account {} - manual reconciliation needed: {}",
                    request.toAccount(), ex.getStatusText());
            return ResponseEntity.status(HttpStatus.BAD_GATEWAY).body(Map.of(
                    "status", "PARTIAL_FAILURE",
                    "stage", "CREDIT",
                    "reason", ex.getStatusText(),
                    "debitResult", debitResult
            ));
        } catch (RestClientException ex) {
            log.error("Credit call unreachable AFTER debit succeeded for account {} - manual reconciliation needed: {}",
                    request.toAccount(), ex.getMessage());
            return ResponseEntity.status(HttpStatus.BAD_GATEWAY).body(Map.of(
                    "status", "PARTIAL_FAILURE",
                    "stage", "CREDIT",
                    "reason", "credit-service unreachable",
                    "debitResult", debitResult
            ));
        }

        log.info("Transfer complete: from={} to={} amount={}",
                request.fromAccount(), request.toAccount(), request.amount());

        return ResponseEntity.ok(Map.of(
                "status", "SUCCESS",
                "debitResult", debitResult,
                "creditResult", creditResult
        ));
    }
}
