# Guided setup and accessibility qualification

Issue #19 qualifies the complete Guided setup, Physical Keyboard management, Switching Status and recovery, Diagnostic Bundle, and General Settings experience.

The qualification candidate must be identified by its source commit. A required case that is unavailable or not run is `inconclusive`. `inconclusive` blocks an Official Release. A failed case is `failed`. The candidate is `passed` only when every automated gate and every required case passes.

## Automated gates

Run:

```sh
./Scripts/run.sh qualify
```

The command writes `build/qualification/setup-accessibility.json` and gate logs under `build/qualification/logs/`. It runs:

- source audit;
- application build;
- complete automated test suite.

The command exits `0` for `passed`, `1` for `failed`, and `2` for `inconclusive`. With no human evidence, exit `2` is expected.

## Human evidence

Run each case on macOS 15 and macOS 26. Use five new Multilingual Professionals for each Guided setup timed journey. Do not put Key Content, exact Physical Keyboard Identity values, serial numbers, custom Physical Keyboard Names, Keyboard Assignments, or raw Input Source identifiers in evidence.

Create a JSON file with aggregate, privacy-safe evidence:

```json
{
  "cases": {
    "guided-setup-macos-26": {
      "status": "passed",
      "evidenceRef": "case-batch-26-a",
      "qualificationRunRef": "macos-26-batch-a",
      "candidateCommit": "0123456789abcdef0123456789abcdef01234567",
      "macOSMajor": "26",
      "macOSBuild": "25F84",
      "participants": 5,
      "durationsSeconds": [112, 124, 131, 145, 157],
      "newMultilingualProfessionals": true,
      "noSeparateDocumentation": true,
      "startedFromNewGuidedSetup": true,
      "listenPermissionGranted": true,
      "builtInPhysicalKeyboard": true,
      "externalPhysicalKeyboard": true,
      "keyboardAssignmentCount": 2,
      "keyboardAssignmentsCreatedDuringJourney": 2,
      "notificationChoiceRecorded": true,
      "reachedReady": true,
      "manualDesignationUsed": false
    }
  }
}
```

Evaluate it with:

```sh
./Scripts/run.sh qualify --evidence path/to/evidence.json
```

Only a safe `evidenceRef` matching `A-Za-z0-9` followed by up to 127 `A-Za-z0-9._-` characters and aggregate values belong in this file. Keep participant identity and raw observations outside the repository, under the approved qualification process.

Every passed case also includes a safe `qualificationRunRef`, the 40-character `candidateCommit`, `macOSMajor`, and `macOSBuild`. The candidate commit must match the report candidate. Use a different `qualificationRunRef` for macOS 15 and macOS 26. The value of `macOSMajor` must match the case ID. Additional checks are required for each case:

- management: `keyboardOperation` and `voiceOver`;
- management also requires `physicalKeyboardNaming`, `keyboardAssignmentManagement`, and `replacementAndForget`;
- manual-designation: `keyboardOperation`, `voiceOver`, and `designationOutsideTimedJourney`;
- status-recovery: `keyboardOperation`, `voiceOver`, and `switchingStatusChanges`;
- status-recovery also requires `recoveryActions`;
- diagnostics-settings: `keyboardOperation`, `voiceOver`, `diagnosticBundleReview`, `diagnosticBundleSaveShare`, and `generalSettingsActions`;
- keyboard-operation: `keyboardOperation`;
- voiceover: `voiceOverNamesValuesActions` and `voiceOverStateChanges`;
- visual-state: `visibleFocus`, `sufficientContrast`, and `nonColorStatus`;
- reduce-motion: `reduceMotion`.

Each additional check must be boolean `true` for a passed case. A missing or invalid check is `inconclusive`; an explicit `false` is `failed`.

Guided setup evidence also requires `newMultilingualProfessionals`, `noSeparateDocumentation`, `startedFromNewGuidedSetup`, and `listenPermissionGranted` to be boolean `true`. `keyboardAssignmentsCreatedDuringJourney` and `keyboardAssignmentCount` must each equal `2`.

## Timed Guided setup journey

Start from a new Guided setup state. Start the timer before the first user action. The journey must:

1. explain Input Monitoring permission and Key Content handling;
2. grant listen permission through the user-approved macOS flow;
3. observe the built-in Physical Keyboard and one external Physical Keyboard;
4. create two Keyboard Assignments using eligible Input Sources;
5. record the optional operational notification choice;
6. reach `Ready`;
7. finish in less than 3 minutes for every participant.

Manual Physical Keyboard Designation is not part of this timed journey. Qualify it separately through its removal, return, and confirmation flow. The separate `manual-designation-macos-15` and `manual-designation-macos-26` cases are required.

## Accessibility matrix

For each supported macOS version, qualify these cases through observable app behavior:

- complete Guided setup, management, Switching Status, recovery, Diagnostic Bundle, and General Settings journeys;
- operate every flow with keyboard input only, including dialogs, sheets, pickers, save, share, and close actions;
- verify VoiceOver announces clear names, values, actions, and Switching Status changes;
- verify visible focus, sufficient contrast, and status information that does not depend on color;
- enable Reduce Motion and verify no required action or state change depends on motion.

Record source commit, macOS version/build, Apple silicon architecture, case status, and sanitized evidence reference. Do not record Key Content or stable Physical Keyboard Identity and Input Source identifiers.
