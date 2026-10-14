# Roadmap

1. Replace the placeholder Android application ID and configure a protected
   release-signing pipeline.
2. Add encrypted portable backups with a user-controlled recovery key and
   explicit compatibility/migration policy.
3. Add optional cloud backup/synchronization providers without making network
   access a dependency of local workflows.
4. Implement scheduled local notifications behind the existing scheduler
   interface, with explicit user-controlled timing and platform permission
   handling.
5. Extend pagination to sales, purchases, customer/supplier histories, and
   large report filter lists.
   Status (2026-10-14): sales, purchases, customer/supplier histories, and the
   large report analysis lists now use limit/offset queries backed by the
   repository/service layer, with a load-more pattern in the report screen.
   The widget-level verification for the broader UI flow remains inconclusive in
   this Linux environment: `flutter test` reaches the tests and stalls during
   the loading stage without producing a pass/fail signal, so this is not
   reported as a successful UI validation.
6. Add the financial accounts ledger and daily reconciliation layer for cash,
   bank, card, and wallet accounts.
   Status (2026-10-14): the local SQLite ledger is implemented with separate
   `financial_accounts`, `account_movements`, and `account_reconciliations`
   tables, a repository for balance and movement tracking, and a regression test
   covering opening balance, debit/credit movements, and daily variance checks.
   The UI for account management and reconciliation screens is not yet added.
7. Expand device QA across supported Android versions, RTL/Arabic, accessibility,
   large datasets, restore failures, and notification permission states.
8. Add operational workflows only when requirements and data semantics are
   specified; do not introduce unsupported business predictions.
