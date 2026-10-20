# Demonstration assessment scoring

This is an invented rule for the technical assignment, authorized as a time-saving assumption. It is not Workhappy/Ergofy's scoring model or a validated ergonomic or medical assessment.

## Questions and response format

Each question asks: “How often does this describe your workstation?”

| Key | Statement |
| --- | --- |
| `chair_support` | My chair does not provide comfortable support. |
| `screen_position` | My screen position makes me adopt an awkward posture. |
| `keyboard_mouse` | My keyboard or mouse position makes my arms or wrists uncomfortable. |
| `desk_space` | My desk or leg space restricts a comfortable working position. |
| `movement_breaks` | I work for long periods without changing position or taking a movement break. |

All questions use the same response scale:

| Value | Label |
| --- | --- |
| 0 | Never |
| 1 | Rarely |
| 2 | Sometimes |
| 3 | Often |
| 4 | Always |

Store answers as JSON integers in `responses_json`. Optional `comments` are free text and never participate in scoring or export. Example:

```json
{
  "chair_support": 2,
  "screen_position": 1,
  "keyboard_mouse": 3,
  "desk_space": 0,
  "movement_breaks": 2,
  "comments": "Synthetic demonstration comment"
}
```

## Formula

All five questions are mandatory and equally weighted:

```text
score = (sum of the five answers / 20) × 100
      = sum of the five answers × 5
```

The example above totals 8, producing **40 / 100**. Higher values mean more reported workstation concerns under this demonstration rule. The result is an integer in steps of five, so no floating-point arithmetic or rounding is needed.

Do not add low/medium/high bands, clinical interpretations, automatic follow-up thresholds, or status transitions. The brief does not define them. Score and workflow status are independent.

## Calculation contract

`AssessmentScore.call(responses_json)` is a pure function with no database queries, writes, logging, clock dependence, or external calls. It returns a small result value:

```text
state: scored | incomplete | invalid
value: integer from 0 to 100 when scored; otherwise nil
reason: nil | missing_answers | invalid_answers | invalid_structure
```

Rules, evaluated in this order:

1. A null payload is incomplete. A non-null payload that is not a JSON object is invalid structure. An empty object is incomplete.
2. Inspect only the five named answer keys. Any present, non-null answer that is not an integer from 0 through 4 makes the result invalid. Strings such as `"2"`, decimals such as `2.0`, booleans, arrays and objects are invalid; do not coerce them with `to_i`.
3. If there are no invalid answers but any required answer is missing or null, the result is incomplete. An empty string is invalid, not missing.
4. Otherwise calculate the sum times five. Extra keys, including comments or an existing `score` field, do not influence the calculation.

Invalid takes precedence over incomplete when both occur in an object. Do not return raw input in reasons or exception messages. Convert HTML form inputs to validated integers at the input boundary if a questionnaire editor is later added; the scorer itself remains strict.

## Dashboard behavior

| Result | Display |
| --- | --- |
| Scored | `40 / 100`, including `0 / 100` for valid zero |
| Incomplete | `Not yet scored` |
| Invalid | `Score unavailable` |

Display a short explanation near the score column: “Demo score: higher values indicate more reported workstation concerns.” Keep score available whenever all five answers are valid, regardless of status. A historical record marked completed but missing answers remains visibly incomplete; do not fabricate a number or change its status automatically.

Calculate from current responses when rendering the bounded dashboard page. Do not persist a second score field or calculate a separate frontend score. CSV includes employee name, creation date, status and this same score. Scored results export as a number from 0–100; incomplete and invalid results use the same labels as the dashboard.

## Acceptance examples

| Input | State | Value |
| --- | --- | --- |
| All five answers 0 | scored | 0 |
| All five answers 4 | scored | 100 |
| All five answers 2 | scored | 50 |
| Answers 2, 1, 3, 0, 2 | scored | 40 |
| Answers 1, 0, 0, 0, 0 | scored | 5 |
| One answer absent; remaining answers valid | incomplete | nil |
| One answer null; remaining answers valid | incomplete | nil |
| Null or empty object | incomplete | nil |
| One answer -1 or 5 | invalid | nil |
| One answer `"2"`, 2.0, true, or empty string | invalid | nil |
| One answer invalid and another absent | invalid | nil |
| Array or string instead of an object | invalid | nil |
| Valid answers plus arbitrary comments/extra keys | scored | Unchanged |

Use these cases as unit-test fixtures and show valid zero, a normal score, and incomplete data in the demo. Describe the formula and its invented status in SOLUTION.md.
