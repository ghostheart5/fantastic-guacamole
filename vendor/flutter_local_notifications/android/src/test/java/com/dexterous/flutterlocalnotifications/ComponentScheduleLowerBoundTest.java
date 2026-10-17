package com.dexterous.flutterlocalnotifications;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertNull;

import com.dexterous.flutterlocalnotifications.models.DateTimeComponents;
import com.dexterous.flutterlocalnotifications.models.NotificationDetails;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.time.ZonedDateTime;
import org.junit.Test;

/** Calls the actual plugin recurrence function; no mocked clocks or Android alarms. */
public class ComponentScheduleLowerBoundTest {
  private static final ZoneId CHICAGO = ZoneId.of("America/Chicago");

  private static ZonedDateTime at(String local) {
    return LocalDateTime.parse(local).atZone(CHICAGO);
  }

  private static String next(String scheduled, DateTimeComponents components, String now) {
    NotificationDetails details = new NotificationDetails();
    details.timeZoneName = CHICAGO.getId();
    details.scheduledDateTime = scheduled;
    details.matchDateTimeComponents = components;
    String actual = FlutterLocalNotificationsPlugin.getNextFireDateMatchingDateTimeComponents(
        details, at(now));
    if (actual != null) {
      ZonedDateTime result = at(actual);
      assertFalse("Must not precede the caller's first permitted date", result.isBefore(at(scheduled)));
      assertFalse("Must not schedule a past alarm", result.isBefore(at(now)));
    }
    return actual;
  }

  @Test public void futureDailySkipsCurrentCompletedDay() {
    assertEquals("2026-10-14T07:30:00",
        next("2026-10-14T07:30:00", DateTimeComponents.Time, "2026-10-13T06:00:00"));
  }

  @Test public void futureWeeklySkipsCurrentCompletedWeek() {
    assertEquals("2026-10-26T07:30:00",
        next("2026-10-26T07:30:00", DateTimeComponents.DayOfWeekAndTime, "2026-10-13T06:00:00"));
  }

  @Test public void futureMonthlySkipsCurrentCompletedMonth() {
    assertEquals("2026-12-01T07:30:00",
        next("2026-12-01T07:30:00", DateTimeComponents.DayOfMonthAndTime, "2026-10-13T06:00:00"));
  }

  @Test public void futureYearlyHonorsTheFullFirstDate() {
    assertEquals("2028-02-29T07:30:00",
        next("2028-02-29T07:30:00", DateTimeComponents.DateAndTime, "2026-01-01T06:00:00"));
  }

  @Test public void pastDailyCatchesUpToTodayBeforeItsTime() {
    assertEquals("2026-10-13T07:30:00",
        next("2026-10-01T07:30:00", DateTimeComponents.Time, "2026-10-13T06:00:00"));
  }

  @Test public void pastDailyCatchesUpToTomorrowAfterItsTime() {
    assertEquals("2026-10-14T07:30:00",
        next("2026-10-01T07:30:00", DateTimeComponents.Time, "2026-10-13T08:00:00"));
  }

  @Test public void equalFirstDeadlineIsRetained() {
    assertEquals("2026-10-13T07:30:00",
        next("2026-10-13T07:30:00", DateTimeComponents.Time, "2026-10-13T07:30:00"));
  }

  @Test public void dailyRepeatAfterDeliveryAdvancesWithoutHorizon() {
    String previous = "2026-10-14T07:30:00";
    for (int day = 0; day < 400; day++) {
      String expected = at(previous).plusDays(1).toLocalDateTime().toString();
      String actual = next(previous, DateTimeComponents.Time,
          at(previous).plusSeconds(1).toLocalDateTime().toString());
      assertEquals(LocalDateTime.parse(expected), LocalDateTime.parse(actual));
      previous = actual;
    }
  }

  @Test public void weeklyRepeatAfterDeliveryAdvancesAWeek() {
    assertEquals("2026-11-02T07:30:00",
        next("2026-10-26T07:30:00", DateTimeComponents.DayOfWeekAndTime, "2026-10-26T07:30:01"));
  }

  @Test public void monthlyRepeatSkipsMonthsWithoutRequestedDay() {
    assertEquals("2027-03-31T07:30:00",
        next("2027-01-31T07:30:00", DateTimeComponents.DayOfMonthAndTime, "2027-01-31T07:30:01"));
  }

  @Test public void springDstPreservesSevenThirtyAndChangesOffset() {
    String result = next("2027-03-13T07:30:00", DateTimeComponents.Time, "2027-03-13T07:30:01");
    assertEquals("2027-03-14T07:30:00", result);
    assertEquals(-5 * 3600, at(result).getOffset().getTotalSeconds());
    assertEquals(23 * 3600, at(result).toEpochSecond() - at("2027-03-13T07:30:00").toEpochSecond());
  }

  @Test public void fallDstPreservesSevenThirtyAndChangesOffset() {
    String result = next("2026-10-31T07:30:00", DateTimeComponents.Time, "2026-10-31T07:30:01");
    assertEquals("2026-11-01T07:30:00", result);
    assertEquals(-6 * 3600, at(result).getOffset().getTotalSeconds());
    assertEquals(25 * 3600, at(result).toEpochSecond() - at("2026-10-31T07:30:00").toEpochSecond());
  }

  @Test public void unknownMatchingComponentStillReturnsNull() {
    assertNull(next("2026-10-14T07:30:00", null, "2026-10-13T06:00:00"));
  }
}
