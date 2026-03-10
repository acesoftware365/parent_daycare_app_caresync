# parentdaycareapp

Parent Daycare App Caresync

## Latest Release

- Version `1.2.25+38`
- `View Document` now opens a printable PDF preview for the daycare contract and each photo permission, including parent info, written terms, and the stored signature when available
- Added in-app PDF preview and print/share support for signed parent documents
- Updated `Pending Signature` cards to use `Sign Document` and `View Document` actions like the main permission cards
- Renamed the contract action to `Save Signature` and added `View Saved Signature` beside it
- Parents now sign once in `Sign Daycare Contract`, and photo permission documents reuse that saved signature
- Added REST fallback for contract and permission saves when Firestore web channel is unavailable
- Daycare contract signature now saves through a dedicated write path instead of the generic profile updater
- Pending signature buttons are wider and now read `Sign Now`
- `View Document` now opens a dedicated read-only signed permission viewer
- `Save Permission` now validates required fields and shows clearer error feedback
- Photo permission cards now show separate `Sign Document` and `View Document` actions
- Signature points now persist as a simpler string format for more reliable saves
- Signature strokes now save with a safer encoded format to avoid contract save failures
- `Today Summary` and `Latest Update` now also fall back to child root fields for more reliable parent-side refresh
- Hardened the daycare contract signature flow with validation, error feedback, and reliable dialog close on successful save
- Photo permission now reloads the saved signed document so the parent can reopen and verify the stored signature
- Clarified the contract signature button versus child photo permission signing flow
- `Latest Update` now reads real classroom photo updates for the selected child
- `Today Summary` now reads real daycare-posted daily tags for the selected child
- Added a real `Photo & Media Permission` flow in `Forms`, signed per child with parent information and drawn signature
- Signed permissions are saved under each child so daycare staff can later gate photo-based updates
- Improved tablet and desktop web UI/UX without changing the mobile layout
- Added child selection on the Home screen when a parent has more than one child linked
- Home screen cards now follow the selected child context
- The `I'm on my way` action now creates a real pickup notification for backoffice
- Pickup notifications now store the parent name in the message text for backoffice display

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
