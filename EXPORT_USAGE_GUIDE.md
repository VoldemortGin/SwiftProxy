# Statistics Export - Quick Usage Guide

## Quick Start (3 Steps)

1. **Click Export Button**
   - Navigate to Statistics view
   - Click "Export" button in the top-right corner

2. **Configure Export**
   - Choose format: CSV or JSON
   - Select date range (Today, Last 7 Days, etc.)
   - Pick a template (Basic Info, Full Details, etc.)

3. **Save File**
   - Click "Export..." button
   - Choose save location
   - Click "Save"

## Common Use Cases

### Use Case 1: Quick Daily Report (CSV)
**Goal**: Export today's traffic for Excel analysis

1. Click "Export"
2. Select "CSV" format
3. Choose "Today" date range
4. Select "Basic Info" template
5. Click "Export..."
6. Save as `daily_report_2025-01-15.csv`

**Result**: Simple CSV file with essential fields that opens in Excel

---

### Use Case 2: Performance Analysis (JSON)
**Goal**: Analyze performance metrics programmatically

1. Click "Export"
2. Select "JSON" format
3. Choose "Last 7 Days" date range
4. Select "Performance Metrics" template
5. Enable "Pretty Print JSON"
6. Click "Export..."
7. Save as `performance_analysis.json`

**Result**: JSON file with timing, latency, and throughput data

---

### Use Case 3: Security Audit (CSV with Filters)
**Goal**: Export only HTTPS failed connections for security review

1. Click "Export"
2. Select "CSV" format
3. Choose "This Month" date range
4. Select "Security Analysis" template
5. Under Filters:
   - Click "HTTPS" protocol toggle
   - Click "Failed" state toggle
6. Enable "Include Metadata"
7. Check preview shows expected record count
8. Click "Export..."
9. Save as `security_audit_failed_https.csv`

**Result**: CSV with only HTTPS failed connections

---

### Use Case 4: Error Investigation (JSON Full Export)
**Goal**: Export all data for a specific time period to investigate errors

1. Click "Export"
2. Select "JSON" format
3. Choose "Custom Range" date range
4. Set start: "Jan 15, 2025 at 2:00 PM"
5. Set end: "Jan 15, 2025 at 3:00 PM"
6. Select "Full Details" template
7. Under Filters:
   - Click "Failed" state toggle
   - Click "4xx Client Error" status code toggle
   - Click "5xx Server Error" status code toggle
8. Enable "Include Metadata"
9. Enable "Pretty Print JSON"
10. Check preview shows matching records
11. Click "Export..."
12. Save as `error_investigation_1400-1500.json`

**Result**: Complete data for failed connections in that hour

---

### Use Case 5: API Traffic Analysis
**Goal**: Export only API calls to specific domains

1. Click "Export"
2. Select "CSV" format
3. Choose "Last 30 Days" date range
4. Select "Full Details" template
5. Under Filters:
   - Click "HTTPS" protocol toggle
   - Click "Closed" state toggle
   - Click "2xx Success" status code toggle
6. Click "Export..."
7. Save as `api_traffic_30days.csv`
8. Open in Excel and filter by host column

**Result**: All successful API traffic for the month

---

## Filter Combinations

### Common Filter Scenarios

#### 1. Successful HTTPS Only
```
Protocols: [HTTPS]
States: [Closed]
Status Codes: [2xx Success]
```

#### 2. All Errors
```
States: [Failed]
Status Codes: [4xx Client Error, 5xx Server Error]
```

#### 3. Active/In-Progress Connections
```
States: [Connecting, Connected]
```

#### 4. High-Traffic Connections
```
(In future: Min Bytes Transferred: 1048576) # 1MB+
```

## Template Selection Guide

| Template | Best For | Fields Included |
|----------|----------|----------------|
| **Basic Info** | Quick reports, Excel analysis | 8 core fields: timestamp, host, port, protocol, state, bytes |
| **Full Details** | Complete data export, debugging | All 25+ available fields |
| **Performance Metrics** | Performance tuning, latency analysis | 8 performance fields: timing, rates, latency |
| **Security Analysis** | Security audits, error investigation | 8 security fields: protocols, ports, status codes, errors |
| **Custom Fields** | Specialized needs | User-selected fields |

## Date Range Reference

| Range | Description | Example |
|-------|-------------|---------|
| **Today** | Midnight to now | Jan 15, 12:00 AM - 10:30 AM |
| **Yesterday** | All of previous day | Jan 14, 12:00 AM - 11:59 PM |
| **This Week** | Start of week to now | Jan 10 (Sun) - Jan 15 |
| **This Month** | Start of month to now | Jan 1 - Jan 15 |
| **Last 7 Days** | Rolling 7-day window | Jan 8 - Jan 15 |
| **Last 30 Days** | Rolling 30-day window | Dec 16 - Jan 15 |
| **All Time** | All recorded data | Earliest - Now |
| **Custom Range** | User-defined period | Jan 10, 2:00 PM - Jan 12, 5:30 PM |

## Format Comparison

| Feature | CSV | JSON |
|---------|-----|------|
| **Excel Compatible** | ✅ Yes | ❌ No |
| **Human Readable** | ✅ Yes | ✅ Yes (with Pretty Print) |
| **Metadata Support** | ✅ Yes (comments) | ✅ Yes (structured) |
| **Nested Data** | ❌ No | ✅ Yes |
| **Type Safety** | ❌ All strings | ✅ Numbers as numbers |
| **File Size** | Smaller | Larger (especially pretty) |
| **Programmatic Use** | ⚠️ Medium | ✅ Easy |
| **Summary Stats** | ❌ No | ✅ Yes |

## Tips & Tricks

### 1. Preview Before Export
Always check the "Estimated Records" count in the preview section before exporting. If it shows 0, adjust your filters or date range.

### 2. Metadata Helps Later
Enable "Include Metadata" so you know what filters were applied when you look at the file months later.

### 3. Use Templates First
Start with built-in templates before creating custom field selections. They cover 90% of use cases.

### 4. Filename Convention
Use descriptive filenames with dates:
- Good: `swiftproxy_statistics_2025-01-15_1430.csv`
- Better: `api_errors_jan15_14-15hrs.csv`
- Best: `security_audit_failed_https_jan2025.csv`

### 5. CSV for Spreadsheets, JSON for Code
- Use CSV when analyzing in Excel/Numbers
- Use JSON when processing with scripts/code
- Use JSON Pretty Print when reading by eye

### 6. Combine Filters for Precision
Don't use just one filter. Combine multiple filters for precise results:
```
Protocols: [HTTPS]
+ States: [Failed]
+ Status Codes: [5xx Server Error]
= Precise: HTTPS connections that failed with server errors
```

### 7. Custom Range for Incidents
When investigating specific incidents, use "Custom Range" to focus on the exact time period.

### 8. Regular Exports
Set a reminder to export statistics weekly or monthly for historical analysis.

## Keyboard Shortcuts

| Action | Shortcut |
|--------|----------|
| Open Export | None (click button) |
| Close Sheet | `Esc` or `⌘W` |
| Export | `⌘S` (in save dialog) |

## Troubleshooting

### Problem: "No records match the current filters"
**Solution**:
- Widen date range (e.g., change "Today" to "Last 7 Days")
- Remove or adjust filters
- Check if proxy has been running and capturing traffic

### Problem: Export button is disabled
**Solution**:
- Estimated records must be > 0
- Check filters and date range
- Ensure there's data in that period

### Problem: File is empty or very small
**Solution**:
- Check "Estimated Records" before exporting
- Verify filters aren't too restrictive
- Confirm date range includes traffic

### Problem: CSV won't open in Excel
**Solution**:
- File should be UTF-8 encoded (default)
- Try "Import" instead of "Open" in Excel
- Verify file extension is `.csv`

### Problem: JSON is unreadable
**Solution**:
- Enable "Pretty Print JSON" before export
- Use JSON viewer/formatter online
- Use `jq` command: `jq . file.json`

## Advanced Usage

### Scripting Exports

While GUI export is manual, you can process exported JSON files with scripts:

```bash
# Count total requests
jq '.connections | length' export.json

# Find connections over 1MB
jq '.connections[] | select(.["Total Bytes"] > 1048576)' export.json

# Average response time
jq '[.connections[].Duration] | add / length' export.json

# Group by host
jq 'group_by(.Host)' export.json
```

### Excel Analysis

After exporting CSV:
1. Open in Excel
2. Create pivot table (Insert > Pivot Table)
3. Analyze by:
   - Host (rows) vs Total Bytes (values)
   - Status Code (rows) vs Count (values)
   - Hour (rows) vs Requests (values)

### Combining Multiple Exports

Export different date ranges and combine:
```bash
# Combine CSVs (skip headers of second file)
cat export1.csv > combined.csv
tail -n +2 export2.csv >> combined.csv
tail -n +2 export3.csv >> combined.csv
```

## Support

For issues or questions:
1. Check this guide
2. Review EXPORT_FEATURE_DOCUMENTATION.md
3. Check application logs
4. Report bugs with:
   - Configuration used
   - Estimated record count
   - Error message (if any)

## Version

This guide is for SwiftProxy Statistics Export v1.0
Last updated: January 2025
