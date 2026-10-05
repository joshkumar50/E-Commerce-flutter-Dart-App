# B-Buys Post-Deploy Smoke Test Checklist

Execute this checklist manually on the production staging environment before the final Go-Live.

## 1. Customer Journey
| Step | Action | Expected | Pass/Fail |
|---|---|---|---|
| 1 | Launch App | App loads without configuration errors | |
| 2 | Login (OTP or Google) | User authenticates successfully, role is 'anon' | |
| 3 | Browse Products | Products load, images render (HTTPS only) | |
| 4 | Add to Cart | Cart updates with item, syncs to server | |
| 5 | Checkout | Payment gateway opens, verifies idempotency | |
| 6 | Order History | New order is visible in customer history | |

## 2. Admin Journey
| Step | Action | Expected | Pass/Fail |
|---|---|---|---|
| 1 | Launch Admin App | App loads, authenticates as admin role | |
| 2 | Add Product | New product saves to database | |
| 3 | Adjust Stock | Inventory Ledger updates correctly | |
| 4 | Refund Order | Order status changes, refund record created | |
| 5 | Trigger Crash | Sentry captures crash, PII is scrubbed | |
