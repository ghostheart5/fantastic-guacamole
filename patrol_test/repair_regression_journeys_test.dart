import 'notification_settings_journey_test.dart' as reminders;
import 'notification_delivery_journey_test.dart' as delivery;
import 'remaining_user_journeys_test.dart' as journeys;
import 'tutorial_planner_journey_test.dart' as tutorial;

// Each independently recorded journey uses the real app bootstrap and ordinary
// visible controls. This entrypoint adds no state overrides or hidden setup.
void main() {
  tutorial.main();
  journeys.main();
  reminders.main();
  delivery.main();
}
