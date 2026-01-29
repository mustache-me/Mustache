# Requirements Document

## Introduction

The Mustache application crashes when reopening the settings window due to improper toolbar lifecycle management. The crash occurs in `NSToolbar _insertNewItemWithItemIdentifier` when the settings window is recreated after being closed, particularly after memory optimization cleanup. This spec addresses the need for robust settings window lifecycle management that prevents toolbar-related crashes while maintaining memory efficiency.

## Glossary

- **Settings Window**: The preferences/configuration window that displays application settings across multiple panes (General, Size, Applications, Statistics)
- **Toolbar**: The NSToolbar component that provides navigation between different settings panes
- **SettingsWindowController**: The controller managing the settings window using the Settings library
- **Pane Controller**: Individual view controllers for each settings tab (General, Size, Applications, Statistics)
- **Memory Cleanup**: The process of releasing resources when the settings window is closed to prevent memory accumulation
- **Settings Library**: The third-party library used for managing tabbed preferences windows with toolbar navigation

## Requirements

### Requirement 1

**User Story:** As a user, I want to open and close the settings window multiple times without the application crashing, so that I can configure my preferences reliably.

#### Acceptance Criteria

1. WHEN a user opens the settings window for the first time THEN the system SHALL display the window with all toolbar items properly initialized
2. WHEN a user closes the settings window THEN the system SHALL clean up resources without affecting future window creation
3. WHEN a user reopens the settings window after closing it THEN the system SHALL create a new window instance without toolbar-related crashes
4. WHEN the settings window is recreated THEN the system SHALL ensure all toolbar items are properly configured before displaying the window
5. WHEN multiple open-close cycles occur THEN the system SHALL maintain stable toolbar state across all cycles

### Requirement 2

**User Story:** As a developer, I want proper lifecycle management of the settings window and its components, so that resource cleanup doesn't interfere with UI operations.

#### Acceptance Criteria

1. WHEN the cleanup method is invoked THEN the system SHALL ensure no toolbar operations are in progress
2. WHEN creating a new settings window controller THEN the system SHALL properly initialize all pane controllers before toolbar configuration
3. WHEN the window delegate receives windowWillClose THEN the system SHALL defer cleanup until all UI operations complete
4. WHEN replacing the settings window controller THEN the system SHALL properly dispose of the old controller before creating the new one
5. WHILE the toolbar is being configured THEN the system SHALL prevent concurrent cleanup operations

### Requirement 3

**User Story:** As a user, I want the settings window to maintain memory efficiency, so that repeatedly opening settings doesn't cause memory leaks.

#### Acceptance Criteria

1. WHEN the settings window closes THEN the system SHALL release all pane controllers and their associated views
2. WHEN cleanup occurs THEN the system SHALL clear the application icon cache to free memory
3. WHEN a new settings window is created THEN the system SHALL not retain references to previous window instances
4. WHEN the application monitor is released THEN the system SHALL properly nil out all weak references
5. WHILE maintaining memory efficiency THEN the system SHALL ensure cleanup timing doesn't cause crashes

### Requirement 4

**User Story:** As a developer, I want clear separation between window lifecycle events and cleanup operations, so that race conditions are prevented.

#### Acceptance Criteria

1. WHEN windowWillClose is triggered THEN the system SHALL schedule cleanup asynchronously after the current run loop cycle
2. WHEN the settings window is being shown THEN the system SHALL complete all cleanup of previous instances before initialization
3. WHEN toolbar items are being inserted THEN the system SHALL ensure the window and its delegate are fully initialized
4. WHEN view controller replacement occurs THEN the system SHALL use proper view hierarchy management to avoid toolbar conflicts
5. WHILE the window is visible THEN the system SHALL prevent premature cleanup operations
