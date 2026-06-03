# Open Source Checklist

Date: 2026-06-01

## Keep In The Repository

- `agent/WinGuiAgent.ps1`
- `client/run_task.py`
- `client/run_suite.py`
- `client/wga.sh`
- `examples/*.json`
- `examples/*.ps1`
- `examples/*.html`
- `docs/*.md`
- `tests/*.py`
- `README.md`
- `CHANGELOG.md`
- `CONTRIBUTING.md`
- `SECURITY.md`
- `LICENSE`
- `.github/workflows/preflight.yml`

## Keep Out Of The Repository

- `runs/`
- `__pycache__/`
- `.pytest_cache/`
- `.venv/`
- `*.pyc`
- local screenshots, logs, VM dumps, installers, license files, and secrets

The `.gitignore` already excludes the common generated paths.

## Public Audit

Before publishing:

1. Run local tests:

```bash
python3 -m unittest discover -s tests -v
```

2. Validate examples parse:

```bash
python3 - <<'PY'
import json
from pathlib import Path
for p in sorted(Path('examples').glob('*.json')):
    json.loads(p.read_text(encoding='utf-8'))
    print('ok', p)
PY
```

3. Confirm generated files are absent:

```bash
find . -name '__pycache__' -o -name '*.pyc'
```

4. Confirm `runs/` is not staged for publication.

4a. Prefer publishing from a clean export instead of the working directory:

```bash
scripts/export_clean.py /tmp/win-gui-agent-clean
/tmp/win-gui-agent-clean/scripts/preflight.py /tmp/win-gui-agent-clean
```

4b. Initialize the public repository from the clean export:

```bash
cd /tmp/win-gui-agent-clean
git init
git add .
git commit -m "Initial win-gui-agent release"
git tag -a v0.1.0 -m "win-gui-agent v0.1.0"
```

The GitHub Actions workflow `.github/workflows/preflight.yml` runs the same preflight on push and pull requests.

5. Run the controlled OCR fixture against a live Windows agent:

```bash
python3 client/run_task.py examples/text-pad-ocr-task.json \
  --base-url http://127.0.0.1:8765 \
  --report runs/text-pad-ocr-task-report.json \
  --quiet
```

6. Run the multi-application smoke suite:

```bash
python3 client/run_suite.py examples/smoke-suite.json \
  --base-url http://127.0.0.1:8765 \
  --report runs/smoke-suite-report.json \
  --quiet-tasks
```

7. If KiCad 10.0 is installed on the Windows VM, run the engineering suite:

```bash
/home/xuan/VMs/bin/win11-ee-ssh-ps.sh \
  'C:\GuiAgent\win-gui-agent\examples\kicad-prepare-pic-programmer.ps1'

/home/xuan/VMs/bin/win11-ee-ssh-ps.sh \
  'C:\GuiAgent\win-gui-agent\examples\kicad-export-pic-programmer.ps1'

python3 client/run_suite.py examples/engineering-suite.json \
  --base-url http://127.0.0.1:8765 \
  --report runs/engineering-suite-report.json \
  --quiet-tasks
```

8. If LTspice 26 is installed on the Windows VM, run the LTspice real-software task:

```bash
python3 client/run_task.py examples/ltspice-lowpass-task.json \
  --base-url http://127.0.0.1:8765 \
  --report runs/ltspice-lowpass-task-report.json \
  --quiet
```

## Current Evidence

- Unit tests: 12 tests pass on Ubuntu without a Windows VM.
- Clean export dry run: `/tmp/win-gui-agent-clean` contains no `runs/`, no `__pycache__/`, no `*.pyc`; 12 tests pass and all example JSON files parse.
- Clean Git repository dry run: `/tmp/win-gui-agent-github` has an initial commit generated from a clean export.
  - Branch: `main`
  - Commit: `Initial win-gui-agent release`
  - Preflight from the committed tree: 12 tests passed, `preflight ok`.
- Persistent local release repository: `/home/xuan/FPGA/win-gui-agent-release`, branch `main`, latest tag `v0.1.1`.
- Release archives:
  - `/home/xuan/FPGA/releases/win-gui-agent-0.1.1.tar.gz`
  - `/home/xuan/FPGA/releases/win-gui-agent-0.1.1.zip`
  - `/home/xuan/FPGA/releases/win-gui-agent-0.1.1.sha256`
  - Historical v0.1.0 archives:
  - `/home/xuan/FPGA/releases/win-gui-agent-0.1.0.tar.gz`
  - `/home/xuan/FPGA/releases/win-gui-agent-0.1.0.zip`
  - `/home/xuan/FPGA/releases/win-gui-agent-0.1.0.sha256`
- Controlled OCR fixture: `runs/text-pad-ocr-task-report.json`, ok.
- Two-loop suite: `runs/smoke-suite-textpad-2loop-report.json`, ok.
- 30-minute burn-in: `runs/smoke-suite-30min-textpad-report.json`, ok.
- Burn-in duration: 1824.524 seconds.
- Burn-in completed child task runs: 215.
- KiCad real-project task: `runs/kicad-pic-programmer-task-report-20260603.json`, ok.
- KiCad engineering suite: `runs/engineering-suite-3loop-report-20260603-r2.json`, ok, 3 loops, 3 child task runs, 29.383 seconds.
- KiCad evidence screenshots: `wga-kicad-project.png`, `wga-kicad-schematic.png`, `wga-kicad-pcb.png` in the local VM shared folder. Treat these as optional published evidence, not source files.
- LTspice install: MSI exit code `0`; Windows Installer logged LTspice 26.0.2.1 installation/reconfiguration success.
- LTspice task: `runs/ltspice-lowpass-task-report-20260603-r3.json`, ok, 11 steps, active window `LTspice - [2ndOrderLowpass]`.
- Engineering suite with KiCad and LTspice: `runs/engineering-suite-kicad-ltspice-report-20260603.json`, ok, 1 loop, 2 child task runs, 17.897 seconds.

## Known Limits

- The agent is designed for trusted local or VM environments; do not expose it to untrusted networks.
- OCR depends on Tesseract being installed on Windows.
- GUI automation remains sensitive to locked screens, sleep, resolution changes, and unexpected modal dialogs.
- Windows 11 Notepad can restore old tabs after repeated forced resets. Use the controlled Text Pad fixture for long unattended reliability checks and keep Notepad as a real-application demo.
- The KiCad demo requires KiCad 10.0.x installed at `C:\Program Files\KiCad\10.0`. It uses KiCad's bundled demo project and should not publish installers or third-party license files.
- The current VM falls back to KiCad software rendering because OpenGL 2.1 is unavailable. The 2D schematic/PCB workflow is valid, but 3D Viewer should not be a required public demo on this VM.
- The LTspice demo requires LTspice 26.x installed at `C:\Users\xuan\AppData\Local\Programs\ADI\LTspice`. It copies a bundled educational schematic into `C:\EE-Projects\wga-ltspice-demo` and does not publish installer files.
