# Costoast

Your costs, served fresh.

Costoast is a tiny macOS dashboard for checking active web service costs at a glance.

This repository is currently at Phase 3: initial billing service providers.

Implemented:

- Add, edit, delete, and reorder billing cards.
- Store non-sensitive billing card settings locally.
- Restore cards and display order after app restart.
- Show Manual Amount and Subscription Plan billing values.
- Fetch initial OpenAI API and AWS Cost Explorer billing data from separated providers.
- Store API keys and secrets in macOS Keychain.
- Use the fixed AWS Cost Explorer endpoint in `us-east-1`.

Not implemented yet:

- JPY conversion, total cards, charts, notifications, or menu bar residency.
- Additional service providers beyond Manual Amount, Subscription Plan, OpenAI API, and AWS.

Credentials such as OpenAI API keys and AWS secret access keys are not stored in UserDefaults or JSON card settings.
