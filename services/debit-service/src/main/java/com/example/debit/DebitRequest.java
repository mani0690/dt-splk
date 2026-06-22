package com.example.debit;

import java.math.BigDecimal;

public record DebitRequest(String account, BigDecimal amount) {}
