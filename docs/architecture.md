# Architecture

The agent uses a layered design:

```text
client
  -> transport
    -> agent HTTP endpoints
      -> desktop primitives
        -> screenshot
        -> mouse
        -> keyboard
        -> windows
        -> UI Automation
        -> vision/OCR
```

## Coordinate Rule

The same process that takes the screenshot must perform the click. This keeps screenshot pixels and input coordinates aligned.

## Action Rule

Every action should be observable:

1. Capture state before the action.
2. Perform the action.
3. Capture state after the action.
4. Return both screenshots and structured metadata.

## Failure Rule

If an action cannot verify progress, stop and preserve evidence. Do not continue a long task blindly.
