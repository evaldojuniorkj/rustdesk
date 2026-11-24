# Design: support password together with the customer's password

Date: 2026-11-23
Status: approved in the conversation (approach A).

## Intent and why

The support team installs the customer edition on its customers' computers and wants to reach them with one default support password, without anyone clicking to accept. A customer who sets a password of their own in the app keeps it, and both passwords open the connection.

## Goals

- The installer of the customer edition carries one support password, the same for every customer.
- The support password works whether or not the customer set their own password.
- Built without the password, the app behaves exactly as before.

## Non-goals and anti-goals

- The password never goes into the repository; it is public on GitHub.
- No change to the click-to-accept flow, to the throttling of wrong attempts, or to stock RustDesk.
- No server-side or per-customer password management.

## Approaches

- **A, chosen. Read the password at compile time.** `option_env!("RUSTDESK_SUPPORT_PASSWORD")` bakes it into the binary. `validate_password` tries it after the existing checks fail. With no variable at build time, nothing changes.
- **B. Reuse RustDesk's preset password** (`HARD_SETTINGS["password"]`). Today it is either the preset or the local password, never both. Changing that touches the shared auth logic, the salt selection and the UI tips. Rejected as too invasive.
- **C. Pass the password through Flutter (dart-define plus a new FFI call).** It is more plumbing, and the check stays in Rust anyway. Rejected.

## Design

- **The hook.** A thin hook at the end of `Connection::validate_password` in `src/server/connection.rs`. It runs only when permanent passwords are allowed, under the same condition as the existing check.
- **How it checks.** It uses `validate_password_plain`, which hashes with the salt already sent to the peer, so it works with and without a local password.
- **Accepting.** On success the audit records `PermanentPassword` and an info line is logged once per login.
- **The helper.** `support_password_matches(Option<&str>, impl Fn(&str) -> bool)` holds the rule: no variable or an empty value never matches. It is unit-tested.
- **The builds.** Set the variable only when building the customer edition. Cargo rebuilds when its value changes.

## Fix of 2026-11-24: unattended on from install

- **The bug.** A customer with no password of their own was never asked for one. Before any password check, the login sees approve mode "both" with no valid local password and tells the peer to wait for a click (`LOGIN_MSG_NO_PASSWORD_ACCESS`). That gate now also passes when a support password is baked in and permanent passwords are enabled.
- **The UI.**
  - The lock next to "Seu endereço" and the unattended tile left the customer home; the option lives only in Configurações → Segurança.
  - With a support password (`mainGetCommon("support-password-set")`), the switch reads approve mode. It is on unless the mode is `click`, so it is on from install. Turning it off stores `click` and keeps both passwords. Below it, the customer may create, change or remove a password of their own.
  - Builds without a support password keep the old switch, which sets or clears the permanent password.
- **Startup preset.** The startup preset no longer forces the approve mode, which would undo the switch on every launch. Its default, empty, is the value the preset used to force.
- **Admin rights.** On Windows the installed app runs as a service, so the technician can operate elevated windows (UAC). Changing Segurança on an installed app still asks for admin rights or the unlock PIN.

## Known limits

- Anyone holding the installer can extract the password. A leak opens every customer, so a long password is advised.
- The connection window still appears on every connection; it closes by itself once the password is accepted.
- Customers who already installed need the new installer.
