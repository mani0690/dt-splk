package com.example.credit;

import org.springframework.stereotype.Component;

import java.math.BigDecimal;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

@Component
public class AccountStore {

    private final Map<String, BigDecimal> balances = new ConcurrentHashMap<>();

    public AccountStore() {
        balances.put("ACC100", new BigDecimal("1000.00"));
        balances.put("ACC200", new BigDecimal("500.00"));
        balances.put("ACC300", new BigDecimal("250.00"));
    }

    public BigDecimal getBalance(String account) {
        return balances.getOrDefault(account, BigDecimal.ZERO);
    }

    public synchronized BigDecimal credit(String account, BigDecimal amount) {
        BigDecimal updated = getBalance(account).add(amount);
        balances.put(account, updated);
        return updated;
    }
}
