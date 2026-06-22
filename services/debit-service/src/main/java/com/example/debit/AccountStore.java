package com.example.debit;

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
        if (!balances.containsKey(account)) {
            throw new AccountNotFoundException(account);
        }
        return balances.get(account);
    }

    public synchronized BigDecimal debit(String account, BigDecimal amount) {
        BigDecimal current = getBalance(account);
        if (current.compareTo(amount) < 0) {
            throw new InsufficientFundsException(account, current, amount);
        }
        BigDecimal updated = current.subtract(amount);
        balances.put(account, updated);
        return updated;
    }
}
