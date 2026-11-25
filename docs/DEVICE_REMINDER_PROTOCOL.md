# Axiomara reminder check on a real phone

This is a hands-on checklist for the app owner. It checks that reminders really
arrive on a physical Android phone, in the situations where phones tend to
delay or drop them (screen locked, restart, battery saver, and so on).

Nothing in this document has been run yet. Every results table below is empty on
purpose. Fill each one in as you go. A step is only "passed" when you saw it with
your own eyes on the phone.

This protocol was written against the app code at commit `04c7e960` on branch
`claude/phase2-scheduling-notifications`. If your QA build is older than that, some
steps will not match. Say so in the notes.

## What you need

- The Moto (moto g stylus 5G 2022) with the QA build of Axiomara installed. Its
  Android package name is `com.ghostheart5.chronospark.qa`. It is the debug build
  made with `--dart-define-from-file=tool/qa_defines.json`. It keeps data on the
  phone only, and cloud is off. That is fine for every step here.
- A charged phone and a charger within reach. You will restart it once.
- About 3 hours in total. You can split the steps across a few sittings. Each test
  says how long to wait.
- The phone's clock must be right. Do not change it by hand. Leave "Set time
  automatically" on except in test 6.
- A second way to see the time (a watch, or a computer clock) is handy, so you
  can note when a reminder really arrived.

## Rules that apply to every test

1. Android may deliver app reminders a few minutes late. This app asks Android
   for "inexact" alarms, which Android is allowed to bunch together and hold back
   to save battery. The delay can be longer with Battery Saver on, or when the
   phone has been sitting idle. So after the time a reminder is due:
   - Wait up to 10 minutes. If it arrives within that window, mark Pass and
     write down how many minutes late it was.
   - If it arrives later than 10 minutes but before 30, mark Pass with a note
     "late" and the delay. This is useful information, not a failure of the app.
   - If nothing has come after 30 minutes, mark Fail.
   These limits are suggestions so everyone judges the same way. Change them if
   you prefer, but write down what you used.
2. Never use "Force stop" on the app (Settings > Apps > Axiomara > Force stop).
   Android cancels every alarm of an app that is force-stopped, so a reminder
   cannot arrive afterwards and that would not be a fair test. To close the app,
   open the recent apps screen and swipe Axiomara away instead.
3. The app also shows its own reminder text in the app language (English or
   Spanish, following the phone language). All reminder wording below is the
   English wording. Test 12 covers Spanish.
4. The app can also send a "Daily Planning Reminder" at its own time of day
   (it is on by default). If one turns up while you are testing, it is not part
   of the check. Ignore it, but you may write it in the notes.
5. When a test says "create a task", do it like this. Use the same steps every
   time:
   1. Open the app. Tap **Browse tools** (the menu button), then **Add something**.
   2. Under **What to save**, choose **Task**.
   3. Type a short title in **Title \***, for example `Reminder test 1`.
   4. Open **Task options (optional)**. Under **When to work on it (optional)**
      tap **Schedule date and time...**. Pick today in the date picker, tap OK,
      then pick the time in the clock picker (if you see a dial, the small
      keyboard icon lets you type the time instead), tap OK.
      Work out the time before you start (now plus the minutes the test says),
      because the picker does not do the sum for you.
   5. Tap **Save task**.
   The reminder is for the time under **When to work on it**. The **Due date**
   field only takes a date, with no time. A task with only a due date gets its
   reminder at 09:00 that morning, which is why these tests do not use it.
6. Check the phone is ready before each test. Open Settings (Browse tools >
   **Settings**), open the **Notifications** section, and read the line at the
   top. It should say **Reminders can arrive on this device.** If it says
   anything else, fix that first (see test 8) or the test cannot work.

## Before you start: set up once

| Step | What to do | What you should see |
| --- | --- | --- |
| S1 | In Android: Settings > About phone. Write down the Android version and the model in the results table. For the app build: Android Settings > Apps > Axiomara (the QA one) > App details shows the version at the bottom. Write it down. If you cannot find it, write the date you installed the QA build instead. | You have the device, Android version and build (or install date) to record. |
| S2 | Open Axiomara (QA). Go to Browse tools > **Settings** > **Notifications**. Make sure the **Reminders** switch is on, **Task Reminders** is on and **Overdue nudges** is off. | Switches as described. The top line says "Reminders can arrive on this device." |
| S3 | In the same area, under **Task Reminders**, set **Task reminder time** to **5 minutes before**. | The drop-down shows "5 minutes before". |
| S4 | The first time you save a task that has a date, the app asks to allow notifications. When it shows **Enable Notifications**, tap **Allow Notifications**, then in Android's own box tap **Allow**. | You land back in the app and the task saves. |

If the phone does not show an Android permission box at all, notifications may
already be allowed. That is fine.

### Results table: device

| Device | Android version | App build | Date | Tester |
| --- | --- | --- | --- | --- |
| Moto g stylus 5G (2022) | | | | |

## How the app decides when a task reminder comes

Read this once. It explains the times you will calculate.

- With **Task reminder time** set to **5 minutes before**, a task scheduled for
  15:00 reminds you at 14:55. The reminder says **Starting soon** and
  `"Reminder test 1" starts in 5 minutes.`
- If you save the task inside that 5 minute window (for example you save a 15:00
  task at 14:58), the reminder comes at 15:00 itself. It says **Time to start**
  and `"..." starts now.` Always schedule tasks at least 8 minutes ahead to avoid
  this.
- **At the time** (the default setting) gives **Time to start** at the task time.
- A task that is done, skipped or deleted has its reminder cancelled.
- The app keeps at most 20 task reminders waiting at once (the nearest ones).

## Test 1: Reminder arrives with the app closed

Goal: a task reminder reaches you 5 minutes ahead when the app is not open.

| Step | What to do | What should happen |
| --- | --- | --- |
| 1.1 | Create a task titled `Reminder test 1` scheduled **12 minutes from now** (see rule 5). Write the exact scheduled time in the table. | The task saves. |
| 1.2 | Close the app: open recent apps and swipe Axiomara away. Do not use Force stop. Put the phone down with the screen on or off, as you like. | The app is closed. |
| 1.3 | Wait. The reminder is due at the scheduled time minus 5 minutes, which is **7 minutes after you saved**. Allow up to 10 more minutes (rule 1). | A notification appears: **Starting soon**, `"Reminder test 1" starts in 5 minutes.` |
| 1.4 | Do not tap it yet. Check for a second, later notification for the same task. | You should get exactly one. None at the scheduled time itself. |

## Test 2: Screen locked

Goal: a reminder still arrives while the phone is locked.

| Step | What to do | What should happen |
| --- | --- | --- |
| 2.1 | Create `Reminder test 2` scheduled **12 minutes from now**. | The task saves. |
| 2.2 | Lock the phone with the power button. Leave it locked and untouched for the whole wait. | The screen goes dark. |
| 2.3 | After 7 minutes (plus up to 10 minutes of lateness), look at the phone without unlocking it. If nothing has come 30 minutes after the due time, keep waiting up to 60 and write down when it finally comes (late, not lost). | A notification appears on the lock screen. The screen may light up or it may only show when you press the power button. Either way, note which one. If your lock screen hides notification content, it may only say a notification from Axiomara is waiting. That is an Android setting, not a fault. |

## Test 3: After a restart, without opening the app

Goal: reminders survive a restart. The app asks Android to bring them back
after a reboot.

| Step | What to do | What should happen |
| --- | --- | --- |
| 3.1 | Create `Reminder test 3` scheduled **25 minutes from now**. | The task saves. |
| 3.2 | Close the app by swiping it away. | The app is closed. |
| 3.3 | Restart the phone (hold the power button, tap **Restart**). When it is back, unlock it once with your PIN or fingerprint so Android finishes starting up. **Do not open Axiomara.** | The phone is back on the home screen. |
| 3.4 | Wait until about 20 minutes after you saved the task, plus up to 10 minutes of lateness. Leave the app closed. | A notification appears: **Starting soon**, `"Reminder test 3" starts in 5 minutes.` |

If the restart takes you past the reminder time, the reminder cannot arrive any
more. Make that a "not valid, repeat" and use a later time (30 minutes).

If 3.4 passes, you proved reminders survive a restart without opening the app.
If it fails, open the app once and check whether the reminder then appears at the
right time. Write that in the notes, since "returns only after opening the app"
is a different result from "never returns".

## Test 4: Airplane mode

Goal: reminders do not need the internet.

| Step | What to do | What should happen |
| --- | --- | --- |
| 4.1 | Create `Reminder test 4` scheduled **12 minutes from now**. | The task saves. |
| 4.2 | Swipe down from the top of the screen and turn on **Airplane mode**. Make sure Wi-Fi and mobile data are both off. Close the app by swiping it away. | The airplane icon shows at the top. |
| 4.3 | Wait 7 minutes (plus up to 10 minutes of lateness). | A notification appears: **Starting soon**, `"Reminder test 4" starts in 5 minutes.` |
| 4.4 | Turn Airplane mode off again. | |

## Test 5: Battery Saver on

Goal: see how much Battery Saver delays a reminder.

| Step | What to do | What should happen |
| --- | --- | --- |
| 5.1 | Create `Reminder test 5` scheduled **12 minutes from now**. | The task saves. |
| 5.2 | Turn on Battery Saver: Android Settings > Battery > Battery Saver > turn on. Close the app by swiping it away. Lock the phone. | The battery icon shows the saver mark. |
| 5.3 | Wait 7 minutes. Write down the time it arrives. Wait up to 30 minutes in total (rule 1). If it has not come by then, keep waiting up to 60 and write down when it comes (late, not lost). | A notification appears: **Starting soon**, `"Reminder test 5" starts in 5 minutes.` It may be late. |
| 5.4 | Turn Battery Saver off again. | |

For this test the lateness is the interesting result. Always write down the
number of minutes late, even when you mark Pass.

## Test 6: Time zone change

Goal: after you travel to another time zone, reminders still arrive, once, at
a time that agrees with the clock the app shows.

The app re-reads the phone's time zone each time you bring it back to the front.
So the change only gets picked up when you open the app after changing it.

| Step | What to do | What should happen |
| --- | --- | --- |
| 6.1 | Create `Reminder test 6` scheduled **20 minutes from now**. Write down the phone's clock time and the task's scheduled time. | The task saves. |
| 6.2 | In Android Settings > System > Date & time, turn off **Set time zone automatically** and choose a zone **one hour earlier** than yours. (Menu names differ a little between phone versions.) The phone clock moves back one hour. | The clock on the phone now shows a time one hour earlier. |
| 6.3 | Open Axiomara. In **My plan** find `Reminder test 6` and write down the time it now shows. Then close the app by swiping it away. | The app shows the task. Write what time it shows. |
| 6.4 | Work out when the reminder should arrive: 5 minutes before the time the app shows in 6.3, on the phone's new clock. If that moment has already passed, or is more than 90 minutes away, write "not waited" and skip to 6.6. Otherwise wait for it, plus up to 10 minutes of lateness. | A **Starting soon** reminder arrives once, at the time that agrees with what the app showed in 6.3. |
| 6.5 | Check there is no second reminder at the old time. | None. |
| 6.6 | Put Android back: turn **Set time zone automatically** on. Open the app once. | The phone clock is correct again. |

It is not known beforehand whether the app keeps a task at the same clock time
or at the same moment when you change zone. Either can be right. What matters is
that the reminder agrees with the time the app shows, and arrives once. Write
exactly what you saw in the notes.

## Test 7: Finish the task first, and no reminder comes

Goal: completing a task before its reminder time cancels the reminder.

| Step | What to do | What should happen |
| --- | --- | --- |
| 7.1 | Create `Reminder test 7` scheduled **15 minutes from now**. | The task saves. |
| 7.2 | Open **My plan** (bottom bar), find `Reminder test 7` and tap **Complete**. | The task shows as completed. |
| 7.3 | Close the app. Wait until 5 minutes before the time plus 10 minutes. | **No** notification arrives for this task. |
| 7.4 | Repeat 7.1 to 7.3 with a task called `Reminder test 7b`, but remove it instead of completing it. In **My plan**, find the task and tap **Delete** on its card. A box titled **Remove task from active planning?** appears. Tap **Remove task**. | The task disappears from the active list. **No** notification arrives for it. |

## Test 8: Say no to notifications, then allow them later

Goal: the app asks politely, does not nag, and recovers when you change your
mind.

This test needs the app to have no notification permission yet. The easiest way
is to start the QA app fresh. In Android Settings > Apps > Axiomara (check it is
the QA one, with `.qa` in its details) > Storage > **Clear data**. Warning: this
erases the QA app's test data on the phone and resets its permissions. That is
fine for the QA build. You will need to click through its first-time screens
again. **Clear data also resets your settings** (the 5 minute lead from S3 goes back to "At the time", and switches go back to their defaults), so step 8.1 redoes the S2 and S3 checks. Quiet hours and the language are also reset. Tests 9 and later assume you did step 8.1; if you skip test 8, you do not need to.

| Step | What to do | What should happen |
| --- | --- | --- |
| 8.1 | Open the app and finish the first-time screens. Before creating anything, redo S2 and S3: Settings > **Notifications**, check **Reminders** and **Task Reminders** are on and **Overdue nudges** is off, and set **Task reminder time** to **5 minutes before** again. (The top status line may already say notifications are off. That is expected here.) Then create `Reminder test 8` scheduled **30 minutes from now**. | When you save, a sheet called **Enable Notifications** appears after the task is saved. |
| 8.2 | Tap **Not Now**. | The task is still saved. No Android permission box appears. |
| 8.3 | Open **Today**, then **Goals**. | Each shows a notice: **Reminders are on, but notifications are off for Axiomara.** with a **Turn on notifications** button. |
| 8.4 | Create another dated task (`Reminder test 8b`, 30 minutes ahead). | The app does **not** ask for permission again by itself. |
| 8.5 | Open Settings > **Notifications**. | The top line says **Notifications are off for Axiomara, so reminders cannot arrive.** with a **Turn on notifications** button. |
| 8.6 | Tap **Turn on notifications**, then **Allow Notifications** in the sheet, then **Allow** in Android's box. If Android's box does not appear (Android only shows it twice), the app opens the phone's settings for the app instead: switch **Notifications** on there and go back. | The top line changes to **Reminders can arrive on this device.** The notice on Today and Goals goes away. |
| 8.7 | Close the app by swiping it away. Wait until `Reminder test 8` is 5 minutes away, plus up to 10 minutes. (If you took longer than 25 minutes to get here, create a fresh task and use that.) | A **Starting soon** reminder arrives. This proves reminders set while permission was off are still delivered after you allow it. |

Write down in the notes if the reminder for the task saved while permission was
off did not arrive, but a task saved after allowing did.

## Test 9: Tap a reminder with the app closed

Goal: tapping the reminder opens the right place in the app.

| Step | What to do | What should happen |
| --- | --- | --- |
| 9.1 | Create `Reminder test 9` scheduled **12 minutes from now**. Close the app by swiping it away. | |
| 9.2 | When the reminder arrives, tap it (from the lock screen too if you like). | The app starts and opens **My plan**. It does not need a second tap. |
| 9.3 | Do 9.1 and 9.2 a second time with `Reminder test 9b`, to be sure a cold-start tap works every time. | The app opens **My plan** again. (The app only drops a closed-app tap when the app has taken more than 2 minutes after launching to become ready to route it, for example a very slow sign-in. You cannot trigger that on purpose, and waiting before you tap does not matter. If you ever land on the normal start screen after a tap, write down how long the app took to open.) |
| 9.4 | Tap a reminder while the app is open in the background (home button, not swiped away). | The app comes to the front on **My plan**. |

Where each reminder opens in the app:
- Task reminder: **My plan** (the task list, not one single task).
- Habit reminder: the habit check-in list.
- Goal reminder: **Goals** (the list, not one single goal).

## Test 10: Quiet hours hold a reminder

Goal: a reminder that falls inside quiet hours waits until quiet hours end.
Quiet hours only move reminders the app works out itself: task and goal reminders.
Times you choose yourself (habits, daily planning, reflection) are not moved.

Do not run this test close to midnight.

| Step | What to do | What should happen |
| --- | --- | --- |
| 10.1 | Open Settings > **Notifications**. Under **Task Reminders**, set **Task reminder time** to **At the time**. | The drop-down shows "At the time". |
| 10.2 | Under **Quiet hours**, turn the switch on. Two rows appear: **Starts** and **Ends**. Tap **Starts** and set it to **5 minutes ago**. Tap **Ends** and set it to **25 minutes from now**. (They must be different times.) | Starts and Ends show your times. |
| 10.3 | Create `Reminder test 10` scheduled **10 minutes from now**. | The task saves. |
| 10.4 | Close the app. At the scheduled time plus 5 minutes, check the phone. | **No** notification yet. It is being held. |
| 10.5 | Wait for the Ends time, plus up to 10 minutes of lateness. | The notification arrives now: **Time to start**, `"Reminder test 10" starts now.` |
| 10.6 | Turn **Quiet hours** off again. Set **Task reminder time** back to **5 minutes before** if you want to continue with the other tests. | |

Note: if you try this with a lead time such as 5 minutes before, the held
reminder may still read "starts in 5 minutes" even though it arrives after the
task time. If you see that, write it in the notes. It is a wording thing.

## Test 11: Main Reminders switch off, then on

Goal: switching **Reminders** off stops everything, switching it on brings it
back.

| Step | What to do | What should happen |
| --- | --- | --- |
| 11.1 | Set **Task reminder time** to **At the time** (Settings > Notifications). | |
| 11.2 | Create `Reminder test 11a` scheduled **10 minutes from now** and `Reminder test 11b` scheduled **25 minutes from now**. | Both save. |
| 11.3 | Settings > Notifications. Turn the **Reminders** switch **off**. | The top line says **Reminders are off. Turn on Reminders below to get them again.** The other switches look greyed out. |
| 11.4 | Close the app. Wait until 15 minutes after saving (past the time of 11a plus a few minutes). | **No** notification for `Reminder test 11a`. |
| 11.5 | Open the app, Settings > Notifications, and turn **Reminders** back **on** (after 11a's time has passed, before 11b's time). | The top line says **Reminders can arrive on this device.** |
| 11.6 | Close the app. Wait for 11b's time, plus up to 10 minutes. | `Reminder test 11b` arrives (**Time to start**). `Reminder test 11a` does **not** arrive late, because its time already passed. |

Your other switch choices (Goal, Habit, Task, lead time) should still be as you
left them after the switch goes back on.

## Test 12: Spanish

Goal: reminder wording follows the phone language.

| Step | What to do | What should happen |
| --- | --- | --- |
| 12.1 | Set **Task reminder time** to **5 minutes before**. Then change the phone language: Android Settings > System > Languages > add **Español** and move it to the top. | The phone is in Spanish. |
| 12.2 | Open Axiomara. Go to **Ajustes** > **Notificaciones**. | The top line reads **Los recordatorios pueden llegar a este dispositivo.** The switch reads **Recordatorios**, and the lead time reads **Hora del recordatorio de tareas** with **5 minutos antes**. |
| 12.3 | **Create the task after changing the language.** Tap **Ver herramientas**, **Añadir algo**, choose **Tarea**, title it `Prueba 12`, open **Opciones de la tarea (opcional)** > **Elegir fecha y hora...** and schedule it **12 minutes from now**. Tap **Guardar tarea**. | The task saves. |
| 12.4 | Close the app. After 7 minutes (plus up to 10), look at the notification. | **Empieza pronto**, `«Prueba 12» empieza en 5 minutos.` |
| 12.5 | Put the phone language back to English. | |

If the notification is in English, write that in the notes. A reminder saved
before the language change keeps its old language until the app plans again.

## Optional test 13: Habit reminder

| Step | What to do | What should happen |
| --- | --- | --- |
| 13.1 | **Add something** > **Habit**. Title `Reminder habit`. Under **Reminder** (default is **Any time**, meaning no reminder) tap **Other time...** and pick **6 minutes from now**. Tap **Save habit**. | The line under the chips reads "Reminder at ... every day" (or similar). |
| 13.2 | Close the app. Wait for that time plus up to 10 minutes. | A notification titled **Reminder habit** arrives: `Time for "Reminder habit". Tap to check in.` |
| 13.3 | Tap it. | The app opens the habit check-in list. |

Weekly habits let you choose weekdays. Monthly habits let you choose a day of the
month or **Last day**. These need days of waiting, so they are covered only in
the "expected, not a failure" list below.

## Optional test 14: Goal reminders

Goal reminders arrive at 09:00 three days before, 09:00 the day before and 09:00
on the day. There is also an 18:00 same-day reminder for a goal due **today**
that you create after 09:00 (only if 18:00 is at least 30 minutes away).

| Step | What to do | What should happen |
| --- | --- | --- |
| 14.1 | Run this between 09:30 and 17:00. **Add something** > **Goal**. Title `Reminder goal`. Open **Add a target date (optional)**, tap **Add target date...**, pick today in the date picker and tap OK. Tap **Save goal**. | The goal saves. |
| 14.2 | Close the app. Wait until 18:00 plus up to 10 minutes. | **Goal due today**, `"Reminder goal" is due today.` |
| 14.3 | Tap it. | The app opens **Goals**. |

For the 09:00 reminders, create a goal with a target date 3 days ahead, 2 days
ahead and tomorrow and check each morning. Write what arrives and when.

## Things that are expected, not a failure

If you see one of these, write it in the notes but do not mark Fail.

- A reminder arrives a few minutes late. See rule 1.
- **Monthly "last day" reminders.** If the app is not opened for a whole month,
  the last-day reminder for the next month can arrive a day early or be skipped.
  Opening the app brings it back to normal.
- **A monthly reminder set after this month's chosen day.** For example you set a
  reminder for the 10th on the 20th. The first one comes next month, not this
  month.
- Tasks with only a due date (no time) are reminded at 09:00 that day. If a task
  is saved after 09:00 on its due day, no reminder comes for it that day.
- Overdue nudges are off by default. When on, one comes at 09:00 the day after
  something was due, if it is still open.
- Only the nearest 20 task reminders are kept waiting. A task far in the future
  may only get its reminder once nearer tasks are done or past.
- A reminder with the app force-stopped does not arrive. That is Android, and it
  is why rule 2 tells you not to force-stop.

## Results table

Fill one row per test. "Arrived at" is the real time on the phone. "Minutes
late" is arrival minus the time the reminder was due.

| # | Test | Date | Due at | Arrived at | Minutes late | Pass / Fail / Not run | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | App closed, 5 minutes ahead | | | | | | |
| 2 | Screen locked | | | | | | |
| 3 | After restart, app not opened | | | | | | |
| 4 | Airplane mode | | | | | | |
| 5 | Battery Saver | | | | | | |
| 6 | Time zone change | | | | | | |
| 7 | Completed first, no reminder | | | | | | |
| 7b | Deleted first, no reminder | | | | | | |
| 8 | Said no, then allowed later | | | | | | |
| 9 | Tap with app closed opens My plan | | | | | | |
| 9b | Second tap with the app closed | | | | | | |
| 10 | Quiet hours hold, then deliver | | | | | | |
| 11 | Main switch off, then on | | | | | | |
| 12 | Spanish wording | | | | | | |
| 13 | Habit reminder (optional) | | | | | | |
| 14 | Goal reminder (optional) | | | | | | |

## When you are finished

- Put the filled-in file (or a photo of the tables) next to the Moto
  walkthrough notes.
- Put the phone back as it was: Airplane mode off, Battery Saver off, time zone
  automatic, language English, Quiet hours off.
- If any test failed, write down the build, the exact steps you took and what you
  saw, and hand it to the person fixing the app. A screenshot of the Settings >
  Notifications top line helps a lot.

Related: `docs/REPAIR_TESTING_20261014.md` says delivery under Doze and restart is
not established. This protocol is how to establish it.
