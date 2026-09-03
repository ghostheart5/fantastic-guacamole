/// CHRONOSPARK-CLASS: SHIPPING | Feature: Authentication routing
///
/// Authentication callback modes recognized by the application boundary.
///
/// Unknown query values must be rejected before they reach presentation code.
enum DeepLinkMode { recovery, verifyEmail, authCallback }
