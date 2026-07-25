/* 
dx10_agent controlling the Filling Workshop. 
It acts on a thing described by: https://ci.mines-stetienne.fr/kg/itmfactory/dx10
It has:
- the following action affordances:
-- pressEmergencyStop
- the following property affordances:
-- stackLightStatus
-- conveyorSpeed
-- positionX
-- tankLevel
-- magneticValveStatus
-- opticalSensorStatus
-- conveyorHeadStatus

@author Olivier Boissier (Mines Saint-Etienne)
*/

/* Initial beliefs and rules */

thing(fillingWorkshop,Thing) :-
    thing(Thing)
    // TODO include signature from the Product Ontology
    & rdf(Thing, "http://www.w3.org/1999/02/22-rdf-syntax-ns#type", "http://www.productontology.org/id/Filler_(packaging)")
    & has_action_affordance(Thing, PressEmergencyStop)
    & stop_in_emergency_action(PressEmergencyStop)
    & has_property_affordance(Thing,StackLightStatus)
    & stack_light_status(StackLightStatus)
    & has_property_affordance(Thing, PositionX)
    & x_coordinate(PositionX)
    & has_property_affordance(Thing,TankLevel)
    & liquid_volume(TankLevel)
    & has_property_affordance(Thing, ConveyorSpeed)
    & conveyor_speed(ConveyorSpeed)
    & has_property_affordance(Thing,OpticalSensorStatus)
    & optical_sensor_status(OpticalSensorStatus)
    & name(OpticalSensorStatus, "opticalSensorStatus")
    & has_property_affordance(Thing,ConveyorHeadStatus)
    & optical_sensor_status(ConveyorHeadStatus)
    & name(ConveyorHeadStatus,"conveyorHeadStatus")
    & has_property_affordance(Thing, MagneticValveStatus)
    & valve_status(MagneticValveStatus)
  .

/* Initial goals */

/* Plans */

+!start :
    name(Name)
    <-
    .println("Belief base is under initialization");
    !!run(Name);
  .

+!run(Name) :
    thing(Name,Thing)
    <-
    .print("Found suitable filling workshop: ", Thing) ;
    //  ?locationOfInputMaterial(Name,CIX,CIY,CIZ);
    //  ?locationOfOutputProduct(Name,COX,COY,COZ);
    !getDescription(Name);
    !testStatus(Name);
    
    // Not necessary to get all of them regularly. 
    // Choose and comment, otherwise there is a risk of
    // consuming all the computing resources
    !observeTankLevel(Name);
    !observeConveyorSpeed(Name);
    !observeConveyorHeadStatus(Name);
    !observeOpticalSensorStatus(Name);
    !observeMagneticValveStatus(Name);
    !observePositionX(Name);
    !observeStackLightStatus(Name);
    
    ?conveyorSpeed(Name,IS);
    if (IS == 0) {
      !changeConveyorSpeed(Name,0.5);
    }
    
    !fillItems(Name);

    !testStatus(Name);
  .

+!run(Name) :
    true
    <-
    .wait(100);
    !!run(Name).

// The filler works automatically: the optical sensor at the start of the belt
// triggers the magnetic valve to pour product into each passing cup. The agent
// therefore monitors the process: it keeps the conveyor running and, when the
// tank runs low, orders more dairy product from the provider (Step 4).
+!fillItems(Name) :
    thing(Name,Thing)
    <-
    ?tankLevel(Name,Level);
    ?conveyorSpeed(Name,Speed);
    if (Speed == 0) {
      !changeConveyorSpeed(Name,0.5);
    };
    if (Level <= 1) {
      !orderDairy(Name);
    };
    .wait(4000);
    !!fillItems(Name);
  .

// Order more dairy product from the provider agent.
+!orderDairy(Name) :
    provider(Provider)
    <-
    .println("tank is low -> ordering dairy product from ",Provider);
    .send(Provider, achieve, order(2));
  .

-!orderDairy(Name) : true
    <-
    .println("no dairy provider configured; cannot reorder product.");
  .

// Acknowledge the provider's delivery confirmation (Step 4 coordination).
+done(order)[source(Sender)] :
    true
    <-
    .println("received dairy delivery acknowledgment from ",Sender);
  .

// Handling emergency cases (mirrors the storage-rack agent):
// press emergency stop when the stack light turns red,
// reinitialize the conveyor speed when it turns green again.
+propertyValue("stackLightStatus", "red")[artifact_name(_,Name)] :
    thing(Name,Thing)
    <-
    .println("********** stackLightStatus is now red. Pressing emergency stop.");
    !pressEmergencyStop(Name);
  .

+propertyValue("stackLightStatus", "green")[artifact_name(_,Name)] :
    thing(Name,Thing)
    & initialSpeed(S)
    <-
    .println("********** stackLightStatus is now green. Reinitialization of the speed.");
    !changeConveyorSpeed(Name,S);
  .

// Organisational stage hook: as `filler` in the production_line group, this
// agent is obliged to the fill_cups goal. Filling is monitored continuously
// from the `start` goal, so this goal reports that the stage is online.
+!fill_cups : true
    <-
    .print("[org] filling stage online.");
  .

{ include("inc/dx10_skills.asl") }
{ include("inc/common.asl") }
{ include("inc/owl-signature.asl") }

{ include("$jacamoJar/templates/common-cartago.asl") }
{ include("$jacamoJar/templates/common-moise.asl") }
