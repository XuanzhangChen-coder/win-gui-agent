# Contributing

Thank you for improving `win-gui-agent`.

## Local Checks

Run the source preflight before sending changes:

```bash
scripts/preflight.py .
```

If your working tree contains generated reports under `runs/`, create a clean export and test that instead:

```bash
scripts/export_clean.py /tmp/win-gui-agent-clean
/tmp/win-gui-agent-clean/scripts/preflight.py /tmp/win-gui-agent-clean
```

## Windows Agent Checks

For changes that touch the agent API, task runner, UI Automation, OCR, or input behavior, validate against a live trusted Windows VM when possible:

```bash
python3 client/run_task.py examples/text-pad-ocr-task.json \
  --base-url http://127.0.0.1:8765 \
  --report runs/text-pad-ocr-task-report.json \
  --quiet
```

For engineering-software changes on a VM with KiCad 10.0 installed:

```bash
python3 client/run_suite.py examples/engineering-suite.json \
  --base-url http://127.0.0.1:8765 \
  --report runs/engineering-suite-report.json \
  --quiet-tasks
```

Do not commit generated `runs/`, screenshots, installers, license files, VM dumps, or secrets.
