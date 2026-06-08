# Costoast

Your costs, served fresh.

Costoast is a tiny macOS dashboard for checking active web service costs at a glance.

This repository is currently at Phase 4: total cost and JPY conversion.

Implemented:

- Add, edit, delete, and reorder billing cards.
- Store non-sensitive billing card settings locally.
- Restore cards and display order after app restart.
- Show Manual Amount and Subscription Plan billing values.
- Fetch initial OpenAI API and AWS Cost Explorer billing data from separated providers.
- Store API keys and secrets in macOS Keychain.
- Use the fixed AWS Cost Explorer endpoint in `us-east-1`.
- Convert each card's original amount to an estimated JPY amount.
- Show a Total card with the estimated JPY total.
- Fetch FX rates from an external no-key exchange rate API.

JPY values are estimates based on the latest fetched billing amounts and current FX rates. They are not finalized invoice amounts.

Not implemented yet:

- Charts, notifications, or menu bar residency.
- Detailed UI/UX adjustments for the dashboard.
- Additional service providers beyond Manual Amount, Subscription Plan, OpenAI API, and AWS.

Credentials such as OpenAI API keys and AWS secret access keys are not stored in UserDefaults or JSON card settings.
