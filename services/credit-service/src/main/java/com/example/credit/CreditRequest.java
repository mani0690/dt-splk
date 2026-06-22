package com.example.credit;

import java.math.BigDecimal;

public record CreditRequest(String account, BigDecimal amount) {}
