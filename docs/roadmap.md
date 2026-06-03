# Roadmap

The project is developed in layers. Each layer must have a concrete validation task before the next layer is added.

## This Week Landing Plan

Goal: produce a stable, open-sourceable Windows GUI automation agent that can observe, act, verify, and stop with evidence.

### Day 1: Stable Closed Loop

Deliverables:

- Windows scheduled-task agent.
- `/health`, `/screen`, `/screenshot`.
- Mouse, keyboard, run-program endpoints.
- Notepad smoke test.

Validation:

- 10 screenshots have stable dimensions.
- A Notepad typing task produces before/after screenshots.

Status: done.

### Day 2: UI Automation And Windows

Deliverables:

- Window list, activate, maximize, close.
- UIA tree, find, click, set text.

Validation:

- Move or maximize Notepad and still set text without coordinate clicks.

Status: done.

### Day 3: Vision And OCR

Deliverables:

- Screenshot diff.
- Template finding and image click.
- Tesseract-backed OCR.
- Region OCR and OCR text click.

Validation:

- Locate text in a bounded region.
- Click a visible word by OCR-derived screen coordinates.

Status: done for MVP; needs more real-app trials.

### Day 4: Verifier And Task DSL

Deliverables:

- `/verify` and `/action`.
- JSON task runner.
- Retry, stop-on-failure, report file, manual resume.
- OCR expectation support.

Validation:

- A multi-step Notepad task completes with a report.
- A deliberately wrong expectation fails with evidence.

Status: MVP done; failure-demo examples still need polish.

### Day 5: Real Software Trials

Deliverables:

- Notepad demo.
- Windows Settings demo.
- Browser or installer-style demo.
- One engineering-software trial when a safe target is available.

Validation:

- Each demo is repeatable from a clean screen.
- Each demo includes screenshots and a JSON report.

Status: done for MVP. Windows Settings, Edge browser, installer-style, and Vivado engineering-software smoke trials are done. A deeper disposable-project Vivado trial is a later extension.

### Day 6: Unattended Reliability

Deliverables:

- Hidden agent window.
- Agent restart workflow.
- Heartbeat checks.
- Clean demo reset scripts.
- 30-minute unattended run.

Validation:

- Long run completes without the agent stealing focus.
- Failure leaves final screenshot and logs.

Status: done.

Short multi-application smoke suite is done: controlled Text Pad OCR, Windows Settings, Edge browser, installer-style wizard, and Vivado smoke all completed in unattended suites. A two-loop reliability check passed with 10 child task runs. The first duration-based burn-in attempt found a real Notepad session-restore reliability bug at 589 seconds, so repeated OCR/UIA baseline testing moved to the controlled Text Pad fixture while Notepad remains a separate real-application demo. The clean 30-minute burn-in passed: 43 loops, 215 child task runs, 1824.524 seconds, all child reports successful.

### Day 7: Open Source Polish

Deliverables:

- README quickstart.
- Setup and troubleshooting docs.
- API reference.
- Examples.
- Client tests.
- License.

Validation:

- A new user can follow docs and run the Notepad task.
- Tests pass on Ubuntu without a Windows VM.

Status: done for MVP.

Open-source pieces now exist: README, setup docs, troubleshooting docs, API docs, examples, client tests, license, controlled fixtures, burn-in evidence, and an open-source checklist. A clean export dry run passed with 11 tests and all example JSON files parsing without `runs/` or cache files.

## Phase 0: Project Goal

Build a Windows GUI automation agent that can operate software without CLI/API support by observing the desktop, acting through mouse/keyboard, and verifying results.

Success criteria:

- Ubuntu can control the Windows VM through a stable agent API.
- Screenshots and clicks share the same coordinate system.
- A real GUI task can run repeatedly with logs and screenshots.
- Failures stop with preserved evidence instead of continuing blindly.

## Phase 1: Stable Desktop Environment

Tasks:

- Confirm Windows VM is running.
- Confirm the `xuan` user is logged in.
- Fix display resolution and scaling where possible.
- Disable sleep, display timeout, and lock screen for unattended runs.
- Confirm shared folder and SSH are available.

Validation:

- A command from Ubuntu can report Windows username, screen size, and active window.

## Phase 2: Screenshot Loop

Tasks:

- Start an agent inside the Windows interactive desktop.
- Implement `/health`, `/screen`, and `/screenshot`.
- Save screenshots to a run directory.

Validation:

- Ubuntu can request 10 consecutive screenshots.
- All screenshots have stable dimensions.
- Images show the actual desktop, not a black screen or lock screen.

## Phase 3: Action Loop

Tasks:

- Implement mouse move, click, double-click.
- Implement text typing, single key, hotkey.
- Return before/after screenshots for each action.

Validation:

- Open Notepad.
- Click the edit area.
- Type `hello gui agent`.
- Screenshot confirms visible text.
- Repeat the loop multiple times without coordinate drift.

## Phase 4: Window Management

Tasks:

- List windows. Done in MVP.
- Report active window. Done in MVP.
- Activate, maximize, and close windows by title. Done in MVP.

Validation:

- Start Notepad.
- Find it in the window list.
- Activate and maximize it.
- Screenshot confirms it is foreground.

## Phase 5: UI Automation

Tasks:

- Add Microsoft UI Automation support. Done in MVP.
- List control tree for standard dialogs. Done in MVP.
- Click a control by name/control type. Done in MVP.
- Set text in standard inputs. Done in MVP.

Validation:

- Operate a standard Windows dialog without coordinate clicks.
- Move the window and repeat successfully.

## Phase 6: Vision Matching

Tasks:

- Add template matching.
- Add image difference checks. Initial screenshot diff API done in MVP.
- Find and click an image target.

Validation:

- Locate a button image inside a screenshot.
- Click its center.
- Verify screen change.

## Phase 7: OCR

Tasks:

- Add OCR for visible text. Tesseract-backed endpoint implemented; backend installation must be present for runtime success.
- Find text boxes/labels/buttons by screen text. Initial `/ocr/find_text` endpoint implemented.
- Click text targets with confidence thresholds.

Validation:

- Find common installer words such as `Next`, `Cancel`, `Install`.
- Click by text and verify the next page appears.

## Phase 8: Verifier

Tasks:

- Add expected-state checks after actions. Initial version done in MVP.
- Support text appears/disappears, title changes, image appears, and screenshot diff thresholds. Title, UIA-exists, and screenshot diff are done in MVP.
- Add retry rules and stop-on-failure evidence capture.

Validation:

- A failed expectation produces a clear error, final screenshot, and step log.

## Phase 9: Task DSL

Tasks:

- Add YAML task execution. JSON task execution is done in MVP; YAML is optional through PyYAML.
- Support wait, click, type, hotkey, expect, retry, and resume. Initial action/verify flow, retry, reports, and manual `--start-at` resume are done; automatic resume remains.

Validation:

- Execute a 10+ step GUI flow from YAML.
- Persist screenshots and logs for every step.

## Phase 10: Real Software Trials

Tasks:

- Notepad: input/save/close.
- Windows settings: toggle/click workflow.
- Installer: next/agree/install/finish workflow.
- Browser: search/download workflow.
- Complex engineering software: open project and inspect status.

Validation:

- Each category has at least one repeatable demo task.

## Phase 11: Unattended Runs

Tasks:

- Start agent automatically on login.
- Heartbeat, task status, logs, screenshots.
- Stop and resume tasks.
- Crash recovery.

Validation:

- Run a 30-minute unattended task and generate a final report.

## Phase 12: Open Source Polish

Tasks:

- Package install scripts.
- Add examples and troubleshooting docs.
- Add architecture docs.
- Add tests for client and task runner logic.

Validation:

- A new user can follow README and run the Notepad demo on a Windows VM.
