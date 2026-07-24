# Deployment Runbook

## Pre-deployment Checklist
- [ ] All tests passing in CI
- [ ] Code review approved
- [ ] QA sign-off on staging
- [ ] No active incidents
- [ ] Database migrations reviewed (if any)
- [ ] Feature flags configured (if any)

## Deployment Steps

### 1. Deploy to Staging
```bash
# Trigger staging deployment
gh workflow run deploy-staging.yml --ref main

# Verify staging health
curl https://staging.api.example.com/health
```

### 2. QA Verification on Staging
- Run regression test suite
- Verify new feature functionality
- Check error rates in monitoring
- Verify no performance regression

### 3. Deploy to Production
```bash
# Blue-green deployment
gh workflow run deploy-production.yml --ref main

# Monitor deployment progress
aws ecs describe-services --cluster prod --services api
```

### 4. Post-deployment Verification
- Check health endpoint: `curl https://api.example.com/health`
- Monitor error rate in CloudWatch (< 0.1% threshold)
- Monitor p99 latency (< 500ms threshold)
- Verify critical user flows

## Rollback Procedure
```bash
# Automatic rollback if health check fails within 5 minutes
# Manual rollback:
aws ecs update-service --cluster prod --service api --task-definition api:PREVIOUS_VERSION
```

## Service Dependencies
When deploying, verify these external dependencies are healthy:
- Stripe API: https://status.stripe.com
- Amazon SES: AWS Health Dashboard
- PostgreSQL RDS: CloudWatch metrics
- Redis ElastiCache: CloudWatch metrics

## Incident Response
If deployment causes issues:
1. Rollback immediately (don't debug in production)
2. Create incident in PagerDuty
3. Notify #incidents Slack channel
4. Investigate in staging with same code version
5. Fix, re-test, and re-deploy
