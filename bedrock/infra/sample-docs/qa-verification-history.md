# QA Verification History

## CU-12340: Fix timeout configuration in payment service
**Verified by**: minh.qa  
**Date**: 2026-07-10  
**Result**: PASS  

### What was tested
- Timeout configurable via env var PAYMENT_TIMEOUT_MS
- Default values: 15000ms production, 5000ms test
- CloudWatch metrics for timeout events

### Test Evidence
- Staging deployment with PAYMENT_TIMEOUT_MS=15000 confirmed
- Simulated slow Stripe response (12s) - no premature timeout
- Simulated over-limit response (20s) - correctly times out at 15s
- CloudWatch alarm triggered on timeout event
- No regression in existing payment tests

### Notes
- Old timeout (5s) was causing ~2% payment failures in production
- After fix: 0% timeout-related failures in staging over 24h

---

## CU-12288: Add health check endpoint to payment service
**Verified by**: minh.qa  
**Date**: 2026-06-28  
**Result**: PASS

### What was tested
- GET /health returns 200 when all dependencies healthy
- GET /health returns 503 with detail when DB unreachable
- GET /health returns 503 with detail when Stripe API unreachable
- Response includes version and uptime

### Test Evidence
- Normal operation: 200 with `{"status":"healthy","version":"2.4.1","uptime":"3d 4h"}`
- DB killed: 503 with `{"status":"unhealthy","failed":["database"],"message":"Connection refused"}`
- Stripe DNS blocked: 503 with `{"status":"unhealthy","failed":["stripe"],"message":"DNS resolution failed"}`
- Response time: <100ms in all cases

### Notes
- Kubernetes liveness probe configured to use this endpoint
- Readiness probe uses same endpoint with 5s timeout

---

## CU-11950: Stripe webhook signature validation
**Verified by**: minh.qa  
**Date**: 2026-06-01  
**Result**: PASS

### What was tested
- Valid webhook signatures accepted
- Invalid signatures rejected with 400
- Replayed events (old timestamp) rejected
- Clock skew > 5 minutes rejected

### Test Evidence
- Valid signature: 200, event processed correctly
- Tampered payload: 400, logged as security event
- Replay attack (same event, 10min old): 400, rejected
- Clock skew 6min: 400, rejected. Clock skew 4min: 200, accepted
- All rejection cases create CloudWatch security metric

### Notes
- Stripe webhook secret rotated monthly via AWS Secrets Manager
- Monitoring alert if > 10 signature failures in 5 minutes

---

## CU-12100: Email notification delivery
**Verified by**: minh.qa  
**Date**: 2026-06-15  
**Result**: PASS

### What was tested
- Email delivery via SES
- Template rendering (5 templates tested)
- Unsubscribe link generation and handling
- Rate limiting: max 10 emails/user/hour

### Test Evidence
- All 5 email templates render correctly with test data
- Unsubscribe link correctly opts out user from specific channel
- Rate limit: 11th email in 1 hour window returns 429
- SES bounce/complaint handling working

### Notes
- SES sandbox mode for staging - limited to verified emails
- Production SES has dedicated IP for reputation management
