# NetmonitorWidget

**Parent:** [../AGENTS.md](../AGENTS.md)
**Generated:** 2026-02-15

## Purpose

iOS widget extension displaying network status at a glance. Supports small, medium, and large widget families with live connection status, latency, speeds, and device count.

## Key Files

| File | Purpose |
|------|---------|
| `NetmonitorWidget.swift` | Widget definition, timeline provider, and all widget views (small/medium/large) |

## For AI Agents

### Widget Architecture

1. **Timeline Provider:** `NetworkStatusProvider` reads cached data from shared UserDefaults (`group.com.blakemiller.netmonitor`).
2. **Timeline Entry:** `NetworkStatusEntry` contains all widget state (connection status, SSID, IP, latency, speeds, device count).
3. **Widget Families:** Three supported sizes with different layouts:
   - **Small:** Connection status + SSID + latency
   - **Medium:** Connection status + speeds + device count
   - **Large:** Full grid with all stats
4. **Refresh Policy:** Timeline refreshes every 15 minutes via `.after(nextUpdate)` policy.

### Data Flow

1. Main app writes network status to `UserDefaults(suiteName: "group.com.blakemiller.netmonitor")`.
2. Widget reads from shared UserDefaults via `NetworkStatusProvider.getTimeline()`.
3. Widget displays cached data until next timeline refresh.

### Shared UserDefaults Keys

- `widget_isConnected` (Bool)
- `widget_connectionType` (String)
- `widget_ssid` (String?)
- `widget_publicIP` (String?)
- `widget_gatewayLatency` (String?)
- `widget_deviceCount` (Int)
- `widget_downloadSpeed` (String?)
- `widget_uploadSpeed` (String?)

### Working Instructions

- **Modifying Widget UI:** Edit `SmallWidgetView`, `MediumWidgetView`, or `LargeWidgetView` in `NetmonitorWidget.swift`.
- **Adding Data Fields:** Add new key to `NetworkStatusEntry`, read from shared UserDefaults in `getTimeline()`, update views.
- **Changing Refresh Interval:** Modify `nextUpdate` calculation in `getTimeline()` (current: 15 minutes).
- **App Group:** Ensure `group.com.blakemiller.netmonitor` is configured in both app and widget targets.

### Testing

1. Build widget target alongside main app.
2. Add widget to home screen in simulator.
3. Use "Debug Widget" in Xcode to test timeline updates.
4. Verify shared UserDefaults writes from main app.

### Dependencies

- WidgetKit framework
- SwiftUI
- Shared app group (`group.com.blakemiller.netmonitor`)

### Widget Families

- `.systemSmall` - Minimal status view
- `.systemMedium` - Split view with stats
- `.systemLarge` - Full detail grid

### Previews

Three preview configurations provided for each widget size using `NetworkStatusEntry.placeholder`.
