## ADDED Requirements

### Requirement: Existing request span receives analytics context

When the documented server tracing integration is enabled, the SDK SHALL add available request-context IDs to the active, recording request span after header extraction. It SHALL use `sessionId` and `posthogDistinctId`, as defined by the traces capability. This applies when the span started before PostHog request context existed.

#### Scenario: incoming span starts before header extraction
- **GIVEN** a recording request span is active before PostHog middleware runs
- **WHEN** the middleware extracts valid session and distinct IDs into request context
- **THEN** the exported request span has those IDs as `sessionId` and `posthogDistinctId`

### Requirement: Child spans snapshot analytics context

With the documented child-span integration installed, recording spans started inside an active request context SHALL receive its available IDs at span start. The captured values SHALL remain stable if context later changes or ends. Existing native PostHog span behavior remains governed by the traces capability.

#### Scenario: child span ends after its request context
- **GIVEN** a child span starts in request context with session ID "session-one"
- **WHEN** the request context ends and another request uses session ID "session-two"
- **AND** the original child span ends and is exported
- **THEN** that span has `sessionId` "session-one"

### Requirement: Span attributes take precedence over request headers

The bridge SHALL preserve existing span attributes, including at the span's attribute limit. It SHALL omit enrichment that would evict existing attributes. Header-derived identity SHALL remain fallback analytics context and SHALL NOT replace stronger application identity. It SHALL omit missing or empty IDs without generating IDs or creating a recording. The SDK SHALL document which application identity attributes its integration recognizes.

#### Scenario: explicit span attributes win
- **GIVEN** a request span already has explicit `sessionId` and `posthogDistinctId` attributes
- **WHEN** middleware extracts different IDs from the request headers
- **THEN** the explicit attributes remain unchanged

#### Scenario: span has no capacity for enrichment
- **GIVEN** a recording span already contains its maximum number of attributes
- **WHEN** request context offers a missing session or distinct ID
- **THEN** enrichment does not evict any existing attribute

#### Scenario: no session is available
- **WHEN** span enrichment runs with no session ID in request context
- **THEN** it does not add a `sessionId` attribute

### Requirement: Span enrichment respects request lifetime

Span enrichment SHALL use only the active request's context. Concurrent requests SHALL remain isolated. Work that starts a new span after its inherited request scope has ended SHALL NOT receive that ended scope's IDs unless the application explicitly establishes a new context. Already captured span attributes SHALL remain available after scope cleanup.

#### Scenario: concurrent requests use their own IDs
- **GIVEN** two concurrent requests have different session IDs
- **WHEN** each starts a child span
- **THEN** each exported child span has only its own request's session ID

#### Scenario: detached work starts a span after the request ends
- **GIVEN** detached async work inherited a request's execution context
- **AND** that request scope has ended
- **WHEN** the work starts a span without explicitly establishing a new PostHog context
- **THEN** the span does not receive the ended request's IDs

### Requirement: Span enrichment preserves application tracing

The SDK SHALL keep tracing dependencies optional, preserve application providers, processors, exporters, sampling, and request handling, and perform context enrichment on a best-effort basis. It SHALL NOT create spans just to attach IDs. Setup docs SHALL state supported runtimes, optional packages, middleware order, and any processor or listener registration needed for child spans.

#### Scenario: no tracing runtime is installed
- **WHEN** PostHog request-context middleware runs without a tracing runtime
- **THEN** request handling and existing analytics context behavior continue normally

#### Scenario: enrichment lookup fails
- **WHEN** reading the current span or PostHog context fails
- **THEN** the application request continues with its normal result or exception

#### Scenario: application samples out the request
- **WHEN** the application chooses not to record a request span
- **THEN** context enrichment does not change that sampling decision or create a replacement span
