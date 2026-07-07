package com.example.debit;

import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.util.Map;

@RestController
@RequestMapping("/api/debit")
public class DebitController {

    private static final Logger log = LoggerFactory.getLogger(DebitController.class);

    private final AccountStore accountStore;
    private final Counter debitSuccess;
    private final Counter debitInsufficientFunds;
    private final Counter debitAccountNotFound;

    public DebitController(AccountStore accountStore, MeterRegistry meterRegistry) {
        this.accountStore = accountStore;

        this.debitSuccess = Counter.builder("debit.operation.total")
                .tag("result", "success")
                .description("Successful debit operations")
                .register(meterRegistry);

        this.debitInsufficientFunds = Counter.builder("debit.operation.total")
                .tag("result", "insufficient_funds")
                .description("Debit operations rejected due to insufficient funds")
                .register(meterRegistry);

        this.debitAccountNotFound = Counter.builder("debit.operation.total")
                .tag("result", "account_not_found")
                .description("Debit operations rejected due to unknown account")
                .register(meterRegistry);
    }

    @PostMapping
    public Map<String, Object> debit(@RequestBody DebitRequest request) {
        log.info("Debit requested: account={} amount={}", request.account(), request.amount());
        try {
            BigDecimal newBalance = accountStore.debit(request.account(), request.amount());
            debitSuccess.increment();
            log.info("Debit successful: account={} newBalance={}", request.account(), newBalance);
            return Map.of(
                    "account", request.account(),
                    "debited", request.amount(),
                    "newBalance", newBalance
            );
        } catch (InsufficientFundsException ex) {
            debitInsufficientFunds.increment();
            throw ex;
        } catch (AccountNotFoundException ex) {
            debitAccountNotFound.increment();
            throw ex;
        }
    }

    @GetMapping("/{account}/balance")
    public Map<String, Object> balance(@PathVariable String account) {
        return Map.of("account", account, "balance", accountStore.getBalance(account));
    }
}