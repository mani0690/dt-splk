package com.example.debit;

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

    public DebitController(AccountStore accountStore) {
        this.accountStore = accountStore;
    }

    @PostMapping
    public Map<String, Object> debit(@RequestBody DebitRequest request) {
        log.info("Debit requested: account={} amount={}", request.account(), request.amount());
        BigDecimal newBalance = accountStore.debit(request.account(), request.amount());
        log.info("Debit successful: account={} newBalance={}", request.account(), newBalance);
        return Map.of(
                "account", request.account(),
                "debited", request.amount(),
                "newBalance", newBalance
        );
    }

    @GetMapping("/{account}/balance")
    public Map<String, Object> balance(@PathVariable String account) {
        return Map.of("account", account, "balance", accountStore.getBalance(account));
    }
}
