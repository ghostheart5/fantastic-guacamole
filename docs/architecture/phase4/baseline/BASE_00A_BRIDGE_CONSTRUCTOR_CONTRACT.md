# BASE-00A bridge constructor contract

The bridge constructor declared `required this._store`, while every current
production caller uses the public named argument `store:`. The callers are
`auth_service.dart` and `repositories_providers.dart`; both are committed HEAD
callers and neither uses `_store:`. No test previously constructed the bridge.

History shows the private constructor parameter was introduced with the bridge
in `87eac76a`. Current committed callers consistently use `store:`, establishing
the intended public dependency-injection contract.

BASE-00A changes only the HEAD-derived constructor to:

```dart
FirebaseSupabaseBridgeRepository({required SecureStore store}) : _store = store;
```

The private field and all bridge behavior are unchanged. The candidate excludes
the protected BRIDGE-H01/H02/H03 queue, gate, drain, and identity changes.
Focused construction/read validation proves the public argument initializes the
same private dependency. HLM-06 remains separately reconstructable from its
recorded index blob manifest.
