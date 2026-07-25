/* 
vl10_agent controlling the Storage rack 
It acts on a thing described by: https://ci.mines-stetienne.fr/kg/itmfactory/vl10
It has:
- the following action affordances:
-- pressEmergencyStop
-- pickItem
- the following property affordances
-- positionX
-- capacity
-- positionZ
-- conveyorSpeed
-- clampStatus
-- stackLightStatus

@author Olivier Boissier (Mines Saint-Etienne)
*/

/* Initial beliefs and rules */
position(0,0). // X,Z cell in the storageRack

thing(storageRack,Thing) :-
    thing(Thing)
    & platform(Thing)
    & rdf(Thing, "http://www.w3.org/1999/02/22-rdf-syntax-ns#type", "http://www.productontology.org/id/Automated_storage_and_retrieval_system")
    & has_action_affordance(Thing, PressEmergencyStop)
    & stop_in_emergency_action(PressEmergencyStop)
    & has_action_affordance(Thing, PickItem)
    & move_from_to_action(PickItem)
    & has_property_affordance(Thing, PositionX)
    & x_coordinate(PositionX)
    & has_property_affordance(Thing, PositionZ)
    & z_coordinate(PositionZ)
    & has_property_affordance(Thing, Capacity)
    & maximum_count(Capacity)
    & has_property_affordance(Thing, ConveyorSpeed)
    & conveyor_speed(ConveyorSpeed)
    & has_property_affordance(Thing,ClampStatus)
    & boolean_schema(ClampStatus)
    & name(ClampStatus,"clampStatus")
    & has_property_affordance(Thing,StackLightStatus)
    & name(StackLightStatus,"stackLightStatus")
  .

/* Initial goals */

/* Plans */

+!start :
    name(Name) <-
    .println("Belief base is under initialization");
    !!run(Name);
  .

+!run(Name) : thing(Name,Thing) <-
    .print("Found suitable storage rack: ", Thing) ;
     // set credentials to access the Thing (DX10 workshop of the IT'm factory)

    ?locationOfOutputProduct(Name,COX,COY,COZ);
    !getDescription(Name);
    !testStatus(Name);

    !observeStackLightStatus(Name);

    ?conveyorSpeed(Name,IS);
    if (IS == 0) {
      !changeConveyorSpeed(Name,IS+0.5);
    }
    !conveyItems(Name);
  .

+!run(Name) :
    true
    <-
    .wait(100);
    !!run(Name).

// Feed the line: walk the storage rack cell by cell, picking each stored
// item and placing it on the conveyor belt. pickItem's input is the [X,Z]
// cell of the item (per the TD, e.g. [0,0] is the first item).
// position(X,Z) tracks the current cell; capacity gives the [Rmax,Cmax] grid.
+!conveyItems(Name) :
    thing(Name,Thing)
    & position(X,Z)
    <-
    // The storage rack is a fixed 5x5 grid (capacity property reads [5,5]).
    // We use the fixed hardware dimensions directly rather than reading the
    // capacity property, whose JSON-array value does not round-trip cleanly
    // through the Hypermedea json/1 belief.
    if (X < 5 & Z < 5) {
      .println("conveying: picking item at storage cell [",X,",",Z,"]");
      !pickItem(Name,[X,Z]);
      .wait(3000);              // let the pick-and-place complete (clamp reopens)
      !nextCell(X,Z,5);
      !!conveyItems(Name);
    } else {
      .println("storage rack emptied. Requesting a refill from the cup provider.");
      !refillRack(Name);
      !!conveyItems(Name);
    }
  .

// Advance the current cell: move along Z, wrap to the next X row.
+!nextCell(X,Z,Cmax) : Z + 1 < Cmax
    <- -+position(X, Z + 1); .
+!nextCell(X,Z,Cmax) : Z + 1 >= Cmax
    <- -+position(X + 1, 0); .

// Refill the rack by ordering cups from the provider, then restart at [0,0].
+!refillRack(Name) :
    provider(Provider)
    <-
    .send(Provider, achieve, order(25));
    .println("ordered 25 cups from ",Provider,"; waiting for delivery.");
    .wait(5000);
    -+position(0,0);
  .

-!refillRack(Name) : true
    <-
    .println("no cup provider configured; cannot refill the rack.");
  .

+done(order)[source(Sender)] :
    true
    <-
    .print("received the acknowledgment from ",Sender);
  .

// Handling emergency cases
// reinitialize the conveyor speed to the initial value when light is green
// press emergency stop when light is red
// both plans supersede the corresponding plans provided in the included file
+propertyValue("stackLightStatus", "green")[artifact_name(_,Name)] :
    thing(Name,Thing)
    & initialSpeed(S)
    <-
    .println("********** stackLightStatus is now green. Reinitialization of the speed.");
    !changeConveyorSpeed(Name,S);
  .

+propertyValue("stackLightStatus", "red")[artifact_name(_,Name)] :
    thing(Name,Thing)
    <-
    .println("********** stackLightStatus is now red. Pressing emergency stop.");
    !pressEmergencyStop(Name);
  .

// Organisational stage hook: as `conveyor` in the production_line group, this
// agent is obliged to the convey_cups goal. Conveying runs continuously from
// the `start` goal, so this goal reports that the stage is online.
+!convey_cups : true
    <-
    .print("[org] conveying stage online.");
  .

{ include("inc/vl10_skills.asl") }
{ include("inc/owl-signature.asl") }
{ include("inc/common.asl") }

{ include("$jacamoJar/templates/common-cartago.asl") }
{ include("$jacamoJar/templates/common-moise.asl") }
