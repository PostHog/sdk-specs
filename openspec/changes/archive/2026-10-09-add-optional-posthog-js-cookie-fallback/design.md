## Context

posthog-js keeps `distinct_id`, `$sesid` and `$user_state` in the `ph_<token>_posthog` cookie (`COOKIE_PERSISTED_PROPERTIES`), cross-subdomain by default. A server on the same site receives it with no frontend configuration.

## Decisions

**Off by default.** posthog-js stores opt-out consent in localStorage by default, and keeps the persistence cookie after opt-out unless configured otherwise. The server cannot see that opt-out, so a default-on fallback would keep linking backend events to a visitor who rejected tracking.

**Keep the anonymous distinct id, without a new profile.** posthog-js defaults to `identified_only` person profiles, so an anonymous cookie distinct id must not create a person profile for every anonymous visitor who calls the backend. `$process_person_profile = false` prevents that on its own, so the fallback keeps the anonymous distinct id and sets that property, rather than generating a random id. This keeps browser and backend events on the same distinct id, which is how `@posthog/next` propagates identity. An existing profile for that distinct id can still be associated with the event. An explicit or authenticated distinct id overrides the cookie, and then the cookie `$user_state` does not change person processing.

**Headers or cookie, never both.** Mixing a header distinct id with a cookie session id can join two identities in one event.

**Session liveness matches posthog-js.** Absolute ages, so a fast browser clock cannot keep a session alive; the idle timeout is configurable and clamped to posthog-js's 60 seconds through 10 hours; the 24-hour cap is fixed.

## Open questions

`persistence_name`, custom consent cookie names and `respect_dnt` are not covered. SDKs document them as limits.
