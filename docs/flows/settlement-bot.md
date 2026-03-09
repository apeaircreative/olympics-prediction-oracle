# Settlement Bot Flow

## Overview
Automated market settlement using CRON scheduling and persistent tracking.

## Steps
1. Load markets from `markets.json`
2. Check current time vs market endTime
3. For expired open markets, trigger settlement
4. Update status on success/failure
5. Repeat every 10 minutes

## Files
- `settlement-bot.ts` (bot logic)
- `markets.json` (persistent storage)

## CLI Commands
- `add --id --question --end`: Add market
- `list`: Show all markets
- `settle-now --id`: Manual settle

## CRON Schedule
`*/10 * * * *` (every 10 minutes)
