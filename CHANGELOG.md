# Changelog

## Unreleased

- Added an LTspice real-software trial that installs/launches LTspice 26, handles first-run dialogs, opens the bundled `2ndOrderLowpass` schematic, and extends the engineering suite to run KiCad plus LTspice.

## v0.1.0 - 2026-06-03

- Added the Windows-internal GUI agent MVP with screenshot, mouse, keyboard, window, UI Automation, OCR, verifier, task-runner, and suite-runner primitives.
- Added real-application demos for Windows Settings, Edge, a wizard-style installer fixture, Vivado smoke validation, and KiCad engineering workflows.
- Added KiCad `pic_programmer` real-project trial with project setup, ERC/DRC checks, schematic PDF export, Gerber export, drill export, GUI editor launch, and multi-loop engineering-suite validation.
- Added optional task steps for recoverable modal dialogs.
- Added native virtual-key input fallback for elevated or wxWidgets windows.
- Added clean export and preflight scripts for GitHub publishing.
