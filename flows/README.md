# Maestro Flows for ChronoSpark

## Included flows
- goal_flow.yaml
- habit_flow.yaml
- task_flow.yaml
- note_flow.yaml
- timeline_flow.yaml
- si_console_flow.yaml
- settings_flow.yaml

## Shared helper
- _login_if_needed.yaml

This helper logs in only when the login screen is visible.

## Run all flows
maestro test flows/

## Run one flow
maestro test flows/goal_flow.yaml

## Install Maestro (Windows)
Option A (Scoop):
1. scoop bucket add extras
2. scoop install maestro

Option B (Manual):
1. Download from https://maestro.mobile.dev/
2. Add Maestro to PATH
3. Re-open terminal and run: maestro --version

## Recommended order
1. goal_flow.yaml
2. habit_flow.yaml
3. task_flow.yaml
4. note_flow.yaml
5. timeline_flow.yaml
6. si_console_flow.yaml
7. settings_flow.yaml
