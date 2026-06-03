# win-gui-agent v0.1.0

This first release packages the Windows-internal GUI automation MVP and the evidence-backed engineering-software demo.

## Highlights

- Windows-local desktop agent with screenshot, mouse, keyboard, window, UI Automation, OCR, verifier, task-runner, and suite-runner endpoints.
- JSON task DSL with retry, wait, verification, and optional recovery steps.
- Real Windows application demos:
  - Windows Settings
  - Microsoft Edge local-page task
  - installer-style wizard fixture
  - Vivado smoke task
  - KiCad real-project engineering suite
- KiCad `pic_programmer` demo workflow:
  - prepares a writable copy of the bundled KiCad project
  - runs ERC and DRC
  - exports schematic PDF, Gerbers, and drill files
  - opens KiCad project manager, schematic editor, and PCB editor through GUI automation
  - passes a 3-loop engineering-suite validation on the local Windows VM
- Clean export and preflight scripts for GitHub publishing.

## Validation

Latest local validation before the release package:

```text
Unit tests: 12 passed
Clean export preflight: ok
Engineering suite: 3 loops passed
KiCad ERC: 0 violations
KiCad DRC: 0 violations
```

## Known Limits

- The agent is intended for trusted local or VM environments only. Do not expose the HTTP API to untrusted networks.
- OCR requires Tesseract on Windows.
- KiCad 3D Viewer is not part of the required demo on the current VM because the virtual GPU lacks OpenGL 2.1 support. KiCad schematic and PCB editors work through software rendering.
- Public releases should not include generated `runs/`, screenshots, installers, VM dumps, credentials, or license files.
