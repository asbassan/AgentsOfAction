# Phase 2: Analyze Script & Extract Schema

## Goal
Parse the user's SQL script to understand what tables and columns it references, then generate CREATE TABLE statements for the test environment.

## Input
- `user_script_content`: The SQL script text
- `success_criteria`: From Phase 1

## Output
- `table_definitions`: List of tables with columns and types
- `detected_qds_query`: Boolean (true if script queries sys.query_store_*)
- `script_analysis`: Detailed analysis object

## Implementation Steps

### Step 1: Detect Query Data Store Usage

**Action:** Determine if script queries QDS tables

**Pattern Matching:**
```python
# Check for QDS table references
qds_tables_in_script = []

qds_table_patterns = [
    r'sys\.query_store_query\b',
    r'sys\.query_store_plan\b',
    r'sys\.query_store_runtime_stats\b',
    r'sys\.query_store_wait_stats\b',
    r'sys\.query_store_query_text\b',
    r'sys\.query_store_runtime_stats_interval\b'
]

for pattern in qds_table_patterns:
    if re.search(pattern, user_script_content, re.IGNORECASE):
        table_name = extract_table_name(pattern)
        qds_tables_in_script.append(table_name)

detected_qds_query = len(qds_tables_in_script) > 0
```

**Store:**
- `detected_qds_query`: boolean
- `qds_tables_in_script`: list of table names

---

### Step 2: Extract Table References

**Action:** Find all FROM and JOIN clauses to identify tables

**SQL Pattern Extraction:**

```python
# Patterns to match
patterns = [
    r'FROM\s+(\[?\w+\]?\.?\[?\w+\]?)\s',           # FROM table
    r'JOIN\s+(\[?\w+\]?\.?\[?\w+\]?)\s',           # JOIN table
    r'INTO\s+(\[?\w+\]?\.?\[?\w+\]?)\s',           # INSERT INTO
    r'UPDATE\s+(\[?\w+\]?\.?\[?\w+\]?)\s',         # UPDATE table
]

tables_referenced = set()

for pattern in patterns:
    matches = re.findall(pattern, user_script_content, re.IGNORECASE)
    for match in matches:
        # Clean table name (remove brackets, schema prefix)
        clean_name = clean_table_name(match)

        # Skip system tables (will create separately)
        if not clean_name.startswith('sys.'):
            tables_referenced.add(clean_name)
```

**Example:**
```sql
-- User script:
SELECT e.employeeid, e.name, d.deptname
FROM employee e
JOIN department d ON e.deptid = d.deptid
WHERE e.salary > 50000

-- Extracted tables:
['employee', 'department']
```

**Store:** `tables_referenced` (set)

---

### Step 3: Extract Column References

**Action:** For each table, determine what columns are referenced

**Approach:**

1. **Parse SELECT clause:**
```python
# Find SELECT columns
select_pattern = r'SELECT\s+(.*?)\s+FROM'
select_match = re.search(select_pattern, user_script_content, re.IGNORECASE | re.DOTALL)

if select_match:
    select_clause = select_match.group(1)

    # Extract column references
    # e.employeeid, e.name, d.deptname
    columns = parse_select_columns(select_clause)

    # columns = [
    #   {'table': 'e', 'column': 'employeeid'},
    #   {'table': 'e', 'column': 'name'},
    #   {'table': 'd', 'column': 'deptname'}
    # ]
```

2. **Parse WHERE clause:**
```python
where_pattern = r'WHERE\s+(.*?)(?:ORDER BY|GROUP BY|$)'
where_match = re.search(where_pattern, user_script_content, re.IGNORECASE | re.DOTALL)

if where_match:
    where_clause = where_match.group(1)

    # Extract columns from conditions
    # e.salary > 50000
    where_columns = extract_where_columns(where_clause)

    # where_columns = [
    #   {'table': 'e', 'column': 'salary'}
    # ]
```

3. **Parse JOIN clause:**
```python
join_pattern = r'ON\s+(.*?)(?:WHERE|JOIN|ORDER|GROUP|$)'
join_matches = re.findall(join_pattern, user_script_content, re.IGNORECASE)

join_columns = []
for join_clause in join_matches:
    # e.deptid = d.deptid
    cols = extract_join_columns(join_clause)
    join_columns.extend(cols)

    # join_columns = [
    #   {'table': 'e', 'column': 'deptid'},
    #   {'table': 'd', 'column': 'deptid'}
    # ]
```

4. **Resolve table aliases:**
```python
# Extract alias mapping
# FROM employee e → {'e': 'employee'}
# JOIN department d → {'d': 'department'}

alias_pattern = r'(?:FROM|JOIN)\s+(\w+)\s+(?:AS\s+)?(\w+)'
alias_matches = re.findall(alias_pattern, user_script_content, re.IGNORECASE)

alias_map = {}
for table, alias in alias_matches:
    alias_map[alias] = table

# Resolve all column references
for col in columns:
    if col['table'] in alias_map:
        col['table'] = alias_map[col['table']]
```

**Combined Result:**
```python
table_columns = {
    'employee': ['employeeid', 'name', 'deptid', 'salary'],
    'department': ['deptid', 'deptname']
}
```

**Store:** `table_columns` (dict)

---

### Step 4: Infer Column Data Types

**Action:** Guess appropriate SQL Server data types for columns

**Type Inference Logic:**

```python
def infer_column_type(column_name, column_usage):
    """
    Infer SQL Server data type based on name and usage
    """

    # ID columns
    if column_name.endswith('id') or column_name.endswith('ID'):
        return 'INT'

    # Name/text columns
    if 'name' in column_name.lower():
        return 'NVARCHAR(200)'

    # Description columns
    if 'desc' in column_name.lower() or 'description' in column_name.lower():
        return 'NVARCHAR(MAX)'

    # Date columns
    if 'date' in column_name.lower() or 'time' in column_name.lower():
        return 'DATETIME'

    # Amount/money columns
    if any(x in column_name.lower() for x in ['amount', 'price', 'cost', 'salary']):
        return 'DECIMAL(18,2)'

    # Count columns
    if 'count' in column_name.lower():
        return 'INT'

    # Boolean columns
    if column_name.lower().startswith('is') or column_name.lower().startswith('has'):
        return 'BIT'

    # Check usage in WHERE clause
    if column_usage['in_where_numeric']:
        return 'INT'  # Used in numeric comparison

    if column_usage['in_where_string']:
        return 'NVARCHAR(200)'  # Used in string comparison

    # Default
    return 'NVARCHAR(200)'
```

**Apply to Columns:**
```python
for table, columns in table_columns.items():
    table_definitions[table] = {}

    for column in columns:
        usage = analyze_column_usage(column, user_script_content)
        data_type = infer_column_type(column, usage)

        table_definitions[table][column] = {
            'type': data_type,
            'nullable': True,  # Default to nullable
            'primary_key': column.endswith('id') and column == f'{table}id'
        }
```

**Example Result:**
```python
table_definitions = {
    'employee': {
        'employeeid': {'type': 'INT', 'nullable': False, 'primary_key': True},
        'name': {'type': 'NVARCHAR(200)', 'nullable': True, 'primary_key': False},
        'deptid': {'type': 'INT', 'nullable': True, 'primary_key': False},
        'salary': {'type': 'DECIMAL(18,2)', 'nullable': True, 'primary_key': False}
    },
    'department': {
        'deptid': {'type': 'INT', 'nullable': False, 'primary_key': True},
        'deptname': {'type': 'NVARCHAR(200)', 'nullable': True, 'primary_key': False}
    }
}
```

**Store:** `table_definitions` (dict)

---

### Step 5: Detect Additional Common Columns

**Action:** Add standard columns that make sense for test data

**Logic:**

For each table, add common columns that will be useful for background load queries:

```python
for table_name in table_definitions:
    columns = table_definitions[table_name]

    # Add created_date if not exists
    if 'created_date' not in columns and 'createdate' not in columns:
        columns['created_date'] = {'type': 'DATETIME', 'nullable': True, 'primary_key': False}

    # Add status/flag columns for variety
    if 'status' not in columns:
        columns['status'] = {'type': 'VARCHAR(50)', 'nullable': True, 'primary_key': False}

    # Add text column for IO-intensive queries
    if not any('notes' in col or 'description' in col for col in columns):
        columns['notes'] = {'type': 'NVARCHAR(MAX)', 'nullable': True, 'primary_key': False}
```

**Reasoning:**
- These columns provide more realistic data
- Enable diverse background load query patterns
- Don't interfere with user's script (not referenced)

---

### Step 6: Generate CREATE TABLE Statements

**Action:** Convert table definitions to SQL DDL

**Implementation:**

```python
def generate_create_table_sql(table_name, columns):
    """
    Generate CREATE TABLE statement
    """
    sql = f"CREATE TABLE [{table_name}] (\n"

    # Add columns
    column_defs = []
    primary_key_cols = []

    for col_name, col_info in columns.items():
        col_def = f"    [{col_name}] {col_info['type']}"

        if not col_info['nullable']:
            col_def += " NOT NULL"

        if col_info['primary_key']:
            primary_key_cols.append(col_name)

        column_defs.append(col_def)

    sql += ",\n".join(column_defs)

    # Add primary key constraint
    if primary_key_cols:
        pk_name = f"PK_{table_name}"
        pk_cols = ", ".join(f"[{col}]" for col in primary_key_cols)
        sql += f",\n    CONSTRAINT [{pk_name}] PRIMARY KEY ({pk_cols})"

    sql += "\n);\nGO\n"

    return sql

# Generate for all tables
create_scripts = []
for table_name, columns in table_definitions.items():
    script = generate_create_table_sql(table_name, columns)
    create_scripts.append(script)
```

**Example Output:**
```sql
CREATE TABLE [employee] (
    [employeeid] INT NOT NULL,
    [name] NVARCHAR(200),
    [deptid] INT,
    [salary] DECIMAL(18,2),
    [created_date] DATETIME,
    [status] VARCHAR(50),
    [notes] NVARCHAR(MAX),
    CONSTRAINT [PK_employee] PRIMARY KEY ([employeeid])
);
GO

CREATE TABLE [department] (
    [deptid] INT NOT NULL,
    [deptname] NVARCHAR(200),
    [created_date] DATETIME,
    [status] VARCHAR(50),
    [notes] NVARCHAR(MAX),
    CONSTRAINT [PK_department] PRIMARY KEY ([deptid])
);
GO
```

---

### Step 7: Detect Expected Indexes

**Action:** Identify indexes that should exist based on query patterns

**Logic:**

```python
expected_indexes = []

# Indexes from success criteria
if 'index_usage' in success_criteria:
    expected_indexes.extend(success_criteria['index_usage']['expected_indexes'])

# Infer indexes from WHERE clauses
for table, columns in table_columns.items():
    for column in columns:
        if column_used_in_where(column, user_script_content):
            index_name = f"IX_{table}_{column}"
            expected_indexes.append({
                'name': index_name,
                'table': table,
                'columns': [column],
                'included_columns': []
            })

# Infer indexes from JOIN clauses
for table, columns in table_columns.items():
    for column in columns:
        if column_used_in_join(column, user_script_content):
            index_name = f"IX_{table}_{column}_join"
            expected_indexes.append({
                'name': index_name,
                'table': table,
                'columns': [column],
                'included_columns': []
            })
```

**Generate Index DDL:**
```python
def generate_index_sql(index_info):
    table = index_info['table']
    name = index_info['name']
    columns = index_info['columns']
    included = index_info.get('included_columns', [])

    sql = f"CREATE NONCLUSTERED INDEX [{name}]\n"
    sql += f"ON [{table}]({', '.join(f'[{col}]' for col in columns)})"

    if included:
        sql += f"\nINCLUDE ({', '.join(f'[{col}]' for col in included)})"

    sql += ";\nGO\n"

    return sql
```

**Store:**
- `expected_indexes`: list of index definitions
- `index_create_scripts`: list of SQL DDL strings

---

### Step 8: Analyze Join Patterns

**Action:** Understand relationships between tables

**Detection:**

```python
join_relationships = []

# Parse JOIN conditions
# e.deptid = d.deptid
join_pattern = r'ON\s+(\w+)\.(\w+)\s*=\s*(\w+)\.(\w+)'
join_matches = re.findall(join_pattern, user_script_content, re.IGNORECASE)

for left_alias, left_col, right_alias, right_col in join_matches:
    left_table = alias_map.get(left_alias, left_alias)
    right_table = alias_map.get(right_alias, right_alias)

    join_relationships.append({
        'left_table': left_table,
        'left_column': left_col,
        'right_table': right_table,
        'right_column': right_col,
        'type': 'INNER'  # Assume inner join
    })

# join_relationships = [
#   {
#     'left_table': 'employee',
#     'left_column': 'deptid',
#     'right_table': 'department',
#     'right_column': 'deptid',
#     'type': 'INNER'
#   }
# ]
```

**Generate Foreign Key Constraints (Optional):**
```sql
ALTER TABLE [employee]
ADD CONSTRAINT [FK_employee_department]
FOREIGN KEY ([deptid]) REFERENCES [department]([deptid]);
GO
```

**Store:** `join_relationships` (list)

---

### Step 9: Build Script Analysis Summary

**Action:** Compile all analysis into structured object

**Output:**
```python
script_analysis = {
    'tables': {
        'user_tables': list(tables_referenced),
        'system_tables': qds_tables_in_script if detected_qds_query else [],
        'total_count': len(tables_referenced)
    },
    'columns': {
        'by_table': table_columns,
        'total_count': sum(len(cols) for cols in table_columns.values())
    },
    'query_patterns': {
        'has_joins': len(join_relationships) > 0,
        'has_aggregations': 'SUM(' in user_script_content or 'AVG(' in user_script_content,
        'has_subqueries': 'SELECT' in user_script_content[20:],  # Not first SELECT
        'has_cte': 'WITH' in user_script_content and 'AS (' in user_script_content,
        'uses_top': 'TOP' in user_script_content.upper()
    },
    'performance_indicators': {
        'likely_expensive': detect_expensive_patterns(user_script_content),
        'estimated_complexity': calculate_complexity_score(user_script_content)
    },
    'qds_detection': {
        'queries_qds': detected_qds_query,
        'qds_tables': qds_tables_in_script
    }
}
```

**Helper Functions:**

```python
def detect_expensive_patterns(sql):
    """Detect potentially expensive query patterns"""
    expensive_patterns = []

    if 'CROSS JOIN' in sql.upper():
        expensive_patterns.append('CROSS JOIN (Cartesian product)')

    if re.search(r'SELECT\s+\*', sql, re.IGNORECASE):
        expensive_patterns.append('SELECT * (all columns)')

    if 'DISTINCT' in sql.upper() and 'TOP' not in sql.upper():
        expensive_patterns.append('DISTINCT without TOP')

    return expensive_patterns

def calculate_complexity_score(sql):
    """Simple complexity scoring"""
    score = 1  # Base score

    score += sql.upper().count('JOIN') * 2
    score += sql.upper().count('WHERE') * 1
    score += sql.upper().count('GROUP BY') * 2
    score += sql.upper().count('ORDER BY') * 1
    score += sql.upper().count('HAVING') * 2

    if score < 5:
        return 'LOW'
    elif score < 10:
        return 'MEDIUM'
    else:
        return 'HIGH'
```

---

### Step 10: Save Analysis Results

**Action:** Write generated scripts and analysis to files

**Files to Create:**

1. **create_tables.sql**
```bash
Write: .claude/testScriptResults/{timestamp}/schema/create_tables.sql
Content: "\n\n".join(create_scripts)
```

2. **create_indexes.sql**
```bash
Write: .claude/testScriptResults/{timestamp}/schema/create_indexes.sql
Content: "\n\n".join(index_create_scripts)
```

3. **script_analysis.json**
```bash
Write: .claude/testScriptResults/{timestamp}/script_analysis.json
Content: JSON.stringify(script_analysis, indent=2)
```

4. **table_definitions.json**
```bash
Write: .claude/testScriptResults/{timestamp}/schema/table_definitions.json
Content: JSON.stringify(table_definitions, indent=2)
```

---

## Display Progress

After completion:
```
📊 Phase 2: Analyze Script & Extract Schema
═══════════════════════════════════════════════════════

✓ Query Data Store detected: YES
  Tables: sys.query_store_runtime_stats, sys.query_store_query

✓ Extracted 3 user tables:
  • employee (7 columns)
  • department (5 columns)
  • salary_history (6 columns)

✓ Detected query patterns:
  • JOINs: 2
  • WHERE filters: 3 columns
  • Complexity: MEDIUM

✓ Generated schema:
  • CREATE TABLE statements: 3
  • Indexes to create: 5
  • Foreign keys: 2

Saved:
• schema/create_tables.sql
• schema/create_indexes.sql
• script_analysis.json

→ Proceeding to Phase 3: Generate Test Data
```

---

## Error Handling

### Cannot Parse SQL
```
❌ Error: Cannot parse SQL script

Issue: Unable to extract table references from script.

Possible causes:
- Complex SQL syntax
- Dynamic SQL (EXEC, sp_executesql)
- Stored procedure calls

Options:
1. Manually specify tables and columns
2. Provide simplified version of script
3. Skip schema extraction (use default tables)
```

Use AskUserQuestion for manual input if needed.

### Ambiguous Table Names
```
⚠️  Ambiguous table reference detected

Found: "orders" in script
Could be:
- dbo.orders
- sales.orders
- temp.orders

Which schema should I use?
```

### No Tables Found
```
❌ Error: No tables detected in script

The script doesn't reference any user tables.

This could mean:
- Script only queries system views (sys.*)
- Script has syntax errors
- Script uses dynamic SQL

Cannot proceed without table definitions.
```

---

## Output Summary

**Variables to preserve:**
- `table_definitions`: Complete schema
- `detected_qds_query`: Boolean
- `script_analysis`: Full analysis object
- `expected_indexes`: Index definitions
- `join_relationships`: Table relationships

**Files created:**
- `schema/create_tables.sql`
- `schema/create_indexes.sql`
- `schema/table_definitions.json`
- `script_analysis.json`

**Ready for Phase 3:** YES

---

**End of Phase 2 Implementation**
