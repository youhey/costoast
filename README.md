# Costoast

Your costs, served fresh.

Costoast is a tiny macOS dashboard for checking active web service costs at a glance.

This repository is currently adding service billing providers on top of the card dashboard, total cost, and JPY conversion base.

Implemented:

- Add, edit, delete, and reorder billing cards.
- Store non-sensitive billing card settings locally.
- Restore cards and display order after app restart.
- Show Manual Amount and Subscription Plan billing values.
- Fetch OpenAI API, AWS Cost Explorer, GCP Billing Export, Azure Cost Management, and Cloudflare subscription billing data from separated providers.
- Store API keys and secrets in macOS Keychain.
- Use the fixed AWS Cost Explorer endpoint in `us-east-1`.
- Convert each card's original amount to an estimated JPY amount.
- Show a Total card with the estimated JPY total.
- Fetch FX rates from an external no-key exchange rate API.

Provider notes:

- GCP uses Cloud Billing Export to BigQuery. Configure Project ID, Dataset ID, Table Name, and optionally Billing Account ID. The Service Account JSON is stored in macOS Keychain.
- Azure uses Tenant ID, Client ID, and either Scope or Subscription ID with Azure Cost Management Query API. The Client Secret is stored in macOS Keychain.
- Cloudflare uses Account ID and API Token. The API Token is stored in macOS Keychain. Cloudflare billing APIs and subscription data can be unavailable depending on account type and token permissions.
- JPY values are estimates based on the latest fetched billing amounts and current FX rates. They are not finalized invoice amounts.

Not implemented yet:

- Charts, notifications, or menu bar residency.
- Detailed UI/UX adjustments for the dashboard.

Credentials such as OpenAI API keys, AWS secret access keys, GCP Service Account JSON, Azure client secrets, and Cloudflare API tokens are not stored in UserDefaults or JSON card settings.
