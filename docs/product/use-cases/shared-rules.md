# Shared business rules

Rules that more than one use case enforces. Each is defined here once; a use case cites it by ID under **Business rules** and never restates it. IDs are stable and never reused.

## SR-1 — Password policy

Applies wherever the Shopper sets a password: Create Account (UC-01), Reset Password (UC-03).

- At least 8 characters.
- At least one letter and at least one digit.
- Not the same as the email address.
- The rules are shown next to the password field before the Shopper types, not only after a failure.
- A password that breaks the rules is refused with the rule it breaks; the other entered values are kept.

The Identity Provider enforces the same policy; the app checks first so the Shopper gets the message immediately.
