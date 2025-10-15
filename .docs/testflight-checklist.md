# TestFlight Packaging Checklist

## Build
- [ ] Increment build number in Xcode (`scribble` target) and archive (`Generic iOS Device`).
- [ ] Validate archive locally (`Product > Archive` → `Distribute App` → `Development` export) to ensure signing profile works.
- [ ] Upload archived build to App Store Connect (`xcodebuild -exportArchive` or Organizer Upload).

## Metadata
- [ ] Release notes summarising new features (Trace/Ghost/Memory, haptics toggle, left-handed mode, persistence changes).
- [ ] Include regression plan link (`.docs/regression-plan.md`) for testers in TestFlight notes.
- [ ] Confirm contact email + auto-expire settings for the beta group.

## Onboarding
- [ ] Provide educators with pilot script (`.docs/pilot-script.md`) and feedback checklist (`.docs/pilot-feedback-checklist.md`).
- [ ] Share instructions for enabling Pencil-only mode and toggling settings within app.
- [ ] Remind testers to capture device/Pencil combo in their feedback.

## Post Upload
- [ ] Download TestFlight build on reference device; complete sanity check (Trace + Memory success ≥80).
- [ ] Monitor App Store Connect build processing; address any missing compliance questions.
- [ ] Once approved, invite pilot cohort and share Slack/email reminder with regression + feedback links.
