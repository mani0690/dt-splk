package com.example.debit;

import io.micrometer.cloudwatch2.CloudWatchConfig;
import io.micrometer.cloudwatch2.CloudWatchMeterRegistry;
import io.micrometer.core.instrument.Clock;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import software.amazon.awssdk.services.cloudwatch.CloudWatchAsyncClient;

import java.time.Duration;

@Configuration
public class CloudWatchConfiguration {

    @Value("${management.metrics.export.cloudwatch.namespace:fintrace/debit-service}")
    private String namespace;

    @Value("${management.metrics.export.cloudwatch.step:30s}")
    private String step;

    @Bean
    public CloudWatchMeterRegistry cloudWatchMeterRegistry(
            CloudWatchConfig config, Clock clock) {
        return new CloudWatchMeterRegistry(config, clock,
                CloudWatchAsyncClient.create());
    }

    @Bean
    public CloudWatchConfig cloudWatchConfig() {
        return new CloudWatchConfig() {
            @Override
            public String get(String key) {
                return null;
            }

            @Override
            public String namespace() {
                return namespace;
            }

            @Override
            public Duration step() {
                return Duration.parse("PT" + step.toUpperCase()
                        .replace("S", "S")
                        .replace("M", "M"));
            }
        };
    }

    @Bean
    public Clock micrometerClock() {
        return Clock.SYSTEM;
    }
}