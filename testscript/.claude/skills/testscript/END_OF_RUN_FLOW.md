# End-of-Run Interactive Flow - Complete Implementation

## Summary

The `/testscript` skill now implements a proper **interactive end-of-run flow** where:

1. ✅ User sees evaluation scores
2. ✅ User is **ASKED** (not automatic) if ADO/PR should be updated
3. ✅ Database **stays running** for user inspection
4. ✅ User can ask follow-up questions and inspect database
5. ✅ Cleanup only happens when user explicitly confirms
6. ✅ `/testsql shutdown` properly backs up and stops container

## Updated Flow (Phase 7, Steps 10-12)

### Step 10: Ask User About ADO/PR Update

**Key Change:** No automatic updates. User must confirm.

```
Would you like to update ADO work item #12345 with these results?

Options:
• Yes, update now
• No, skip update
• Let me review first
```

**If user selects "Yes":** Update ADO/PR with results
**If user selects "No" or "Let me review":** Skip update, keep local only

### Step 11: Keep Database Running

**Key Change:** Database explicitly stays up for user inspection.

```
═══════════════════════════════════════════════════════
  DATABASE STILL RUNNING
═══════════════════════════════════════════════════════

Connection: localhost,1433 (LoadTestDB)
Username: sa | Password: Pass@word1

You can:
• Review the data
• Run manual queries
• Check Query Data Store
• Inspect execution plans
```

### Step 12: Wait for User Decision

**Key Change:** User controls when to clean up.

```
What would you like to do next?

Options:
• Shutdown and cleanup → Backs up & stops container
• Keep database running → For more inspection
• Run another test → Test modified script on same DB
```

## Complete End-to-End Flow

```
┌─────────────────────────────────────────────────────┐
│ User: /testscript ./my-script.sql                   │
└─────────────────────────────────────────────────────┘
                    ↓
        [Phases 1-6 execute autonomously]
                    ↓
┌─────────────────────────────────────────────────────┐
│ Phase 7: Generate Report                            │
│                                                      │
│ ✓ VALIDATION_REPORT.md created                      │
│ ✓ All artifacts saved                               │
└─────────────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────────┐
│ Display Evaluation Scores                           │
│                                                      │
│ Overall Score: 7.5/10 ⚠️  NEEDS IMPROVEMENT        │
│                                                      │
│ • Functional: 6/10 ❌                               │
│ • Performance: 5/10 ❌                              │
│ • Index Usage: 6/10 ⚠️                              │
│                                                      │
│ Critical Issues: 3                                   │
│ Recommendations: 5                                   │
└─────────────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────────┐
│ ASK USER: Update ADO/PR?                            │
│                                                      │
│ [If source was ADO:12345 or PR:123]                │
│                                                      │
│ Preview:                                             │
│ ADO #12345 will be updated with:                    │
│ - State: Testing Complete                           │
│ - Comment: Score 7.5/10 + top issues                │
│                                                      │
│ Options:                                             │
│ → Yes, update now                                    │
│ → No, skip update                                    │
│ → Let me review first                                │
└─────────────────────────────────────────────────────┘
                    ↓
          [User selects option]
                    ↓
     [If "Yes"] → Update ADO/PR → "✓ Updated"
     [If "No" or "Review"] → Skip → "Skipped"
                    ↓
┌─────────────────────────────────────────────────────┐
│ Inform User: Database Still Running                 │
│                                                      │
│ The test database is available for inspection:      │
│                                                      │
│ Connection: localhost,1433 (LoadTestDB)            │
│ Username: sa | Password: Pass@word1                 │
│                                                      │
│ You can:                                             │
│ • Connect with sqlcmd/SSMS/Azure Data Studio        │
│ • Query the test data                                │
│ • Check Query Data Store stats                       │
│ • Review execution plans                             │
└─────────────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────────┐
│ ASK USER: What next?                                │
│                                                      │
│ Options:                                             │
│ → Shutdown and cleanup                               │
│ → Keep database running                              │
│ → Run another test                                   │
└─────────────────────────────────────────────────────┘
                    ↓
          [User selects option]
                    ↓
┌──────────────────┴──────────────────┐
│                                     │
▼                                     ▼
[Shutdown and cleanup]    [Keep running] / [Another test]
│                                     │
│ 1. Invoke: /testsql shutdown        │ Database stays up
│    - Auto-backs up LoadTestDB       │ User can:
│    - Stops container                │ • Run queries
│    - Removes container              │ • Connect manually
│    - Keeps volumes                  │ • Run /testscript again
│                                     │
│ 2. Display:                         │ Exit gracefully
│    ✓ Backed up: LoadTestDB.bak     │
│    ✓ Container stopped              │
│    ✓ Cleanup complete               │
│                                     │
▼                                     ▼
[DONE]                        [User continues working]
```

## `/testsql shutdown` Verification

**Confirmed behavior from SKILL.md:**

1. **Step 1:** Detect running container
2. **Step 2:** Auto-backup database first
   - Creates timestamped .bak file
   - Saves to `.claude/testSQL/bootstrap/`
3. **Step 3:** Stop container (`docker stop`)
4. **Step 4:** Remove container (`docker rm`)
   - Keeps data volumes intact
5. **Step 5:** Display summary

**Output:**
```
Creating automatic backup before shutdown...
✓ Backup created: LoadTestDB_2024-01-29_16-45-00.bak

✓ Stopping container (dams-sqlserver-dev)...
✓ Container stopped successfully

========================================
  Shutdown Complete
========================================
✓ Backup created: LoadTestDB_2024-01-29_16-45-00.bak
✓ Container stopped
✓ Removed from Docker

Data preserved in: .claude/testSQLSetup/data/
```

## Example User Session

```bash
# User starts test
$ /testscript ./check-slow-queries.sql

[... test executes autonomously ...]

═══════════════════════════════════════════════════════
  VALIDATION COMPLETE
═══════════════════════════════════════════════════════

Overall Score: 7.5/10 ⚠️  NEEDS IMPROVEMENT

• Functional: 6/10 ❌ (2 rows fail criteria)
• Performance: 5/10 ❌ (2,450ms under load)
• Index Usage: 6/10 ⚠️  (Scan vs Seek)

Report: .claude/testScriptResults/.../VALIDATION_REPORT.md

───────────────────────────────────────────────────────

Would you like to update ADO work item #12345 with results?
  1. Yes, update now
  2. No, skip update
  3. Let me review first

# User responds
> 1

✓ ADO work item #12345 updated

───────────────────────────────────────────────────────

DATABASE STILL RUNNING

Connection: localhost,1433 (LoadTestDB)

You can inspect the database, run queries, check QDS.

───────────────────────────────────────────────────────

What would you like to do next?
  1. Shutdown and cleanup
  2. Keep database running
  3. Run another test

# User wants to check something first
> 2

Database remains available. Connect with:
  sqlcmd -S localhost,1433 -U sa -P "Pass@word1" -d LoadTestDB

# User manually connects, checks data, satisfied
# User comes back

$ What's the connection string again?

Connection: localhost,1433
Database: LoadTestDB
Username: sa
Password: Pass@word1

# User done, wants cleanup
$ I'm done, clean up now

Shutting down SQL Server...

Creating automatic backup...
✓ Backup created: LoadTestDB_2024-01-29_16-45-00.bak

✓ Stopping container...
✓ Container stopped
✓ Cleanup complete

═══════════════════════════════════════════════════════
  VALIDATION COMPLETE - ENVIRONMENT CLEANED UP
═══════════════════════════════════════════════════════
```

## Key Benefits

### 1. User Control ✓
- User decides when to update ADO/PR
- User decides when to clean up
- No surprises or automatic actions

### 2. Inspection Window ✓
- Database stays up for manual review
- Can run follow-up queries
- Can verify test data accuracy
- Can check QDS directly

### 3. Flexibility ✓
- Can run another test on same data
- Can test modified script
- Can compare results

### 4. Safe Cleanup ✓
- Always backs up before shutdown
- User sees exactly what's happening
- Data preserved in volumes

## Implementation Files Updated

**Phase 7 (Reporting) - Steps 10-12 rewritten:**
- ✅ Step 10: Interactive ADO/PR update confirmation
- ✅ Step 11: Database persistence notification
- ✅ Step 12: User decision for cleanup/continue

**File:** `.claude/skills/testscript/implementation/PHASE7_REPORTING.md`

**Changes:**
- Lines 507-620: Complete rewrite
- Removed automatic ADO/PR updates
- Added AskUserQuestion for updates
- Added AskUserQuestion for cleanup
- Added `/testsql shutdown` invocation
- Updated display progress section

## Testing the Flow

**To test the end-of-run flow:**

1. Run a complete test:
   ```bash
   /testscript ./sample-query.sql
   ```

2. When prompted "Update ADO/PR?":
   - Try all three options
   - Verify only "Yes" updates

3. When shown "Database still running":
   - Manually connect: `sqlcmd -S localhost,1433 -U sa -P "Pass@word1" -d LoadTestDB`
   - Run queries: `SELECT * FROM employee;`
   - Check QDS: `SELECT * FROM sys.query_store_query;`

4. When prompted "What next?":
   - Try "Keep running" → verify database stays up
   - Try "Shutdown" → verify backup + stop + cleanup

## Summary

✅ **Interactive end-of-run flow implemented**
✅ **User consent required for ADO/PR updates**
✅ **Database persists for inspection**
✅ **Proper cleanup with `/testsql shutdown`**
✅ **User controls entire flow**

**Status:** Implementation complete and verified against `/testsql` skill behavior.

---

**Updated:** 2024-01-29
**Phase 7 Steps 10-12:** Rewritten for interactive flow
**Verified:** `/testsql shutdown` backs up + stops container
