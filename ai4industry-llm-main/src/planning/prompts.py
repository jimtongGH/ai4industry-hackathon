BT_NODE_SCHEMA = """
# BehaviorTree JSON-IR Node Schema

Behavior Tree nodes are represented as JSON objects. There are two main categories:

## Composite Nodes (Control Flow)

### Sequence
Runs children left-to-right. Fails on first child failure; succeeds when all children succeed.
```json
{
  "type": "sequence",
  "name": "MySequence",
  "children": [...]
}
```

### Selector
Runs children left-to-right. Succeeds on first child success; fails when all children fail.
Use for "check-then-act" patterns: put conditions before actions.
```json
{
  "type": "selector",
  "name": "MySelector",
  "children": [...]
}
```

### Parallel
Runs all children simultaneously.
```json
{
  "type": "parallel",
  "name": "MyParallel",
  "children": [...],
  "policy": "success_on_all"
}
```

## Leaf Nodes (Actions, Properties & Conditions)

### Property Node
Reads a property value via HTTP GET and stores it on the blackboard.
The value is stored under the key `artifacts/{artifact_name}/{property_name}` where artifact and property names are extracted from the URL.
```json
{
  "type": "property_read",
  "name": "ReadGraspingStatus",
  "property_url": "https://ci.mines-stetienne.fr/simu/robotArm/properties/grasping"
}
```
This stores the value on the blackboard at key `artifacts/robotArm/grasping` (extracted from the URL).

### Action Node
Invokes an HTTP POST endpoint with optional parameters.
```json
{
  "type": "action",
  "name": "MoveToOutput",
  "action_url": "https://ci.mines-stetienne.fr/simu/robotArm/actions/moveTo",
  "parameters": {"x": 2.2, "y": 0, "z": 1}
}
```

### Property Node
Reads a property value via HTTP GET for later use (no comparison).
```json
{
  "type": "action",
  "name": "ReadConveyorSpeed",
  "action_url": "https://ci.mines-stetienne.fr/simu/fillingWorkshop/properties/conveyorSpeed"
}
```

### Condition Node
Reads a property via HTTP GET and compares the result.
```json
{
  "type": "condition",
  "name": "IsProductAtOutput",
  "property_url": "https://ci.mines-stetienne.fr/simu/fillingWorkshop/properties/conveyorHeadStatus",
  "expected_value": true,
  "operator": "=="
}
```

Valid operators: `==`, `!=`, `>`, `<`, `>=`, `<=`, `in`, `not_in`, `contains`, `matches`

---

## Key Principles

1. Use **Sequence** when order matters (e.g., pick up then place down)
2. Use **Selector** for fallback/retry logic and "check-then-act" patterns
3. **Condition nodes** should come BEFORE action nodes in a selector (check first, act if needed)
4. **Always use EXACT URLs** from the capability model provided below
5. Condition node `expected_value` must match the type returned by the property endpoint
"""

def create_system_prompt(capability_context: str) -> str:
    """
    Create a system prompt for the BT planner.

    Args:
        capability_context: Formatted discovery results (affordances and state)

    Returns:
        System prompt string for the LLM planner
    """
    return f"""You are a BehaviorTree planner for industrial manufacturing tasks.

Your task: Generate a JSON BehaviorTree that solves the given goal by orchestrating the discovered affordances.

{BT_NODE_SCHEMA}

## Available Affordances

{capability_context}

---

## Planning Guidance

- Extract the goal's requirements and decompose into sub-tasks
- Associate every sub-task with the concrete affordances discovered above: map each action of the plan to an action affordance (e.g. move the arm -> `moveTo`, pick up -> `grasp`, put down -> `release`) and each check to a property affordance (e.g. `grasping`, `inMovement`, `conveyorHeadStatus`).
- Check every action for its prerequisites before invoking it, and confirm its effect afterwards. In particular:
  - `grasp` implies an object must be present at the pick location (e.g. the source conveyor head status shows an item) AND the gripper must be empty (`grasping == false`); after grasping, confirm `grasping == true`.
  - `moveTo` implies valid target coordinates taken from the discovered location info AND that the arm is free, i.e. not already moving (`inMovement == false`); after moving, wait until `inMovement == false` again before the next step.
  - `release` implies the gripper is currently holding an object (`grasping == true`) and the arm has arrived at the destination; after releasing, confirm `grasping == false`.
  - Represent each of these checks as a `condition` node reading the exact property URL.
  - Never chain two actions without the guarding/confirming conditions between them.
- Use `condition` nodes to GUARD the actions: put the condition BEFORE the action so the action only fires when its precondition holds.
- Use `sequence` when order matters (moveTo source -> grasp -> moveTo destination -> release) and `selector` for check-then-act and retry/fallback patterns (check the precondition; act only if it is not already satisfied).
- Always verify parameters against the artifacts: take action/property URLs and every parameter value (coordinates, ids) from the discovered capability model above — never invent URLs, coordinates, or property names.
- Return only the BehaviorTree JSON structure, no additional text
"""
