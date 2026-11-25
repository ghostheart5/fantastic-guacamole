# Release Notes

Axiomara has not yet published verified public production release notes.

This document will record customer-facing releases only after the exact release candidate has completed the required release verification and is available through an approved public distribution channel.

## Unreleased

These changes are not yet released or verified on a device.

- Existing habit reminders are kept when you upgrade to per-habit reminder times.
- Forecast wording now says the time range changes how wide the uncertainty is, not the projection itself.
- Task-completion records are no longer sent to the cloud while Cloud Backup is off.
- The recovery-key screen no longer creates or overwrites a key by accident.
- Automatic backup keeps your full cloud backup up to date, and Settings shows when the last backup happened.
- Turning Cloud Backup on now includes saving your recovery key, with a way to start over if the key is lost. This needs a server update before it can be used.
- Moving around the app closes screens that were covering where you are going, and "Review my day in detail" has a Back button.
- "My patterns & progress" keeps the tab bar, and Back returns to Insights.
- Skipping setup now tells you the guide is off and how to restart it.
- A paid AI reply is kept if you leave the screen while it is being answered.
- First-run test flows and device journeys are updated for the current app.
- Tasks now remind you at their start time, or when they are due. This is on by default, with one reminder per task and only the next 20 set at once.
- You can turn on a nudge the morning after a task or goal was due, if it is still open. It is off by default.
- A goal due today that you add after 9 AM gets one reminder at 6 PM.
- You can set a habit's reminder time when you create it, and pick the days of the week or the day of the month it reminds you on.
- You can change a goal's target date after creating it.
- Settings has one Notifications area: a main switch, how early task reminders come, quiet hours, and a line that says whether reminders can arrive on this device.
- The app asks for notification permission at the moment you set something that needs a reminder, and explains what to do if notifications are off.
- The in-app reminder list shows what the phone actually accepted, with the right time for habits on any chosen day.
- Reminders are updated by changing only what is different, instead of cancelling and setting them all again. A reminder already shown stays in the notification tray when the app restarts.
- Reminder times follow a change of time zone.
- Changing how early task reminders come, or turning reminders back on, no longer drops a task reminder that is still to come.
- Tapping a reminder opens the screen it is about.
- Reminder text follows the app language.
- The app no longer asks for a push notification token, since nothing sends push messages yet.
- A step-by-step check for reminders on a real phone is in docs/DEVICE_REMINDER_PROTOCOL.md. It has not been run on a device yet.

## Future release entries

Each published entry will identify:

- The release date and public version or build identifier.
- User-visible additions and improvements.
- Material fixes, known limitations, or compatibility notes.
- The relevant distribution or availability status.

Release notes will describe verified shipped behavior only. Planned work, test-only behavior, and unverified candidates will not be presented as released features.

## Support

For help with Axiomara, visit [Axiomara Support](https://ghostheart5.github.io/fantastic-guacamole/support/).
