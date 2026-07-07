package com.example.credit;

import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.util.Map;

@RestController
@RequestMapping("/api/credit")
public class CreditController {

    private static final Logger log = LoggerFactory.getLogger(CreditController.class);

    private final AccountStore accountStore;
    private final Counter creditSuccess;

    public CreditController(AccountStore accountStore, MeterRegistry meterRegistry) {
        this.accountStore = accountStore;

        this.creditSuccess = Counter.builder("credit.operation.total")
                .tag("result", "success")
                .description("Successful credit operations")
                .register(meterRegistry);
    }

    @PostMapping
    public Map<String, Object> credit(@RequestBody CreditRequest request) {
        log.info("Credit requested: account={} amount={}", request.account(), request.amount());
        BigDecimal newBalance = accountStore.credit(request.account(), request.amount());
        creditSuccess.increment();
        log.info("Credit successful: account={} newBalance={}", request.account(), newBalance);
        return Map.of(
                "account", request.account(),
                "credited", request.amount(),
                "newBalance", newBalance
        );
    }

    @GetMapping("/{account}/balance")
    public Map<String, Object> balance(@PathVariable String account) {
        return Map.of("account", account, "balance", accountStore.getBalance(account));
    }
}