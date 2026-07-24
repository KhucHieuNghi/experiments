# Project Overview - E-Commerce Platform

## Product Description
A modern e-commerce platform providing online shopping experience with payment processing, user management, notifications, and order fulfillment.

## Tech Stack
- **Backend**: Node.js (TypeScript), Express.js
- **Database**: PostgreSQL (Prisma ORM), Redis (caching)
- **Message Queue**: Amazon SQS
- **File Storage**: Amazon S3
- **Payment**: Stripe
- **Email**: Amazon SES
- **Infrastructure**: AWS, Terraform, Docker
- **CI/CD**: GitHub Actions
- **Monitoring**: CloudWatch, Datadog

## Services Architecture
The platform follows a modular monolith architecture with clear service boundaries:

### Core Services
1. **User Service** (`src/services/user/`)
   - Authentication (JWT + refresh tokens)
   - Profile management
   - Role-based access control

2. **Payment Service** (`src/services/payment/`)
   - Stripe integration
   - Payment processing
   - Refund handling
   - Webhook processing

3. **Order Service** (`src/services/order/`)
   - Order creation and management
   - Order status tracking
   - Fulfillment coordination

4. **Notification Service** (`src/services/notification/`)
   - Email (SES)
   - Push notifications (FCM)
   - SMS (Twilio)
   - In-app notifications

5. **Product Service** (`src/services/product/`)
   - Product catalog
   - Inventory management
   - Search and filtering

## Team
- **Backend**: 4 engineers (david.nguyen, lisa.tran, anna.le, tom.pham)
- **QA**: 2 engineers (minh.qa, hoa.qa)
- **Product**: 1 PM (sarah.product)
- **DevOps**: 1 engineer (kien.devops)

## Deployment
- **Environments**: development, staging, production
- **Deploy frequency**: 2-3 times per week
- **Release process**: PR → Review → Staging deploy → QA verify → Production deploy
- **Rollback**: Automatic via blue-green deployment

## Current Sprint Focus (Sprint 42)
- Payment reliability improvements (retry logic, circuit breaker)
- Notification preferences API
- Performance optimization for product search
