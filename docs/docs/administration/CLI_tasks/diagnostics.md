# Diagnostics

A few tasks to help with debugging, troubleshooting, and diagnosing problems.

They mostly relate to common postgres queries. 

## Home timeline query plan

This task will print a query plan for the home timeline of a given user.

=== "OTP"

    `./bin/pleroma_ctl diagnostics home_timeline <nickname>`

=== "From Source"

    `mix pleroma.diagnostics home_timeline <nickname>`

## User timeline query plan

This task will print a query plan for the user timeline of a given user,
from the perspective of another given user.

=== "OTP"

    `./bin/pleroma_ctl diagnostics user_timeline <nickname> <viewing_nickname>`

=== "From Source"
    
    `mix pleroma.diagnostics user_timeline <nickname> <viewing_nickname>`