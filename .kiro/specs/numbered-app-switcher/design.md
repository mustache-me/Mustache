# Design Document: Numbered App Switcher

## Overview

The Numbered App Switcher is a macOS menu bar application built with SwiftUI and AppKit that provides quick keyboard-based application switching. The system consists of four main components: an Application Monitor that tracks running apps, a Hotkey Manager that captures keyboard input, a Badge Renderer that displays numbered overlays, and a Preferences Manager that handles user configuration.

The application uses macOS Accessibility APIs to enumerate windows, Carbon Event Manager or modern CGEvent APIs for global hotkey registration, and SwiftUI overlays for rendering numbered badges. The architecture emphasizes separation of concerns, with clear boundaries between window management, input handling, and UI rendering.

## Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      Menu Bar Agent                          │
│  ┌────────────────────────────────────────────────────────┐ │
│  │              Application Coordinator                    │ │
│  └────────────────────────────────────────────────────────┘ │
│         │              │              │              │       │
│         ▼              ▼              ▼              ▼       │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐   │
│  │   App    │  │  Hotkey  │  │  Badge   │  │   Prefs  │   │
│  │ Monitor  │  │ Manager  │  │ Renderer │  │ Manager  │   │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘   │
│         │              │              │              │       │
└─────────┼──────────────┼──────────────┼──────────────┼───────┘
          │              │              │              │
          ▼              ▼              ▼              ▼
    ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐
    │Accessib. │  │  CGEvent │  │  SwiftUI │  │UserDefau.│
    │   API    │  │   Tap    │  │  Window  │  │   lts    │
    └──────────┘  └──────────┘  └──────────┘  └──────────┘
```

### Component Responsibilities

1. **Application Coordinator**: Orchestrates communication between components and manages application lifecycle
2. **Application Monitor**: Tracks running applications, assigns numbers, and detects changes
3. **Hotkey Manager**: Registers global hotkeys, captures keyboard events, and triggers app switching
4. **Badge Renderer**: Creates and positions numbered overlay windows on top of application windows
5. **Preferences Manager**: Persists and loads user configuration (modifier keys, app ordering, launch at login)

## Components and Interfaces

### 1. Application Monitor

**Purpose**: Track running applications and maintain the numbered application list.

**Key Types**:
```swift
struct TrackedApplication: Identifiable, Equatable {
    let id: pid_t
    let bundleIdentifier: String
    let name: String
    let icon: NSImage
    var assignedNumber: Int?
    var isActive: Bool
    var windowFrame: CGRect?
}

protocol ApplicationMonitorDelegate: AnyObject {
    func applicationsDidUpdate(_ applications: [TrackedApplication])
    func applicationDidActivate(_ application: TrackedApplication)
}
```

**Interface**:
```swift
class ApplicationMonitor: ObservableObject {
    @Published var trackedApplications: [TrackedApplication] = []
    weak var delegate: ApplicationMonitorDelegate?
    
    func startMonitoring()
    func stopMonitoring()
    func refreshApplicationList()
    func getApplication(forNumber number: Int) -> TrackedApplication?
    func updateApplicationOrdering(_ newOrder: [pid_t])
}
```

**Implementation Details**:
- Uses `NSWorkspace.shared.runningApplications` to enumerate apps
- Filters out background apps and apps without windows using Accessibility API
- Uses `NSWorkspace.didLaunchApplicationNotification` and `NSWorkspace.didTerminateApplicationNotification` for real-time updates
- Polls window positions every 500ms using `AXUIElementCopyAttributeValue` for window frames
- Assigns numbers 1-9, 0 to first ten applications based on ordering strategy

### 2. Hotkey Manager

**Purpose**: Register and handle global keyboard shortcuts for app switching.

**Key Types**:
```swift
struct HotkeyConfiguration: Codable, Equatable {
    var modifierFlags: CGEventFlags
    var showOverlaysOnModifierOnly: Bool
}

protocol HotkeyManagerDelegate: AnyObject {
    func hotkeyPressed(number: Int)
    func modifierKeyStateChanged(isPressed: Bool)
}
```

**Interface**:
```swift
class HotkeyManager {
    weak var delegate: HotkeyManagerDelegate?
    var configuration: HotkeyConfiguration
    
    func registerHotkeys() throws
    func unregisterHotkeys()
    func updateConfiguration(_ newConfig: HotkeyConfiguration) throws
}
```

**Implementation Details**:
- Uses `CGEvent.tapCreate` to create a global event tap for keyboard events
- Monitors `CGEventType.keyDown` and `CGEventType.flagsChanged` events
- Detects modifier key state (Option, Control, Command, Shift) from `CGEventFlags`
- Maps number keys (0-9) to their key codes (29, 18-25, 26)
- Validates hotkey combinations against system shortcuts using `CGEventSourceKeyState`
- Runs event tap on a separate dispatch queue to avoid blocking main thread

### 3. Badge Renderer

**Purpose**: Display numbered overlays on application windows.

**Key Types**:
```swift
struct BadgeStyle {
    var backgroundColor: Color
    var textColor: Color
    var fontSize: CGFloat
    var padding: CGFloat
    var cornerRadius: CGFloat
    var opacity: Double
}

struct BadgeViewModel: Identifiable {
    let id: pid_t
    let number: Int
    let position: CGPoint
    var isHighlighted: Bool
}
```

**Interface**:
```swift
class BadgeRenderer: ObservableObject {
    @Published var badges: [BadgeViewModel] = []
    var style: BadgeStyle
    var isVisible: Bool
    
    func showBadges(for applications: [TrackedApplication])
    func hideBadges()
    func highlightBadge(number: Int, duration: TimeInterval)
    func updateBadgePositions(for applications: [TrackedApplication])
}
```

**Implementation Details**:
- Creates borderless, transparent `NSWindow` instances for each badge
- Sets window level to `CGWindowLevelForKey(.floatingWindow)` to appear above all apps
- Uses SwiftUI `Text` views with custom styling for badge content
- Positions badges at top-left corner of application windows with 10pt offset
- Implements fade-in/fade-out animations using `withAnimation` (50ms duration)
- Highlight animation uses color pulse effect (200ms duration)
- Updates badge positions on a 100ms timer when visible

### 4. Preferences Manager

**Purpose**: Persist and manage user configuration.

**Key Types**:
```swift
struct AppSwitcherPreferences: Codable {
    var hotkeyConfiguration: HotkeyConfiguration
    var customApplicationOrder: [String]? // Bundle identifiers
    var excludedApplications: Set<String>
    var launchAtLogin: Bool
    var badgeStyle: BadgeStyle
}
```

**Interface**:
```swift
class PreferencesManager: ObservableObject {
    @Published var preferences: AppSwitcherPreferences
    
    func loadPreferences()
    func savePreferences()
    func resetToDefaults()
    func setLaunchAtLogin(_ enabled: Bool)
}
```

**Implementation Details**:
- Uses `UserDefaults.standard` for persistence with key "com.manico.preferences"
- Encodes/decodes preferences using `JSONEncoder`/`JSONDecoder`
- Default modifier key: Option (`.maskAlternate`)
- Default badge style: semi-transparent black background, white text, 24pt font
- Launch at login implemented using `SMLoginItemSetEnabled` (Service Management framework)

### 5. Application Coordinator

**Purpose**: Coordinate between all components and manage application state.

**Interface**:
```swift
@MainActor
class ApplicationCoordinator: ObservableObject {
    let applicationMonitor: ApplicationMonitor
    let hotkeyManager: HotkeyManager
    let badgeRenderer: BadgeRenderer
    let preferencesManager: PreferencesManager
    
    @Published var permissionStatus: PermissionStatus
    
    func start()
    func stop()
    func switchToApplication(number: Int)
    func checkPermissions() -> PermissionStatus
    func requestPermissions()
}
```

**Implementation Details**:
- Implements `ApplicationMonitorDelegate` and `HotkeyManagerDelegate`
- On `hotkeyPressed(number:)`: calls `switchToApplication(number:)` which activates the app using `NSRunningApplication.activate(options:)`
- On `modifierKeyStateChanged(isPressed:)`: shows/hides badges via `BadgeRenderer`
- On `applicationsDidUpdate(_:)`: updates badge positions and assignments
- Checks Accessibility permissions using `AXIsProcessTrusted()`
- Coordinates preference changes across all components

## Data Models

### TrackedApplication
Represents a running application with its metadata and assigned number.

```swift
struct TrackedApplication: Identifiable, Equatable {
    let id: pid_t                    // Process ID
    let bundleIdentifier: String     // e.g., "com.apple.Safari"
    let name: String                 // Display name
    let icon: NSImage                // App icon
    var assignedNumber: Int?         // 0-9, nil if not assigned
    var isActive: Bool               // Currently frontmost
    var windowFrame: CGRect?         // Main window position
    
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id && 
        lhs.assignedNumber == rhs.assignedNumber &&
        lhs.isActive == rhs.isActive
    }
}
```

### HotkeyConfiguration
Defines the keyboard shortcut configuration.

```swift
struct HotkeyConfiguration: Codable, Equatable {
    var modifierFlags: CGEventFlags  // e.g., .maskAlternate for Option
    var showOverlaysOnModifierOnly: Bool  // Show badges when modifier held
    
    // Helper computed properties
    var modifierDescription: String {
        // Returns "Option", "Control", "Command", etc.
    }
}
```

### AppSwitcherPreferences
Complete user preferences model.

```swift
struct AppSwitcherPreferences: Codable {
    var hotkeyConfiguration: HotkeyConfiguration
    var customApplicationOrder: [String]?  // Bundle IDs in preferred order
    var excludedApplications: Set<String>  // Bundle IDs to exclude
    var launchAtLogin: Bool
    var badgeStyle: BadgeStyle
    
    static var defaults: AppSwitcherPreferences {
        // Returns default configuration
    }
}
```

### PermissionStatus
Tracks Accessibility API permission state.

```swift
enum PermissionStatus {
    case notDetermined
    case granted
    case denied
}
```

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system—essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: Application enumeration completeness
*For any* set of running applications with visible windows, when the Application Monitor enumerates applications, all applications with visible windows should appear in the tracked applications list.
**Validates: Requirements 1.1**

### Property 2: Number assignment uniqueness
*For any* tracked application list, each assigned number (1-9, 0) should map to exactly one application, and no two applications should have the same assigned number.
**Validates: Requirements 1.2**

### Property 3: Badge position follows window
*For any* application window, when the window moves to a new position, the badge position should be updated to match the new window position within the update interval.
**Validates: Requirements 1.4**

### Property 4: Hotkey activation correctness
*For any* valid hotkey combination (modifier + number), when pressed, the system should activate the application assigned to that number, and that application should become frontmost.
**Validates: Requirements 2.1, 2.2**

### Property 5: Invalid hotkey ignored
*For any* number key pressed without an assigned application, the system should maintain the current application state unchanged.
**Validates: Requirements 2.3**

### Property 6: Overlay visibility on modifier press
*For any* modifier key state, when the modifier key is pressed and held, all badges should become visible within 50ms, and when released, all badges should become hidden within 50ms.
**Validates: Requirements 3.1, 3.2, 3.3**

### Property 7: Preference persistence round-trip
*For any* valid preferences configuration, saving then loading the preferences should produce an equivalent configuration.
**Validates: Requirements 4.4, 5.4**

### Property 8: Application list updates on launch/quit
*For any* application launch or quit event, the Application Monitor should detect the change and update the tracked applications list within 200ms.
**Validates: Requirements 6.1, 6.2, 6.4**

### Property 9: Number reassignment on removal
*For any* tracked application list, when an application is removed, the remaining applications should maintain their relative ordering, and numbers should be reassigned sequentially without gaps (up to 10 apps).
**Validates: Requirements 6.2**

### Property 10: Visual feedback timing
*For any* valid hotkey press, the corresponding badge should display a highlight effect for exactly 200ms before returning to normal appearance.
**Validates: Requirements 7.1, 7.2**

### Property 11: Permission check accuracy
*For any* permission state, the system's reported permission status should match the actual Accessibility API permission state as reported by `AXIsProcessTrusted()`.
**Validates: Requirements 8.1, 8.3**

### Property 12: Single overlay per application
*For any* application with multiple windows, the Badge Renderer should display exactly one numbered overlay for that application.
**Validates: Requirements 10.2**

## Error Handling

### Accessibility API Errors
- **Missing Permissions**: Display alert dialog with instructions to enable Accessibility access in System Preferences
- **API Call Failures**: Log error, continue with cached data, retry on next refresh cycle
- **Invalid Window References**: Skip the window, continue processing other windows

### Hotkey Registration Errors
- **Conflicting Shortcuts**: Display warning in Preferences panel, suggest alternative modifier keys
- **Event Tap Creation Failure**: Fall back to polling-based modifier key detection (less responsive but functional)
- **Permission Denied**: Disable hotkey functionality, show status in menu bar

### Application Monitoring Errors
- **Crashed Applications**: Detect via `NSRunningApplication.isTerminated`, remove from list immediately
- **Unresponsive Applications**: Timeout Accessibility API calls after 100ms, use cached window data
- **Missing Application Info**: Use fallback values (generic icon, process name as display name)

### Preferences Errors
- **Corrupted Preferences File**: Reset to defaults, log error, notify user via menu bar
- **Invalid Configuration**: Validate on load, use defaults for invalid fields, save corrected version
- **Launch at Login Failure**: Log error, disable the feature, show warning in Preferences

### General Error Handling Strategy
- All errors logged to unified logging system using `os_log`
- Non-critical errors handled gracefully without user interruption
- Critical errors (permissions, hotkey registration) communicated via UI
- Automatic recovery attempted for transient failures
- User notified only when action is required

## Testing Strategy

### Unit Testing

The application will use XCTest framework for unit testing. Unit tests will focus on:

- **Data Model Validation**: Test `TrackedApplication`, `HotkeyConfiguration`, and `AppSwitcherPreferences` initialization and equality
- **Preference Serialization**: Test encoding/decoding of preferences to/from JSON
- **Number Assignment Logic**: Test the algorithm that assigns numbers 1-9, 0 to applications
- **Hotkey Key Code Mapping**: Test conversion between number keys and their key codes
- **Permission Status Detection**: Test `PermissionStatus` state transitions
- **Badge Position Calculation**: Test the algorithm that calculates badge positions from window frames

### Property-Based Testing

The application will use the **swift-check** library for property-based testing. Each property test will run a minimum of 100 iterations with randomly generated inputs.

Property tests will be implemented for each correctness property defined above:

1. **Property 1 Test**: Generate random sets of mock running applications, verify all are enumerated
2. **Property 2 Test**: Generate random application lists, verify number uniqueness after assignment
3. **Property 3 Test**: Generate random window positions, verify badge positions update correctly
4. **Property 4 Test**: Generate random hotkey combinations with valid numbers, verify correct app activation
5. **Property 5 Test**: Generate random invalid number keys, verify state remains unchanged
6. **Property 6 Test**: Generate random modifier key press/release sequences, verify badge visibility timing
7. **Property 7 Test**: Generate random valid preferences, verify save/load round-trip produces equivalent config
8. **Property 8 Test**: Generate random app launch/quit events, verify list updates within time bound
9. **Property 9 Test**: Generate random application removal scenarios, verify correct number reassignment
10. **Property 10 Test**: Generate random hotkey presses, verify highlight timing is exactly 200ms
11. **Property 11 Test**: Generate random permission states, verify reported status matches actual state
12. **Property 12 Test**: Generate random applications with multiple windows, verify single overlay per app

Each property-based test will be tagged with a comment in the following format:
```swift
// Feature: numbered-app-switcher, Property 1: Application enumeration completeness
func testApplicationEnumerationCompleteness() { ... }
```

### Integration Testing

- Test full workflow: launch app → grant permissions → monitor apps → press hotkey → switch app
- Test preferences workflow: change settings → save → restart app → verify settings loaded
- Test edge cases: rapid app launches, system sleep/wake, display configuration changes

### Manual Testing Checklist

- Verify badges appear correctly on all displays in multi-monitor setup
- Test with various applications (native, Electron, Java, etc.)
- Verify no conflicts with existing system shortcuts
- Test performance with 50+ running applications
- Verify menu bar icon and menu functionality

## Implementation Notes

### SwiftUI vs AppKit
- Use SwiftUI for Preferences panel and badge content rendering
- Use AppKit for menu bar agent, window management, and global event handling
- Bridge between SwiftUI and AppKit using `NSHostingView` and `NSHostingController`

### Performance Considerations
- Cache application icons to avoid repeated loading
- Debounce window position updates to reduce CPU usage
- Use background queues for Accessibility API calls
- Minimize badge window redraws by updating only when positions change

### macOS Version Compatibility
- Target macOS 13.0+ for modern SwiftUI features
- Use `@available` checks for newer APIs
- Provide fallbacks for older macOS versions where possible

### Accessibility API Best Practices
- Always check `AXIsProcessTrusted()` before making API calls
- Handle `kAXErrorAPIDisabled` gracefully
- Use `AXObserver` for efficient window event monitoring where possible
- Respect user privacy by only accessing necessary window information

### Code Organization
```
manico/
├── App/
│   ├── manicoApp.swift (Menu bar agent entry point)
│   └── AppDelegate.swift (AppKit app delegate)
├── Coordinators/
│   └── ApplicationCoordinator.swift
├── Monitors/
│   ├── ApplicationMonitor.swift
│   └── AccessibilityHelper.swift
├── Hotkeys/
│   ├── HotkeyManager.swift
│   └── EventTapHandler.swift
├── Rendering/
│   ├── BadgeRenderer.swift
│   ├── BadgeWindow.swift
│   └── BadgeView.swift (SwiftUI)
├── Preferences/
│   ├── PreferencesManager.swift
│   ├── PreferencesWindow.swift
│   └── PreferencesView.swift (SwiftUI)
├── Models/
│   ├── TrackedApplication.swift
│   ├── HotkeyConfiguration.swift
│   └── AppSwitcherPreferences.swift
└── Tests/
    ├── UnitTests/
    └── PropertyTests/
```
