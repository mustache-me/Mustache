# Requirements Document

## Introduction

The Numbered App Switcher is a macOS utility that enhances application switching by displaying numbered overlays on running application windows. Users can quickly switch to any application by pressing a modifier key (e.g., Option) plus a number key (0-9), providing faster access than the traditional Cmd+Tab interface. The system monitors running applications, assigns numbers to them, and provides visual feedback through floating numbered badges.

## Glossary

- **App Switcher**: The system component that allows users to switch between running applications
- **Numbered Overlay**: A visual badge displaying a number that appears on top of an application window
- **Running Application**: An application that is currently executing and has visible windows
- **Modifier Key**: A keyboard key (such as Option, Command, Control) that modifies the behavior of other keys
- **Hotkey Combination**: A combination of modifier key(s) and a number key used to trigger app switching
- **Application Monitor**: The component that tracks running applications and their window states
- **Badge Renderer**: The component that draws numbered overlays on application windows
- **Accessibility API**: macOS APIs that provide access to window information and application control
- **Menu Bar Agent**: A background application that runs from the macOS menu bar
- **Preferences Panel**: A user interface for configuring application settings

## Requirements

### Requirement 1

**User Story:** As a macOS user, I want to see numbered badges on my running application windows, so that I know which number to press to switch to each application.

#### Acceptance Criteria

1. WHEN the Menu Bar Agent starts THEN the system SHALL enumerate all running applications with visible windows
2. WHEN applications are enumerated THEN the system SHALL assign numbers 1-9 and 0 to the first ten applications based on their screen position or usage order
3. WHEN a numbered overlay is displayed THEN the Badge Renderer SHALL position it at the top-left corner of the application window
4. WHEN an application window moves THEN the Badge Renderer SHALL update the overlay position to follow the window
5. WHEN an application is hidden or minimized THEN the system SHALL remove its numbered overlay from display

### Requirement 2

**User Story:** As a user, I want to quickly switch to any numbered application by pressing Option + number, so that I can navigate between apps faster than using Cmd+Tab.

#### Acceptance Criteria

1. WHEN a user presses a hotkey combination (modifier + number) THEN the system SHALL activate the application assigned to that number
2. WHEN the target application is activated THEN the system SHALL bring all windows of that application to the front
3. WHEN an invalid number is pressed (no application assigned) THEN the system SHALL ignore the input and maintain current state
4. WHEN the hotkey is triggered THEN the system SHALL complete the switch within 100 milliseconds
5. IF the target application is already frontmost WHEN the hotkey is pressed THEN the system SHALL maintain focus on that application

### Requirement 3

**User Story:** As a user, I want the numbered overlays to appear only when I hold down the modifier key, so that they don't clutter my screen during normal work.

#### Acceptance Criteria

1. WHEN the user presses and holds the modifier key THEN the Badge Renderer SHALL display all numbered overlays within 50 milliseconds
2. WHEN the user releases the modifier key THEN the Badge Renderer SHALL hide all numbered overlays within 50 milliseconds
3. WHILE the modifier key is held THEN the Badge Renderer SHALL keep overlays visible and updated
4. WHEN overlays are displayed THEN the Badge Renderer SHALL render them with semi-transparent backgrounds to avoid obscuring content
5. WHEN overlays are displayed THEN the Badge Renderer SHALL use high-contrast colors for readability

### Requirement 4

**User Story:** As a user, I want to configure which modifier key triggers the app switcher, so that I can avoid conflicts with other keyboard shortcuts.

#### Acceptance Criteria

1. WHEN the user opens the Preferences Panel THEN the system SHALL display available modifier key options (Option, Control, Command, Shift, or combinations)
2. WHEN the user selects a new modifier key THEN the system SHALL update the hotkey registration immediately
3. WHEN the user selects a modifier key combination already used by the system THEN the Preferences Panel SHALL display a warning message
4. WHEN preferences are changed THEN the system SHALL persist the configuration to disk
5. WHEN the Menu Bar Agent starts THEN the system SHALL load the saved modifier key preference

### Requirement 5

**User Story:** As a user, I want to customize which applications appear in the numbered list, so that I can prioritize my most-used applications.

#### Acceptance Criteria

1. WHEN the user opens the Preferences Panel THEN the system SHALL display a list of all running applications
2. WHEN the user reorders applications in the list THEN the system SHALL update number assignments to match the new order
3. WHEN the user excludes an application from the list THEN the system SHALL not assign a number to that application
4. WHEN application preferences are saved THEN the system SHALL remember the custom ordering across restarts
5. WHERE custom ordering is enabled THEN the system SHALL assign numbers based on user preference rather than default ordering

### Requirement 6

**User Story:** As a user, I want the app switcher to automatically update when I open or close applications, so that the numbered list stays current.

#### Acceptance Criteria

1. WHEN a new application launches THEN the Application Monitor SHALL detect it and assign an available number
2. WHEN an application quits THEN the Application Monitor SHALL remove it from the numbered list and reassign numbers if necessary
3. WHEN the number of running applications exceeds ten THEN the system SHALL assign numbers only to the first ten applications
4. WHEN applications are added or removed THEN the system SHALL update overlay displays within 200 milliseconds
5. WHILE monitoring applications THEN the Application Monitor SHALL poll for changes at least every 500 milliseconds

### Requirement 7

**User Story:** As a user, I want visual feedback when I trigger an app switch, so that I know my input was recognized.

#### Acceptance Criteria

1. WHEN a valid hotkey combination is pressed THEN the Badge Renderer SHALL briefly highlight the corresponding numbered overlay
2. WHEN the highlight is displayed THEN the Badge Renderer SHALL use a distinct color or animation for 200 milliseconds
3. WHEN an app switch completes THEN the system SHALL hide all overlays if the modifier key is released
4. IF the modifier key is still held after switching THEN the Badge Renderer SHALL continue displaying overlays with the newly activated app's number highlighted
5. WHEN visual feedback is shown THEN the Badge Renderer SHALL ensure it does not interfere with the app switching performance

### Requirement 8

**User Story:** As a macOS user, I want the app switcher to request necessary permissions, so that it can access window information and control applications.

#### Acceptance Criteria

1. WHEN the Menu Bar Agent first launches THEN the system SHALL check for Accessibility API permissions
2. IF Accessibility API permissions are not granted THEN the system SHALL display a dialog explaining why permissions are needed
3. WHEN the user grants permissions THEN the system SHALL enable all app switching functionality
4. IF permissions are denied THEN the system SHALL disable app switching and display a status message in the menu bar
5. WHEN permission status changes THEN the system SHALL detect the change and update functionality accordingly

### Requirement 9

**User Story:** As a user, I want the app switcher to run as a lightweight menu bar application, so that it doesn't consume significant system resources.

#### Acceptance Criteria

1. WHEN the Menu Bar Agent is running THEN the system SHALL display an icon in the macOS menu bar
2. WHEN the user clicks the menu bar icon THEN the system SHALL display a menu with options to open preferences, quit, or view status
3. WHEN the Menu Bar Agent is idle THEN the system SHALL consume less than 20 MB of memory
4. WHEN monitoring applications THEN the system SHALL use less than 1% CPU on average
5. WHEN the system starts up THEN the Menu Bar Agent SHALL launch automatically if configured to do so

### Requirement 10

**User Story:** As a developer, I want the application to handle edge cases gracefully, so that users have a reliable experience.

#### Acceptance Criteria

1. WHEN an application crashes or becomes unresponsive THEN the Application Monitor SHALL detect it and remove it from the numbered list
2. WHEN multiple windows belong to the same application THEN the system SHALL display only one numbered overlay for that application
3. IF the Accessibility API fails to return window information THEN the system SHALL log the error and continue operating with available data
4. WHEN the system wakes from sleep THEN the Application Monitor SHALL refresh the application list within 1 second
5. WHEN displays are connected or disconnected THEN the Badge Renderer SHALL update overlay positions for the new screen configuration
