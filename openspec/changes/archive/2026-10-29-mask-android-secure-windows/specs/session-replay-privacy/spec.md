## ADDED Requirements

### Requirement: Android secure windows are recorded fully masked

On Android, while a window captured by session replay is a **secure window** — its `WindowManager.LayoutParams` flags include `FLAG_SECURE` — the SDK SHALL record that window fully masked rather than skip it, in every replay mode the SDK supports.

This applies to every SDK whose Android session replay captures that window, including wrapper SDKs that render replay frames themselves (posthog-flutter) or delegate capture to posthog-android (posthog-react-native). It is not applicable on iOS, which has no window-level secure flag and masks sensitive inputs per field under the existing rules.

Recording a secure window fully masked means:

- In screenshot mode, the SDK SHALL record an opaque, solid black frame with the window's dimensions and MUST NOT record or upload any of the window's pixels.
- In wireframe mode, the SDK SHALL record one masked node covering the window, filled solid black, and MUST NOT serialize the window's child views, text, or images.

The SDK SHALL check the window's secure state when capture starts and again before the captured frame is recorded, and SHALL record the frame fully masked if the window was secure at either check.

The SDK MUST NOT record touch interactions that occur on a secure window. The touch MUST still be delivered to the application.

The SDK SHALL evaluate each window by its own flags. A window without `FLAG_SECURE`, such as a dialog shown over a secure activity, is captured under the normal masking rules.

#### Scenario: Screenshot mode records a secure window as a masked frame
- **GIVEN** Android session replay is recording in screenshot mode
- **AND** the captured window has `FLAG_SECURE`
- **WHEN** a replay frame is captured
- **THEN** the recorded frame is fully masked with the window's dimensions
- **AND** the frame is solid black
- **AND** no pixels from the window are recorded or uploaded

#### Scenario: Wireframe mode records a secure window as one masked node
- **GIVEN** Android session replay is recording in wireframe mode
- **AND** the captured window has `FLAG_SECURE` and contains a text view showing "1234"
- **WHEN** a replay snapshot is captured
- **THEN** the recorded snapshot contains one masked node covering the window
- **AND** the node is filled solid black
- **AND** it contains no child views, images, or text "1234"

#### Scenario: A window that becomes secure during capture is masked
- **GIVEN** Android session replay is recording in screenshot mode
- **AND** the captured window does not have `FLAG_SECURE` when capture starts
- **WHEN** the window gains `FLAG_SECURE` before the captured frame is recorded
- **THEN** the recorded frame is fully masked

#### Scenario: A frame captured on a secure window stays masked after the flag clears
- **GIVEN** Android session replay is recording in screenshot mode
- **AND** the captured window has `FLAG_SECURE` when capture starts
- **WHEN** the window loses `FLAG_SECURE` before the captured frame is recorded
- **THEN** the recorded frame is fully masked

#### Scenario: Touches on a secure window are not recorded
- **GIVEN** Android session replay is recording
- **AND** the window has `FLAG_SECURE`
- **WHEN** the user taps the window
- **THEN** no touch interaction is recorded for that tap
- **AND** the application still receives the tap

#### Scenario: A window without the flag follows the normal masking rules
- **GIVEN** Android session replay is recording
- **AND** a dialog window without `FLAG_SECURE` is shown over an activity window that has `FLAG_SECURE`
- **WHEN** a replay frame of the dialog window is captured
- **THEN** the dialog window is captured under the normal masking rules
