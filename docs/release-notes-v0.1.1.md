# win-gui-agent v0.1.1

This release adds a second real engineering-software validation target on top of the v0.1.0 Windows GUI automation MVP.

## Highlights

- Added an LTspice 26 real-software GUI trial.
- Added a setup script that prepares a writable `2ndOrderLowpass` schematic project from LTspice's bundled examples.
- Added LTspice batch simulation evidence for a generated RC filter netlist:
  - `rc_filter.raw`
  - `rc_filter.log`
  - measured `vout_final`
- Added optional recovery for LTspice first-run dialogs:
  - `Anonymously Share LTspice Usage Data`
  - `LTspice Tool Change Log`
  - `New Keyboard Shortcuts`
- Extended the engineering suite so one run now covers both KiCad and LTspice.
- Documented LTspice selector lessons: old-style UIA controls can appear as panes, and LTspice's MFC `Afx:...` window class should not be hard-coded.

## Validation

Latest local validation before this release package:

```text
Unit tests: 12 passed
Preflight: ok
LTspice task: 13 steps passed
LTspice simulation: rc_filter.raw exists, rc_filter.log contains vout_final
Engineering suite: KiCad plus LTspice passed
Engineering suite child task runs: 2
30-minute unattended smoke suite: 43 loops, 215 child task runs, 1824.524 seconds
```

## Compatibility

The LTspice demo assumes LTspice 26.x is installed at:

```text
C:\Users\xuan\AppData\Local\Programs\ADI\LTspice
```

The KiCad demo still assumes KiCad 10.0.x is installed at:

```text
C:\Program Files\KiCad\10.0
```

## Known Limits

- The agent is intended for trusted local or VM environments only.
- OCR requires Tesseract on Windows.
- The current VM still should not require KiCad 3D Viewer because its virtual GPU lacks OpenGL 2.1 support.
- Public releases do not include generated `runs/`, screenshots, installers, VM dumps, credentials, or license files.
