# Payment Service Architecture

## Overview
The payment service handles all monetary transactions for the platform. It integrates with Stripe as the primary payment gateway and supports credit card, debit card, and bank transfer payment methods.

## Service Location
- Source code: `src/services/payment/`
- Configuration: `src/config/payment.ts`
- Tests: `tests/services/payment/`

## Architecture

### Components
- **PaymentController** (`src/services/payment/controller.ts`): HTTP request handling, input validation
- **PaymentService** (`src/services/payment/service.ts`): Business logic, orchestration
- **StripeAdapter** (`src/services/payment/adapters/stripe.ts`): Stripe API integration
- **PaymentRepository** (`src/services/payment/repository.ts`): Database operations

### Database
- PostgreSQL table: `payments`
- Fields: id, user_id, amount, currency, status, stripe_payment_intent_id, created_at, updated_at
- Indexes: user_id, stripe_payment_intent_id, status+created_at

### API Endpoints
- `POST /api/payments` - Create a new payment
- `GET /api/payments/:id` - Get payment details
- `POST /api/payments/:id/refund` - Refund a payment
- `GET /api/payments/user/:userId` - List user payments

## Error Handling
Current error handling strategy is **fail-fast**:
- If Stripe API returns error, the payment fails immediately
- No retry logic is currently implemented
- Timeout: configurable via `PAYMENT_TIMEOUT_MS` env var (default: 15000ms)
- All errors are logged with correlation ID

## Idempotency
- Each payment request generates a unique idempotency key
- Idempotency key format: `pay_{userId}_{timestamp}_{random}`
- Stripe idempotency key is passed on all API calls
- Duplicate requests within 24h return cached result

## Configuration
Environment variables:
- `STRIPE_SECRET_KEY` - Stripe API key
- `STRIPE_WEBHOOK_SECRET` - Webhook signature validation
- `PAYMENT_TIMEOUT_MS` - API call timeout (default: 15000)
- `PAYMENT_MAX_AMOUNT` - Maximum single payment (default: 50000)
- `PAYMENT_CURRENCY` - Default currency (default: USD)

## Dependencies
- Stripe Node.js SDK v14.x
- PostgreSQL via Prisma ORM
- Redis for idempotency cache

## Security
- PCI DSS compliant - no card data stored locally
- All payment data encrypted at rest
- Webhook signature validation on all incoming Stripe events
- Rate limiting: 100 requests/minute per user

## Recent Changes
- 2026-07-10: Timeout configuration made environment-specific (CU-12340)
- 2026-06-28: Health check endpoint added (CU-12288)
- 2026-06-01: Stripe webhook signature validation hardened (CU-11950)
- 2026-05-15: Payment amount limits added
