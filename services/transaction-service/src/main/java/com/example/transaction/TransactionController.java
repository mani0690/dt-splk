package com.example.transaction;

import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.DistributionSummary;
import io.micrometer.core.instrument.MeterRegistry;
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
    private final Counter transferSuccess;
    private final Counter transferFailedDebit;
    private final Counter transferFailedCredit;
    private final Counter transferFailedDownstream;
    private final DistributionSummary transferAmount;

    @Value("${debit.service.url}")
    private String debitServiceUrl;

    @Value("${credit.service.url}")
    private String creditServiceUrl;

    public TransactionController(RestTemplate restTemplate, MeterRegistry meterRegistry) {
        this.restTemplate = restTemplate;

        this.transferSuccess = Counter.builder("transaction.transfer.total")
                .tag("status", "success")
                .description("Total successful fund transfers")
                .register(meterRegistry);

        this.transferFailedDebit = Counter.builder("transaction.transfer.total")
                .tag("status", "failed_debit")
                .description("Transfers failed at debit stage")
                .register(meterRegistry);

        this.transferFailedCredit = Counter.builder("transaction.transfer.total")
                .tag("status", "failed_credit")
                .description("Transfers failed at credit stage after successful debit")
                .register(meterRegistry);

        this.transferFailedDownstream = Counter.builder("transaction.transfer.total")
                .tag("status", "failed_downstream_unreachable")
                .description("Transfers failed due to downstream service unreachable")
                .register(meterRegistry);

        this.transferAmount = DistributionSummary.builder("transaction.transfer.amount")
                .description("Distribution of transfer amounts")
                .baseUnit("currency")
                .register(meterRegistry);
    }

    @PostMapping("/transfer")
    public ResponseEntity<Map<String, Object>> transfer(@RequestBody TransferRequest request) {
        log.info("Transfer requested: from={} to={} amount={}",
                request.fromAccount(), request.toAccount(), request.amount());

        transferAmount.record(request.amount().doubleValue());

        Map<String, Object> debitResult;
        try {
            debitResult = restTemplate.postForObject(
                    debitServiceUrl + "/api/debit",
                    Map.of("account", request.fromAccount(), "amount", request.amount()),
                    Map.class
            );
        } catch (HttpStatusCodeException ex) {
            log.warn("Debit failed for account {}: {}", request.fromAccount(), ex.getStatusText());
            transferFailedDebit.increment();
            return ResponseEntity.status(HttpStatus.UNPROCESSABLE_ENTITY).body(Map.of(
                    "status", "FAILED",
                    "stage", "DEBIT",
                    "reason", ex.getStatusText()
            ));
        } catch (RestClientException ex) {
            log.error("Debit unreachable for account {}: {}", request.fromAccount(), ex.getMessage());
            transferFailedDownstream.increment();
            return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE).body(Map.of(
                    "status", "FAILED",
                    "stage", "DEBIT",
                    "reason", "debit-service unreachable"
            ));
        }

        Map<String, Object> creditResult;
        try {
            creditResult = restTemplate.postForObject(
                    creditServiceUrl + "/api/credit",
                    Map.of("account", request.toAccount(), "amount", request.amount()),
                    Map.class
            );
        } catch (HttpStatusCodeException ex) {
            log.error("Credit failed AFTER debit succeeded - manual reconciliation needed: {}",
                    ex.getStatusText());
            transferFailedCredit.increment();
            return ResponseEntity.status(HttpStatus.BAD_GATEWAY).body(Map.of(
                    "status", "PARTIAL_FAILURE",
                    "stage", "CREDIT",
                    "reason", ex.getStatusText(),
                    "debitResult", debitResult
            ));
        } catch (RestClientException ex) {
            log.error("Credit unreachable AFTER debit succeeded - manual reconciliation needed: {}",
                    ex.getMessage());
            transferFailedCredit.increment();
            return ResponseEntity.status(HttpStatus.BAD_GATEWAY).body(Map.of(
                    "status", "PARTIAL_FAILURE",
                    "stage", "CREDIT",
                    "reason", "credit-service unreachable",
                    "debitResult", debitResult
            ));
        }

        transferSuccess.increment();
        log.info("Transfer complete: from={} to={} amount={}",
                request.fromAccount(), request.toAccount(), request.amount());

        return ResponseEntity.ok(Map.of(
                "status", "SUCCESS",
                "debitResult", debitResult,
                "creditResult", creditResult
        ));
    }
}