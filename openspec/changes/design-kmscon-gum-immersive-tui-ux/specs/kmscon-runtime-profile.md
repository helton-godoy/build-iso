# KMSCON Runtime Profile Specification

## Purpose
Define the configuration and runtime parameters for KMSCON to serve as the primary console interface, replacing standard Getty/VT lines, to support a rich TUI experience.

## Requirements

### Requirement: Display Configuration
KMSCON MUST be configured to utilize the full capabilities of the framebuffer.

#### Scenario: Resolution and Rendering
- **WHEN** KMSCON starts
- **THEN** it must detect and use the native display resolution
- **AND** it must use the DRM/KMS backend
- **AND** hardware acceleration should be enabled if available

### Requirement: Input Device Support
The console MUST support modern input methodologies.

#### Scenario: User Interaction
- **WHEN** a user interacts with the system
- **THEN** full keyboard support (including modifier keys) must be available
- **AND** mouse events should be captured and passed to compatible TUI applications (GPM-like behavior)

### Requirement: Service Integration
KMSCON MUST integrate seamlessly with the system initialization process.

#### Scenario: Startup
- **WHEN** systemd reaches multi-user target
- **THEN** `kmscon` service must start automatically on tty1
- **AND** standard `getty` services on other TTYs should be disabled or deprioritized to prevent conflict
