# Security-related tasks

{! administration/CLI_tasks/general_cli_task_info.include !}

!!! danger
    Many of these tasks were written in response to a patched exploit.
    It is recommended to run those very soon after installing its respective security update.
    Over time with db migrations they might become less accurate or be removed altogether.
    If you never ran an affected version, there’s no point in running them.

## Spoofed AcitivityPub objects exploit (2024-03, fixed in 3.11.1)

### Search for uploaded spoofing payloads

Scans local uploads for spoofing payloads.
If the instance is not using the local uploader it was not affected.
Attachments wil be scanned anyway in case local uploader was used in the past.

!!! note
    This cannot reliably detect payloads attached to deleted posts.

=== "OTP"

    ```sh
    ./bin/pleroma_ctl security spoof-uploaded
    ```

=== "From Source"

    ```sh
    mix pleroma.security spoof-uploaded
    ```

### Search for counterfeit posts in database

Scans all notes in the database for signs of being spoofed.

!!! note
    Spoofs targeting local accounts can be detected rather reliably
    (with some restrictions documented in the task’s logs).
    Counterfeit posts from remote users cannot. A best-effort attempt is made, but
    a thorough attacker can avoid this and it may yield a small amount of false positives.

    Should you find counterfeit posts of local users, let other admins know so they can delete the too.

=== "OTP"

    ```sh
    ./bin/pleroma_ctl security spoof-inserted
    ```

=== "From Source"

    ```sh
    mix pleroma.security spoof-inserted
    ```
