# Implementation Plan

- [ ] 1. Set up project structure and core data models
  - Remove default SwiftData boilerplate (Item.swift, ContentView.swift)
  - Create directory structure: Models/, Monitors/, Hotkeys/, Rendering/, Preferences/, Coordinators/
  - Define TrackedApplication model with all properties
  - Define HotkeyConfiguration model with modifier flags
  - Define AppSwitcherPreferences model with all settings
  - Define PermissionStatus enum
  - Define BadgeStyle and BadgeViewModel models
  - _Requirements: 1.1, 1.2, 4.1, 4.4_

- [x] 1.1 Write property test for data models
  - **Property 7: Preference persistence round-trip**
  - **Validates: Requirements 4.4**

- [x] 2. Implement Accessibility API helper and permission checking
  - Create AccessibilityHelper class with permission checking methods
  - Implement AXIsProcessTrusted() wrapper
  - Implement window enumeration using AXUIElementCopyAttributeValue
  - Implement window frame retrieval for applications
  - Add error handling for Accessibility API failures
  - _Requirements: 8.1, 8.3, 10.3_

- [x] 2.1 Write unit tests for AccessibilityHelper
  - Test permission status detection
  - Test window enumeration with mock data
  - Test error handling for API failures
  - _Requirements: 8.1, 10.3_

- [x] 3. Implement Application Monitor
  - Create ApplicationMonitor class with ObservableObject conformance
  - Implement startMonitoring() using NSWorkspace notifications
  - Implement refreshApplicationList() to enumerate running apps
  - Filter out background apps and apps without windows
  - Implement number assignment algorithm (1-9, 0)
  - Implement getApplication(forNumber:) lookup method
  - Add delegate protocol for application updates
  - _Requirements: 1.1, 1.2, 6.1, 6.2_

- [x] 3.1 Write property test for application enumeration
  - **Property 1: Application enumeration completeness**
  - **Validates: Requirements 1.1**

- [x] 3.2 Write property test for number assignment
  - **Property 2: Number assignment uniqueness**
  - **Validates: Requirements 1.2**

- [x] 3.3 Write property test for application list updates
  - **Property 8: Application list updates on launch/quit**
  - **Validates: Requirements 6.1, 6.2**

- [x] 3.4 Write property test for number reassignment
  - **Property 9: Number reassignment on removal**
  - **Validates: Requirements 6.2**

- [x] 4. Implement window position tracking
  - Add timer-based polling (500ms) for window position updates
  - Implement window frame caching to detect changes
  - Update TrackedApplication windowFrame property on changes
  - Notify delegate when window positions change
  - _Requirements: 1.4, 6.5_

- [x] 4.1 Write property test for badge position tracking
  - **Property 3: Badge position follows window**
  - **Validates: Requirements 1.4**

- [x] 5. Implement Hotkey Manager with global event tap
  - Create HotkeyManager class
  - Implement CGEvent tap creation for keyboard events
  - Register event tap for keyDown and flagsChanged events
  - Implement modifier key state detection (Option, Control, Command, Shift)
  - Map number keys (0-9) to key codes
  - Add delegate protocol for hotkey events and modifier state changes
  - Implement error handling for event tap creation failures
  - _Requirements: 2.1, 2.3, 3.1, 3.2_

- [x] 5.1 Write property test for hotkey activation
  - **Property 4: Hotkey activation correctness**
  - **Validates: Requirements 2.1, 2.2**

- [x] 5.2 Write property test for invalid hotkey handling
  - **Property 5: Invalid hotkey ignored**
  - **Validates: Requirements 2.3**

- [x] 5.3 Write unit tests for key code mapping
  - Test number key to key code conversion
  - Test modifier flag detection
  - _Requirements: 2.1_

- [x] 6. Implement Badge Renderer with SwiftUI overlays
  - Create BadgeRenderer class with ObservableObject conformance
  - Create BadgeWindow class (NSWindow subclass) for borderless transparent windows
  - Create BadgeView SwiftUI view with number display and styling
  - Implement showBadges(for:) to create and position badge windows
  - Implement hideBadges() to remove all badge windows
  - Set window level to .floatingWindow
  - Implement badge position calculation (top-left corner + offset)
  - _Requirements: 1.3, 3.1, 3.2, 3.4_

- [x] 6.1 Write unit tests for badge position calculation
  - Test position calculation from window frames
  - Test offset application
  - _Requirements: 1.3_

- [x] 6.2 Write property test for overlay visibility
  - **Property 6: Overlay visibility on modifier press**
  - **Validates: Requirements 3.1, 3.2**

- [x] 7. Implement badge animations and visual feedback
  - Add fade-in/fade-out animations (50ms duration)
  - Implement highlightBadge(number:duration:) for visual feedback
  - Add color pulse animation for highlights (200ms)
  - Implement updateBadgePositions(for:) with smooth transitions
  - _Requirements: 7.1, 7.2_

- [x] 7.1 Write property test for visual feedback timing
  - **Property 10: Visual feedback timing**
  - **Validates: Requirements 7.1, 7.2**

- [x] 8. Implement Preferences Manager
  - Create PreferencesManager class with ObservableObject conformance
  - Implement loadPreferences() using UserDefaults
  - Implement savePreferences() with JSON encoding
  - Implement resetToDefaults() with default configuration
  - Implement setLaunchAtLogin() using SMLoginItemSetEnabled
  - Add default values for all preferences
  - _Requirements: 4.4, 5.4, 9.5_

- [x] 8.1 Write unit tests for preference serialization
  - Test JSON encoding/decoding of preferences
  - Test default values
  - _Requirements: 4.4_

- [x] 9. Implement Preferences UI with SwiftUI
  - Create PreferencesView SwiftUI view
  - Add modifier key selection picker
  - Add application list with drag-to-reorder
  - Add exclude application checkboxes
  - Add launch at login toggle
  - Add badge style customization controls
  - Create PreferencesWindow to host the SwiftUI view
  - _Requirements: 4.1, 4.2, 5.1, 5.2_

- [x] 9.1 Write unit tests for preferences UI interactions
  - Test modifier key selection updates configuration
  - Test application reordering updates number assignments
  - Test exclusion logic
  - _Requirements: 4.2, 5.2, 5.3_

- [x] 10. Implement Application Coordinator
  - Create ApplicationCoordinator class with MainActor isolation
  - Initialize all component instances (monitor, hotkey manager, badge renderer, preferences)
  - Implement ApplicationMonitorDelegate methods
  - Implement HotkeyManagerDelegate methods
  - Implement start() to begin monitoring and register hotkeys
  - Implement switchToApplication(number:) using NSRunningApplication.activate()
  - Coordinate modifier key state with badge visibility
  - Implement checkPermissions() and requestPermissions()
  - _Requirements: 2.1, 2.2, 3.1, 3.2, 8.1, 8.3_

- [x] 10.1 Write unit tests for coordinator logic
  - Test component coordination
  - Test app switching logic
  - Test permission checking
  - _Requirements: 2.1, 8.1_

- [x] 10.2 Write property test for permission check accuracy
  - **Property 11: Permission check accuracy**
  - **Validates: Requirements 8.1, 8.3**

- [x] 10.3 Write property test for single overlay per application
  - **Property 12: Single overlay per application**
  - **Validates: Requirements 10.2**

- [x] 11. Implement menu bar agent and app lifecycle
  - Convert manicoApp.swift to menu bar agent (remove WindowGroup)
  - Create AppDelegate with NSApplicationDelegate conformance
  - Add menu bar status item with icon
  - Create menu with "Preferences", "Quit", and status items
  - Initialize ApplicationCoordinator in AppDelegate
  - Handle app termination and cleanup
  - _Requirements: 9.1, 9.2_

- [x] 11.1 Write unit tests for menu bar functionality
  - Test menu item creation
  - Test menu actions
  - _Requirements: 9.1, 9.2_

- [x] 12. Implement permission request flow
  - Create permission request dialog with explanation
  - Add "Open System Preferences" button that opens Accessibility settings
  - Show permission status in menu bar when denied
  - Implement permission state monitoring
  - Disable functionality gracefully when permissions denied
  - _Requirements: 8.2, 8.4, 8.5_

- [x] 12.1 Write unit tests for permission flow
  - Test permission dialog display logic
  - Test functionality disable when denied
  - _Requirements: 8.2, 8.4_

- [-] 13. Implement edge case handling
  - Handle crashed/unresponsive applications (check isTerminated)
  - Handle multiple windows per application (show single overlay)
  - Handle system sleep/wake (refresh app list on wake)
  - Handle display configuration changes (update badge positions)
  - Handle >10 running applications (assign numbers to first 10 only)
  - _Requirements: 10.1, 10.2, 10.4, 10.5, 6.3_

- [ ] 13.1 Write unit tests for edge cases
  - Test crashed app detection and removal
  - Test >10 apps scenario
  - Test multiple windows per app
  - _Requirements: 10.1, 10.2, 6.3_

- [ ] 14. Add logging and error reporting
  - Implement unified logging using os_log
  - Add log statements for all major operations
  - Add error logging for Accessibility API failures
  - Add error logging for hotkey registration failures
  - Add performance logging for app switching timing
  - _Requirements: 10.3_

- [ ] 15. Final integration and polish
  - Test complete workflow: launch → permissions → monitor → hotkey → switch
  - Verify badge appearance on multiple displays
  - Test with various application types (native, Electron, Java)
  - Verify no conflicts with system shortcuts
  - Optimize performance (caching, debouncing)
  - _Requirements: All_

- [ ] 16. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.



