# Device acceptance repairs for 3027

Build3026 was updated through Google Play on the Moto without uninstalling or
clearing data. Version2026083026 and installercom.android.vending were read back.
The existing owner profile retained level20,36137XP and1445 completed tasks,
with the existing bookkeeping goal, task and note still visible.

Two findings require another candidate:

1. Startup logged `startup.state_timed_out` and showed a limited-mode banner.
   Local state bootstrap awaited remote entitlement for up to ten seconds,
   while its caller allowed only four seconds. Bootstrap now starts entitlement
   hydration through its AsyncValue without awaiting the network. Local SI
   initialization completes independently; all existing paid-access consumers
   continue to fail closed while authority is loading or errored. A disposed
   bootstrap calculation cannot continue after its deferred initialization.
   Regressions cover pending authority and authority failure without granting
   premium or blocking local startup.
2. Android accessibility exposed only the Home report's navigation label,
   omitting its visible report and baseline metrics. The same actionable node
   now announces the report, Pressure, Momentum and active commitments,
   including unavailable states. The widget regression verifies the announced
   fixture values and retained Trajectory navigation. Visual layout is unchanged.

Device observations on3026: Energy save/cancel/clear passed; fatigue20% produced
Clarity80%; cancellation did not persist drafts; clearing Clarity preserved
Energy80%. Clearing Energy returned both to unmeasured/not-checked. Energy80%
appeared in Trajectory; Home and Trajectory both reported Momentum BUILDING.
The Home report showed baseline Pressure56%, Momentum0%, active2. These are
observations, not a new completion/endurance run. The owner's transient check-ins
were cleared after the checks. Settings displayed417credits (20included,
397purchased); no purchase or credit debit occurred.

Changed-source analysis and21 focused tests passed, including three unchanged
golden comparisons. The new accessibility test's initial cleanup defect was
corrected before this pass; existing assertions were not weakened.

Build3027 requires fresh full CI, a signed candidate, Play update and device
retest. The hosted instrumentation harness separately passed compilation after
aligning both test classpaths; SDK image installation then failed on some hosts,
so the native15-case gate remains open. Signed qualified review/public paid
activation and the isolated reviewer journey remain open. Production publication
is not authorized. No current candidate is declared production ready here.
