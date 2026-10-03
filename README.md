# drawnonward POS

drawnonward POS is a web-based point of sale system distributed and supported by drawnonward. It is written in PHP on CodeIgniter 4, uses MySQL or MariaDB as the data store, and has a simple, intuitive user interface.

## Support

- Phone: +923182232414
- Email: info@drawnonward.org

## Features

- Stock management (items with an extensible list of attributes)
- VAT, GST, customer, and multi-tier taxation
- Sale register with transaction logging
- Quotations and invoicing
- Expense logging
- Cash-up function
- Printing and emailing of receipts, invoices and quotations
- Barcode generation and printing
- Database of customers and suppliers
- Multi-user with permission control
- Reporting on sales, orders, expenses, inventory status and more
- Receivings
- Rewards
- Restaurant tables
- Messaging (SMS)
- Multilanguage
- Selectable Bootstrap based UI theme with Bootswatch
- MailChimp integration
- Optional Google reCAPTCHA to protect the login page from brute force attacks
- GDPR ready

## Requirements

- PHP 8.2 to 8.4 with the `json`, `gd`, `bcmath`, `intl`, `openssl`, `mbstring`, `curl` and `xml` extensions
- MySQL 5.7 or later, or MariaDB 10.x
- Apache 2.4 (Nginx works too)

## Installation

See [WINDOWS.md](WINDOWS.md) for the step-by-step Windows guide (Docker Desktop, or XAMPP without Docker), [INSTALL.md](INSTALL.md) for Linux and Docker installs, [BUILD.md](BUILD.md) to build from source, and [UPGRADE.md](UPGRADE.md) to upgrade an existing installation.

Default login after installation:

- Username: `admin`
- Password: `pointofsale`

Change the default password right after the first login.

## License

Licensed under the MIT License. See [LICENSE](LICENSE) for the full terms.
