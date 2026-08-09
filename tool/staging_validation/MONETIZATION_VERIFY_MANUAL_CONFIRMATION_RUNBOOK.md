# Monetization Verify Manual Confirmation Runbook

Use the authorized staging dashboard or deployment record. This runbook does not authorize deployment, invocation, testing, or secret disclosure.

1. Confirm target project: `pxtjkwfedrtnxuihtdox`.
2. Confirm function: `monetization-verify`.
3. Confirm route: `/functions/v1/monetization-verify`.
4. Confirm JWT enforcement is enabled for the deployed function.
5. Confirm the required environment-variable names exist without viewing or recording their values.
6. Confirm the deployed version identity matches the reviewed local source revision.
7. Capture the project ref, function name, route, UTC timestamp, operator identity, and each confirmation outcome without exposing secrets.

Complete `MONETIZATION_VERIFY_OPERATOR_CONFIRMATION.md` and attach the redacted evidence to the receipt execution record.

Production release remains **NO**.