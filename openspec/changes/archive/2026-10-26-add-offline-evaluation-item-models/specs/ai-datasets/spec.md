## MODIFIED Requirements

### Requirement: Convert dataset cases into independent executions

Conversion SHALL copy input, expected output, and metadata; preserve the stable dataset-item
ID and exact version ID; and generate a fresh execution UUID unless supplied. Default
`case_key` SHALL be the client item ID when present, otherwise the stable item UUID. Execution
output and application trace ID SHALL come from the caller, never from source output or source
trace provenance. Archived items SHALL be rejected. Multiple scorers can reuse one converted
item; independent trials SHALL use independent execution identities. The experiment SHALL
reference the snapshot's revision UUID, which can differ from an item's introducing revision.

`EvaluationItem.from_dataset_item` SHALL also accept an optional nullable `model_version`
for the new execution, with the same validation, wire placement, inheritance, and replay
semantics as direct evaluation-item construction. A supplied model SHALL be retained in the
converted declaration. Omitted or null values SHALL remain eligible for experiment fallback;
conversion SHALL NOT infer the execution's model from dataset content, metadata, or source
trace provenance. Converting the same case for different model executions SHALL generate
distinct execution UUIDs unless the caller explicitly supplies them, while preserving the
same case key and exact dataset-item version reference.

#### Scenario: Source data does not become a new execution's output
- **GIVEN** an isolated dataset client and an active case with source output, source trace ID, and client item ID "case-1"
- **WHEN** the caller converts the case twice with different execution outputs and trace IDs
- **THEN** the declarations have different execution IDs and the same case key and dataset-item version ID
- **AND** each declaration contains its caller-supplied output and application trace ID

#### Scenario: One dataset case produces executions for two models
- **GIVEN** an active dataset case from a pinned snapshot
- **WHEN** the caller converts it twice with model_version "model-b" and "model-c" and their respective execution outputs
- **THEN** the declarations have distinct execution UUIDs and the same case key and exact dataset-item version ID
- **AND** each declaration retains its caller-supplied model and output through serialization and upload

#### Scenario: Dataset metadata does not supply an execution model
- **GIVEN** an active dataset case with metadata containing model_version "source-model"
- **WHEN** the caller converts the case without a model override or with model_version null
- **THEN** the converted item's model remains unset for experiment fallback
- **AND** the source metadata is copied as payload metadata without becoming execution attribution
