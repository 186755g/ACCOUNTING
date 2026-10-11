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
6. Expand device QA across supported Android versions, RTL/Arabic, accessibility,
   large datasets, restore failures, and notification permission states.
7. Add operational workflows only when requirements and data semantics are
   specified; do not introduce unsupported business predictions.
