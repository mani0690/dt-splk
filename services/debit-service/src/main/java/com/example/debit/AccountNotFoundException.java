package com.example.debit;

public class AccountNotFoundException extends RuntimeException {
    public AccountNotFoundException(String account) {
        super("Account not found: " + account);
    }
}
