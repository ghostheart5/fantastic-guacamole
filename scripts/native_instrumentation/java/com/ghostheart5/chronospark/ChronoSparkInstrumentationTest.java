package com.ghostheart5.chronospark;

import androidx.test.rule.ActivityTestRule;
import dev.flutter.plugins.integration_test.FlutterTestRunner;
import org.junit.Rule;
import org.junit.runner.RunWith;

@RunWith(FlutterTestRunner.class)
public final class ChronoSparkInstrumentationTest {
    @Rule
    public ActivityTestRule<MainActivity> activity =
            new ActivityTestRule<>(MainActivity.class, true, false);
}
