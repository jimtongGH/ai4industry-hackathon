/* 
apas_agent controlling the Robot Arm. 
It acts on a thing described by: https://ci.mines-stetienne.fr/kg/itmfactory/bosch-apas#this
It has:
- the following action affordances:
-- grasp
-- moveTo
-- release
- the following property affordances:
-- inMovement
-- grasping

@author Olivier Boissier (Mines Saint-Etienne)
*/


/* Initial beliefs and rules */

td_name(boschApas). // boch-apas

nb(0). // number of pick-and-place iterations already performed

thing(boschApas,Thing) :-
      thing(Thing)
      & bosch_apas(Thing)
      & has_action_affordance(Thing, MoveAction)
      & move_from_to_action(MoveAction)
      & has_action_affordance(Thing, GraspAction)
      & grasp_action(GraspAction)
      & has_action_affordance(Thing, ReleaseAction)
      & release_action(ReleaseAction)
      & has_property_affordance(Thing, InMovement)
      & activity_status(InMovement)
      & name(InMovement,"inMovement")
      & has_property_affordance(Thing, Grasping)
      & activity_status(Grasping)
      & name(Grasping,"grasping")
  .

+!start :
    name(Name)
    <-
    .print("Belief base is under initialization");
    !!run(Name);
  .

+!run(Name) : 
    thing(Name,Thing) 
    <-
    .print("Found suitable RobotArm : ", Thing) ;

    ?has_origin_coordinates(Name,CX,CY,CZ);
    .println(Thing, " has origin coordinates ",CX," ",CY," ",CZ);

    !getDescription(Name);

    // Part IV (Agentic AI): instead of executing the transfer with Jason plans
    // (!potItems / !carry below), delegate the carry goal to the LLM-based agent.
    // The goal is passed as a single string to the solve(Goal) operation of the
    // LlmBridge artifact (focused as `b`). The LLM agent discovers affordances,
    // plans a Behavior Tree and executes it against the simulation; the outcome
    // is published on the artifact's `llmResult` observable property.
    !delegateCarry(Name);
  .

+!run(Name) :
    true
    <-
    .wait(100);
    !!run(Name);
  .

// Delegate the carry goal to the LLM-based agent via the LlmBridge artifact.
// The goal string uses !carry(RobotType, InputConveyor, OutputConveyor):
// APAS carries pots from the filling workshop output (DX10_output) to the
// packaging workshop input (XY10_input).
+!delegateCarry(Name)
    <-
    Goal = "!carry(\"APAS\", \"DX10_output\", \"XY10_input\")";
    .print("Delegating carry goal to the LLM-based agent: ", Goal);
    solve(Goal);
  .

// React to the plan/outcome published by the LLM bridge on the llmResult property.
+llmResult(Result) :
    Result \== "" & Result \== "FAILURE" & Result \== "TIMEOUT"
    <-
    .print("LLM-based agent returned a Behavior Tree plan / result: ", Result);
  .

+llmResult(Result) :
    Result == "FAILURE" | Result == "TIMEOUT"
    <-
    .print("LLM-based agent could not solve the carry goal: ", Result);
  .

// Pick a pot at the conveyor and place it at the packaging workshop.
// Bounded to 3 iterations (like leubot_agent), then reset the arm.
+!potItems(Name) :
    nb(X)
    & X < 3
    & location_conveyor(Lc)
    & location_packaging(Lp)
    <-
    .println("iteration ",X,": potting an item from conveyor to packaging");
    !carry(Name,Lc,Lp);
    -+nb(X+1);
    !!potItems(Name);
  .

+!potItems(Name) : true
    <-
    .wait(2000);
    !reset(Name);
  .

// Real carry plan: move to the source, grasp, move to the target, release.
// move/grasp/release/reset are provided by inc/robot_arm_skills.asl.
+!carry(Name,From,To) :
    true
    <-
    .println("carrying a pot from ",From," to ",To);
    !move(Name,From);
    .wait(1000);
    !grasp(Name,From);
    .wait(1000);
    !move(Name,To);
    .wait(1000);
    !release(Name,To);
  .

// Organisational stage hook: as `potter` in the production_line group, this
// agent is obliged to the pot_items goal. Potting runs continuously from the
// `start` goal, so this goal reports that the stage is online.
+!pot_items : true
    <-
    .print("[org] potting stage online.");
  .

{ include("inc/robot_arm_skills.asl") }
{ include("inc/common.asl") }
{ include("inc/owl-signature.asl") }

{ include("$jacamoJar/templates/common-cartago.asl") }
{ include("$jacamoJar/templates/common-moise.asl") }
