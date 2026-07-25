/*
All rules below translate RDF statements into shorter beliefs.

It is common to translate RDFS classes to unary predicates (such as 'thing') 
and RDFS properties to binary predicates (such as 'hasPropertyAffordance'). By
doing so, we may introduce name conflicts though. For instance,
- https://www.w3.org/2019/wot/td#Thing and
- http://www.w3.org/2002/07/owl#Thing
are quite different from each other. The latter is more general than the former.
That is why everything is a URI, in RDF.
*/
type(Individual, Class)
    :-
    rdf(
        Individual,
        "http://www.w3.org/1999/02/22-rdf-syntax-ns#type",
        Class
    ) .

system(Individual) :- type(Individual, "http://www.w3.org/ns/ssn/System") .
thing(Individual) :- type(Individual, "https://www.w3.org/2019/wot/td#Thing") .

automated_storage_and_retrieval_system(Individual)
    :-
    type(
        Individual,
        "http://www.productontology.org/id/Automated_storage_and_retrieval_system"
    ) .

type(Individual, automated_storage_and_retrieval_system)
    :-
    automated_storage_and_retrieval_system(Individual) .

conveyorSpeed(Individual)
    :-
    type(
        Individual,
        "https://ci.mines-stetienne.fr/kg/ontology#ConveyorSpeed"
    ) .

type(Individual, conveyorSpeed) :- conveyorSpeed(Individual) .

moveFromToAction(Individual)
    :-
    type(
        Individual,
        "https://ci.mines-stetienne.fr/kg/ontology#MoveFromToAction"
    ) .

type(Individual, moveFromToAction) :- moveFromToAction(Individual) .

hasSubSystem(Individual1, Individual2)
    :-
    rdf(Individual1, "http://www.w3.org/ns/ssn/hasSubSystem", Individual2) .

hasPropertyAffordance(Individual1, Individual2)
    :-
    rdf(
        Individual1,
        "https://www.w3.org/2019/wot/td#hasPropertyAffordance",
        Individual2
    ) .

hasActionAffordance(Individual1, Individual2)
    :-
    rdf(
        Individual1,
        "https://www.w3.org/2019/wot/td#hasActionAffordance",
        Individual2
    ) .

name(Individual1, Individual2)
    :-
    rdf(Individual1, "https://www.w3.org/2019/wot/td#name", Individual2) .
    
hasForm(Individual1, Individual2)
    :-
    rdf(Individual1, "https://www.w3.org/2019/wot/td#hasForm", Individual2) .

hasTarget(Individual1, Individual2)
    :-
    rdf(
        Individual1,
        "https://www.w3.org/2019/wot/hypermedia#hasTarget",
        Individual2
    ) .

/* *************************
   STEP 4: generic classes and coordinates, so that machines can be found
   and located without hard-coding their names.
**************************** */

// Step 4, example (a): "how much yogurt is in the silo", regardless of which
// machine or Thing API implements it -- any property affordance of type
// onto:LiquidVolume observes a tank/silo level.
liquidVolume(Individual)
    :-
    type(Individual, "https://ci.mines-stetienne.fr/kg/ontology#LiquidVolume") .

type(Individual, liquidVolume) :- liquidVolume(Individual) .

// pto:Filler_(packaging) is the generic class of "filling machine", instead
// of hard-coding the DX10's name.
filling_machine(Individual)
    :-
    type(Individual, "http://www.productontology.org/id/Filler_(packaging)") .

type(Individual, filling_machine) :- filling_machine(Individual) .

// Step 4, example (b): locate any robotic arm generically (instead of
// hard-coding "bosch-apas") and compute where it must move to reach the
// output area of a filling machine, wherever that machine is.
robotic_arm(Individual) :- type(Individual, "https://ci.mines-stetienne.fr/kg/ontology#Bosch-APAS") .
type(Individual, robotic_arm) :- robotic_arm(Individual) .

hasOriginCoordinates(Individual1, Individual2)
    :-
    rdf(Individual1, "https://ci.mines-stetienne.fr/kg/ontology#hasOriginCoordinates", Individual2) .

outputArea(Individual1, Individual2)
    :-
    rdf(Individual1, "https://ci.mines-stetienne.fr/kg/ontology#outputArea", Individual2) .

relativeCoordinates(Individual1, Individual2)
    :-
    rdf(Individual1, "https://ci.mines-stetienne.fr/kg/ontology#relativeCoordinates", Individual2) .

coordX(Individual, X) :- rdf(Individual, "https://ci.mines-stetienne.fr/kg/ontology#coordX", X) .
coordY(Individual, Y) :- rdf(Individual, "https://ci.mines-stetienne.fr/kg/ontology#coordY", Y) .
coordZ(Individual, Z) :- rdf(Individual, "https://ci.mines-stetienne.fr/kg/ontology#coordZ", Z) .

relativeTo(Individual1, Individual2)
    :-
    rdf(Individual1, "https://ci.mines-stetienne.fr/kg/ontology#relativeTo", Individual2) .

// The KG's entry point (https://ci.mines-stetienne.fr/kg/) is the one and
// only frame of reference all absolute coordinates are eventually given in.
factoryFrame("https://ci.mines-stetienne.fr/kg/itmfactory/itm#this") .

/*
Data quirk found by inspecting the KG: a machine's own coordinate frame is
identified by two different URIs depending on where it is referenced from,
e.g. "itmfactory/dx10#this" (the Thing/machine itself) and
"itmfactory/dx10/#this" (used as the value of onto:relativeTo in that same
machine's own areas). The documentation warns that this kind of mismatch in
relative origins can happen. Rather than assume this never occurs, we
normalize both forms to the same machine before resolving coordinates.
*/
sameOrigin(URI, URI) .
// explicit fixes for the "trailing slash" form of a machine's own URI, as
// observed in the vl10 and dx10 descriptions (onto:relativeTo points to
// ".../vl10/#this" resp. ".../dx10/#this" instead of ".../vl10#this" resp.
// ".../dx10#this", the URI used everywhere else for the same machine).
sameOrigin(
    "https://ci.mines-stetienne.fr/kg/itmfactory/vl10/#this",
    "https://ci.mines-stetienne.fr/kg/itmfactory/vl10#this"
) .
sameOrigin(
    "https://ci.mines-stetienne.fr/kg/itmfactory/dx10/#this",
    "https://ci.mines-stetienne.fr/kg/itmfactory/dx10#this"
) .

// Resolve any point's coordinates into the single factory frame of
// reference. Angles in this KG are all "0 deg" (no rotation between the
// factory and any machine currently in the production line), so the
// composition is a plain vector sum; a rotation matrix would be needed for
// the general case (see angleToXYPlane/xyAngle in the KG documentation).
absoluteCoordinates(Point, AX, AY, AZ)
    :-
    coordX(Point, X) & coordY(Point, Y) & coordZ(Point, Z)
    & relativeTo(Point, Ref)
    & factoryFrame(FactoryURI)
    & (
        Ref = FactoryURI
        & AX = X & AY = Y & AZ = Z
      |
        Ref \== FactoryURI
        & sameOrigin(Ref, Machine)
        & hasOriginCoordinates(Machine, Origin)
        & absoluteCoordinates(Origin, OX, OY, OZ)
        & AX = X + OX & AY = Y + OY & AZ = Z + OZ
      ) .