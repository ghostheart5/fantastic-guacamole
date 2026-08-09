# Receipt Product Mismatch Review

Local source review covers `monetization-verify` and `_shared/subscription_verification.ts`. It is not deployed-route or Google test-receipt proof.

| Check | Classification | Local evidence |
| --- | --- | --- |
| Client `productId` is claimed rather than blindly accepted | PASS | It is allow-listed, purchase-type checked, and used in server-side Google verification. |
| Google `lineItems[].productId` matches claimed `productId` | PASS | Subscription verification returns null unless a matching line item is found. |
| Lower-tier token cannot claim higher-tier product | PASS | Local subscription fixture covers monthly token claiming annual product and expects rejection. |
| Missing `lineItems` fails | PASS | Non-array line items return null. |
| Expired subscription fails | PASS | Expiry must parse and be in the future. |
| Invalid subscription state fails | PASS | Only active and grace-period states are accepted. |
| Benefits derive from verified product, not blindly from client input | NEEDS_GOOGLE_TEST_RECEIPT | Subscription path applies the product only after matching Google line-item validation; the in-app path relies on the Google product-token endpoint and needs a safe receipt test. |
| `target_user_id` derives from authenticated user | PASS | The request has no target-user field; the authenticated Supabase user ID is passed server-side. |
| Purchase-token/order replay protections exist or are planned | NEEDS_GOOGLE_TEST_RECEIPT | Token binding hashes the token and rejects cross-user reuse; order replay behavior needs safe staging evidence and cleanup approval. |
| `apply_verified_purchase` is called only after verification succeeds | PASS | Both paths require valid Google state and successful token binding before application. |

## Additional Deployment Requirement

The local results require **NEEDS_DEPLOYED_ROUTE_CONFIRMATION** before they are treated as staging behavior.

Production release remains **NO**.