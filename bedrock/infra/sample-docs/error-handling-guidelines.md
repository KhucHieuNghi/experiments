# Error Handling Guidelines

## General Principles
1. **Fail fast for client errors (4xx)** - Do not retry on validation errors, auth errors, or bad requests
2. **Retry on transient errors (5xx, timeouts)** - Use exponential backoff with jitter
3. **Circuit breaker for cascading failures** - Trip after N consecutive failures
4. **Always log with context** - Include correlation_id, service, action, error_code, attempt_number

## Retry Strategy Standards

### Recommended Pattern
```typescript
interface RetryConfig {
  maxRetries: number;       // Default: 3
  baseDelayMs: number;      // Default: 1000
  maxDelayMs: number;       // Default: 10000
  backoffMultiplier: number; // Default: 2
  retryableStatusCodes: number[]; // Default: [500, 502, 503, 504]
  retryableErrors: string[];      // Default: ['ETIMEDOUT', 'ECONNRESET', 'ECONNREFUSED']
}
```

### Exponential Backoff Formula
```
delay = min(baseDelayMs * (backoffMultiplier ^ attemptNumber) + jitter, maxDelayMs)
jitter = random(0, baseDelayMs * 0.1)
```

### What to Retry
- HTTP 500, 502, 503, 504
- Network timeouts (ETIMEDOUT)
- Connection reset (ECONNRESET)
- Connection refused (ECONNREFUSED)
- DNS resolution failures

### What NOT to Retry
- HTTP 400 Bad Request
- HTTP 401 Unauthorized
- HTTP 402 Payment Required
- HTTP 403 Forbidden
- HTTP 404 Not Found
- HTTP 409 Conflict
- HTTP 422 Unprocessable Entity
- HTTP 429 Too Many Requests (use backoff from Retry-After header instead)

## Circuit Breaker Standards

### Configuration
- **Failure threshold**: 5 consecutive failures to trip
- **Reset timeout**: 30 seconds before half-open
- **Half-open max calls**: 1 request to test recovery
- **Monitoring**: CloudWatch metric on state changes

### States
1. **Closed** (normal): All requests pass through
2. **Open** (tripped): All requests fail immediately with 503
3. **Half-Open**: Single test request allowed; success closes, failure re-opens

## Logging Standards

### Required Fields
```json
{
  "timestamp": "ISO8601",
  "level": "error|warn|info",
  "correlation_id": "uuid",
  "service": "payment-service",
  "action": "stripe.charge.create",
  "attempt": 1,
  "max_attempts": 3,
  "error_code": "STRIPE_TIMEOUT",
  "error_message": "Request timed out after 15000ms",
  "duration_ms": 15000
}
```

## Service-Specific Notes

### Payment Service
- Currently uses **fail-fast** (no retry) for all Stripe calls
- Idempotency keys ensure safe retry if implemented
- Circuit breaker NOT yet implemented
- Priority: HIGH to add retry logic (prevents revenue loss on transient failures)

### Notification Service
- Email: retry 3x with 5s/10s/30s backoff
- Push: retry 2x with 2s/4s backoff
- SMS: no retry (provider handles delivery retry)

### User Service
- Database calls: no retry (use connection pool health)
- Cache (Redis): retry 1x with 100ms delay
- Auth provider: retry 2x with 1s/2s backoff
