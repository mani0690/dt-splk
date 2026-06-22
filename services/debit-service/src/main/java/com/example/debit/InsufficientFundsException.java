package com.example.debit;

import java.math.BigDecimal;

public class InsufficientFundsException extends RuntimeException {
    public InsufficientFundsException(String account, BigDecimal balance, BigDecimal requested) {
        super("Account " + account + " has balance " + balance + " but " + requested + " was requested");
    }
}
