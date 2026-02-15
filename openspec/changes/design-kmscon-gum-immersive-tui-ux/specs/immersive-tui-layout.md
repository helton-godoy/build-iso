# Immersive TUI Layout Specification

## Purpose
Define the visual structure, behavior, and responsive rules for the Text User Interface (TUI) to ensure an immersive, full-screen experience that abstracts the underlying shell environment.

## Requirements

### Requirement: Full Screen Utilization
The application MUST utilize the entire available terminal space to create an immersive environment.

#### Scenario: Application Launch
- **WHEN** the TUI application starts
- **THEN** it must occupy 100% of the terminal width and height
- **AND** it must hide the system cursor unless explicitly required for input
- **AND** it must clear any previous shell output

### Requirement: Standard Visual Hierachy
The interface MUST enforce a consistent layout structure across all screens to reduce cognitive load.

#### Scenario: Visual Grid
- **WHEN** displaying any screen
- **THEN** it must follow a standard grid: Header (top), Body (middle, flexible), Footer (bottom)
- **AND** the Header must display the "FILESERVER INSTALLER" branding and current step title
- **AND** the Footer must reserve space for navigation hints (e.g., "Enter: Confirm", "Esc: Back")

### Requirement: Responsive Adaptation
The layout MUST obey the constraints of the execution environment, adapting to different terminal sizes.

#### Scenario: Low Resolution Support
- **WHEN** running in a standard 80x24 terminal
- **THEN** the layout must remain usable without scrolling critical navigation elements
- **AND** text content must wrap or ellipsize gracefully
- **AND** borders must adjust to fit within the visible area
