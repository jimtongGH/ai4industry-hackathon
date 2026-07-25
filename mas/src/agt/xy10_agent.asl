/* 
xy10_agent controlling the Packaging Workshop 
It acts on a thing described by: https://ci.mines-stetienne.fr/kg/itmfactory/xy10
It has:
- the following action affordances:
-- pressEmergencyStop
- the following property affordances
-- stackLightStatus
-- conveyorSpeed
-- packageBuffer
-- opticalSensorPackage
-- opticalSensorContainer1
-- opticalSensorContainer2
-- conveyorHeadStatus

@author Olivier Boissier (Mines Saint-Etienne)
*/

/* Initial beliefs and rules */

thing(packagingWorkshop,Thing) :-
    thing(Thing)
    // TODO include signature from the Product Ontology
    & rdf(Thing, "http://www.w3.org/1999/02/22-rdf-syntax-ns#type", "http://www.w3.org/ns/sosa/Platform" )
    & rdf(Thing, "http://www.w3.org/1999/02/22-rdf-syntax-ns#type", "http://www.productontology.org/id/Packaging_machinery")
    & has_action_affordance(Thing, PressEmergencyStop)
    & stop_in_emergency_action(PressEmergencyStop)
    & has_property_affordance(Thing,OpticalSensorContainer2)
    & optical_sensor_status(OpticalSensorContainer2)
    & name(OpticalSensorContainer2,"opticalSensorContainer2")
    & has_property_affordance(Thing,StackLightStatus)
    & stack_light_status(StackLightStatus)
    & has_property_affordance(Thing,PackageBuffer)
    & count(PackageBuffer)
    & has_property_affordance(Thing,ConveyorHeadStatus)
    & optical_sensor_status(ConveyorHeadStatus)
    & name(ConveyorHeadStatus,"conveyorHeadStatus")
    & has_property_affordance(Thing,ConveyorSpeed)
    & conveyor_speed(ConveyorSpeed)
    & has_property_affordance(Thing,OpticalSensorContainer1)
    & optical_sensor_status(OpticalSensorContainer1)
    & name(OpticalSensorContainer1,"opticalSensorContainer1")
    & has_property_affordance(Thing,OpticalSensorPackage)
    & optical_sensor_status(OpticalSensorPackage)
    & name(OpticalSensorPackage,"opticalSensorPackage")
  .


/* Initial goals */

/* Plans */

+!start :
    name(Name)
    <-
    .println("Belief base is under initialization");
    !!run(Name);
  .

+!run(Name) : thing(Name,Thing) <-
    .print("Found suitable Packaging : ", Thing) ;

    ?locationOfInputMaterial(Name,CIX,CIY,CIZ);
    ?locationOfOutputProduct(Name,COX,COY,COZ);
    !getDescription(Name);
    !testStatus(Name);

    // Not necessary to get all of them regularly. 
    // Choose and comment, otherwise there is a risk of
    // consuming all the computing resources
    !observeStackLightStatus(Name);
    !observeConveyorSpeed(Name); 
    !observePackageBuffer(Name);
    !observeOpticalSensorPackage(Name);
    !observeOpticalSensorContainer1(Name);
    !observeOpticalSensorContainer2(Name);
    !observeConveyorHeadStatus(Name);

    ?conveyorSpeed(Name,IS);
    if (IS == 0) {
      !changeConveyorSpeed(Name,IS+0.5);
    }
    !packageItems(Name);

    !testStatus(Name);
  .

+!run(Name) : 
    true 
    <- 
    .wait(100); 
    !!run(Name);
  .

// The packaging workshop wraps incoming containers automatically. The agent
// monitors the process: it keeps the conveyor running and, when the stock of
// packages runs low, orders more from the provider agent (Step 4).
+!packageItems(Name) :
    thing(Name,Thing)
    <-
    ?packageBuffer(Name,Buffer);
    ?conveyorSpeed(Name,Speed);
    if (Speed == 0) {
      !changeConveyorSpeed(Name,0.5);
    };
    if (Buffer <= 2) {
      !orderPackages(Name);
    };
    .wait(4000);
    !!packageItems(Name);
  .

// Order more packages from the provider agent.
+!orderPackages(Name) :
    provider(Provider)
    <-
    .println("package buffer is low -> ordering packages from ",Provider);
    .send(Provider, achieve, orderPackages(5));
  .

-!orderPackages(Name) : true
    <-
    .println("no package provider configured; cannot reorder packages.");
  .

// Acknowledge the provider's delivery confirmation (Step 4 coordination).
+done(orderPackages)[source(Sender)] :
    true
    <-
    .println("received package delivery acknowledgment from ",Sender);
  .

// Handling emergency cases (mirrors the storage-rack agent).
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

// Organisational stage hook: as `packager` in the production_line group, this
// agent is obliged to the package_pots goal. Packaging is monitored
// continuously from the `start` goal, so this goal reports the stage is online.
+!package_pots : true
    <-
    .print("[org] packaging stage online.");
  .

{ include("inc/xy10_skills.asl") }
{ include("inc/common.asl") }
{ include("inc/owl-signature.asl") }

{ include("$jacamoJar/templates/common-cartago.asl") }
{ include("$jacamoJar/templates/common-moise.asl") }
