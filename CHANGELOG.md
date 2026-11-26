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
- When the app starts or comes back to the front, reminders are updated by changing only what is different, instead of cancelling and setting them all again. A reminder already shown stays in the notification tray when the app restarts. Saving a goal or checking in a habit still sets that kind of reminder again.
- Reminder times follow a change of time zone.
- Changing how early task reminders come, or turning reminders back on, no longer drops a task reminder that is still to come.
- Tapping a reminder opens the screen it is about.
- Reminder text follows the app language.
- The app no longer asks for a push notification token, since nothing sends push messages yet.
- A step-by-step check for reminders on a real phone is in docs/DEVICE_REMINDER_PROTOCOL.md. It has not been run on a device yet.
- The first-run guide no longer blocks the app. It has two steps: add your first task with a time, then find it in My plan. Each step has "Skip this step", and the guide ends when you tap "I found my task".
- If you add your first task with Today's own Add button instead of the guide, the guide goes on to "Find your saved task" the next time you open the app, instead of asking for a first task again.
- After the guide saves your first task, the app asks for notification permission at that moment, then opens My plan whatever you answer.
- Help now appears as small cards, each shown once, that leave the page usable. People who skipped setup or paused the guide see them too, and the pause message now says so.
- New one-time cards on Habits, Goals and Settings › Notifications. Existing users will see up to ten such cards, once each.
- A card about a page appears only on that page. The Today card now says where to read why a task was suggested: tap "Review my day in detail".
- Your first touch on Insights no longer removes its card. Scrolling, changing the time range or picking an option to compare does.
- Opening the app on another tab no longer uses up the Today card before you have seen it.
- A habit card shows when its reminder cannot be delivered.
- Restoring a backup ends the first-run guide for a returning account. Setup itself still shows once on a new install.
- Guide and help wording is rewritten in plain words in English and Spanish.
- Settings has an in-app Help screen with search.
- The guide status in Settings counts only things you did, not dismissed cards or a restart.
- Unused setup code is removed.
- The assistant has one name and two modes: "On this device · free" and "AI chat". One switch at the top of Chat and Choose a step moves between them, and what you typed goes with you.
- AI chat is off until you allow it. Before the first message it shows what will be sent, where it goes and what it costs, and a line above the message box lists what is included.
- A paid AI request is saved before it is sent. If you leave, lose connection or sign in again, the same request is collected if you come back within a few minutes, without a second charge. After that the reply cannot be collected and the app says it may have used credits.
- When a paid request fails, the message says "nothing was charged" only when that is known. Otherwise it says the request may have used credits and to check your balance.
- Each AI reply shows what it cost and the balance left after it. The balance at the top of Chat shows only when it is known to be current.
- Eight one-tap questions are answered on this device for free in Chat, and three of them on Today: plan my day, what's coming up and what am I falling behind on. Each answer shows the facts it used and what is missing.
- A task with a due date and no time counts as overdue only after that day ends.
- Day counts in free answers stay right across a clock change.
- AI chat can optionally include habits, recent results and goal progress. This is built but switched off in this release.
- Settings no longer shows assistant release controls. The assistant beta is no longer offered; an account that joined earlier has a switch to leave it.
- "Memory governance" in Settings is now "What Axiomara remembers", in plain words.
- Plans and credits now says "AI chat credit plans".
- The old assistant code that the app no longer used is removed.
- Server changes are written, with tests, but not deployed yet, and the database change has not been run yet: record text is kept out of the AI's instructions, the reply filter removes only the sentence at fault, refunded requests do not count toward the daily limit, and reply reports are blanked after 180 days.
- The Insights tab has two parts: Patterns, which shows what you recorded, and Future outcomes, which shows estimates. A switch at the top moves between them, and the tab opens on Future outcomes.
- Future outcomes estimates now use the time range you pick (7, 30 or 90 days) and your free time from your working hours. Workload is the share of that free time the tasks in the range need, so the numbers may differ from before. They are estimates, not promises.
- A "capacity right now" limit you share counts for today only, not for every day of the range.
- The "keep going" forecast is recorded automatically on this device, at most once a day for 7 days and once a week for 30 and 90 days, and checked later against what you recorded. Recorded accuracy can widen or narrow the ranges. Nothing leaves this device.
- Patterns shows streaks and consistency for each habit, how many tasks you finished, when you usually get things done, the work planned for the coming days and what was missed.
- On Future outcomes, the button on an option opens the task it is about (Mark done… or Edit this task), Choose a step or Schedule. Nothing changes until you confirm.
- The priority menu in the task editor no longer runs off the screen with large text.

## Future release entries

Each published entry will identify:

- The release date and public version or build identifier.
- User-visible additions and improvements.
- Material fixes, known limitations, or compatibility notes.
- The relevant distribution or availability status.

Release notes will describe verified shipped behavior only. Planned work, test-only behavior, and unverified candidates will not be presented as released features.

## Support

For help with Axiomara, visit [Axiomara Support](https://ghostheart5.github.io/fantastic-guacamole/support/).
