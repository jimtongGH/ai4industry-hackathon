# Step 1 — "Agentifying" the IT'm Factory production process

Design analysis for Part III (Autonomous Agents) of the AI4Industry hackathon.
It identifies the **agents**, **artifacts / environment** and **organisation** that
together monitor and control the whole process running on top of the workshops
(Things) of the IT'm Factory, and argues the design choices.

The concrete implementation of these choices lives in `mas/` (agents in
`src/agt/`, environment in `mas.jcm`, organisation in `src/org/org.xml`).

---

## 1. The process to control

The factory produces filled pots (yoghurt-like cups). The physical flow is:

```
 cup provider ─┐
               ├─▶ VL10 storage rack ─▶ DX10 filling ─▶ APAS robot arm ─▶ XY10 packaging ─▶ finished pots
 dairy provider┘   (convey cups)        (fill cups)     (pot / move)      (package)
```

Each stage is a WoT **Thing** exposing a Thing Description (TD) with property
affordances (sensors/state) and action affordances (commands), reachable over
HTTP under `https://ci.mines-stetienne.fr/simu/<thing>/`. All Things are also
described in the Knowledge Graph (KG) at `https://ci.mines-stetienne.fr/kg/`.

---

## 2. Identified agents

We chose **one agent per controllable Thing** rather than a single monolithic
controller. Each agent is autonomous: it reasons on its own beliefs (extracted
from the KG), pursues its own goals, and coordinates with the others by messages.

| Agent | Controls (Thing) | Functional description |
|-------|------------------|------------------------|
| `cup_provider` | cupProvider | Supplies cups and packages on request (`order`, `orderPackages`); replies with a delivery acknowledgment. |
| `dairy_product_provider` | dairyProductProvider | Supplies dairy product on request (`order`); replies with an acknowledgment. |
| `vl10_agent` | storageRack (VL10) | Conveying workshop: walks the storage grid, picks each cup (`pickItem [X,Z]`) onto the conveyor, reorders cups when empty, and reacts to the stack light (emergency stop / resume). |
| `dx10_agent` | fillingWorkshop (DX10) | Filling workshop: keeps the conveyor running, monitors the tank and reorders dairy product when it runs low, handles emergencies. Filling itself is automatic (optical sensor → valve). |
| `apas_agent` | boschApas | Potting: drives the robot arm to move filled pots from the conveyor to the packaging line (`moveTo`/`grasp`/`release`), observing `inMovement` / `grasping`. |
| `xy10_agent` | packagingWorkshop (XY10) | Packaging workshop: keeps the conveyor running, monitors the package buffer and reorders packages when low, handles emergencies. |
| `ld_spider` | — | Utility agent that crawls the KG to populate/inspect the shared belief base (Linked-Data artifact). |

`leubot_agent` and `template_agent` are provided reference/starter agents.

### Why one agent per Thing (not a single controller)?

* **Autonomy & locality** — each workshop has its own state, failure modes and
  emergency handling; a local agent can react to its own stack light without
  waiting on a central loop.
* **Decentralisation / robustness** — no single point of failure; if one
  workshop stops, the others keep running and simply throttle via ordering.
* **Evolvability** — adding a workshop = adding an agent + its skills file,
  with no change to the others.
* **Natural mapping to coordination** — inter-workshop dependencies become
  explicit messages (orders / acknowledgments), which is exactly what Step 4
  asks us to model.

A single agent controlling everything would be simpler to start but would
serialise all decisions, centralise all failure handling, and scale badly as
the line grows — so it was rejected.

---

## 3. Environment and artifacts

One **workspace** `itm_factory_workspace` hosts the shared artifacts:

| Artifact | Type | Usage interface |
|----------|------|-----------------|
| `h` | `org.hypermedea.HypermedeaArtifact` | The bridge to the physical world and the KG. Agents `get`/`put`/`post` on Thing URIs (read/write property affordances, invoke action affordances) and crawl RDF into their belief base. Observable properties surface as `propertyValue(Name, Value)` beliefs; HTTP forms carry the basic-auth credentials. |
| `b` | `tools.LlmBridge` | Optional bridge to an LLM (used by the APAS agent, which focuses both `h` and `b`). |

**Why artifacts, not agents, for the Hypermedea bridge?** It is a non-autonomous,
function-oriented, stateful tool: it has no goals of its own, it just exposes
operations (`get`, `post`, …) and observable state to whichever agent uses it.
That is precisely the definition of an artifact.

### WoT mapping — Things as Artifacts *and* Agents

The Things themselves are reached **through** the Hypermedea artifact rather than
being modelled as one CArtAgO artifact each. Conceptually each Thing is a passive,
observable/controllable resource (artifact-like), but because every Thing carries
non-trivial control logic, emergencies and coordination duties, we wrap each one
in a dedicated **agent** that *uses* the artifact to reach it. So the mapping is:
**Thing = observable/controllable resource (artifact role) + one controlling agent.**

---

## 4. Organisation (Step 4)

A single **organisation** structures the agents as one production line. It is
specified in `src/org/org.xml` (Moise):

* **Structural** — a `production_line` group with one role per stage
  (`supplier`, `conveyor`, `filler`, `potter`, `packager`), all specialising an
  abstract `workshop_controller` role. Communication links encode who may
  request material from whom and which adjacent stages coordinate the item flow.
* **Functional** — a `produce_batch` scheme whose top goal `produce_pots`
  decomposes, in sequence, into `supply_material → convey_cups → fill_cups →
  pot_items → package_pots`, one mission per stage.
* **Normative** — each stage role is *obliged* to commit to its stage mission.

**Why an organisation on top of messaging?** Direct messages (orders/acks) already
give bilateral coordination, but an organisation makes the **global workflow and
the commitments explicit and enforceable**: it documents the expected line
formation, sequences the stage goals, and lets norms detect a stage that fails to
play its part. It is the right tool when coordination must be regulated globally
rather than negotiated pairwise.

Instantiating it (optional runtime wiring) means, in `mas.jcm`, creating the
organisation from `src/org/org.xml`, having each workshop agent adopt its stage
role and commit to the matching mission, and including
`common-moise.asl` in the workshop agents. This is left as an integration step so
it can be enabled deliberately against the shared simulation.

---

## 5. Coordination strategies used (summary)

* **In the agent** — each agent reasons on its own beliefs/goals (e.g. reorder
  when `tankLevel`/`packageBuffer`/clamp is low; emergency-stop on a red light).
* **Through the environment** — agents perceive each Thing's observable
  properties via the Hypermedea artifact and act on shared resources.
* **By direct interaction** — `order` / `orderPackages` request messages and
  `done(...)` acknowledgments between workshop agents and providers.
* **By organisation** — the `production_line` group + `produce_batch` scheme +
  obligations regulate the global process (Step 4, optional at runtime).
