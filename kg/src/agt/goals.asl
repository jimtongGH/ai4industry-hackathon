+!crawl(URI)
    <-
    get(URI) ;
    +crawled(URI) ;
    for (system(S) & hasSubSystem(S, SS)) {
        h.target(SS, TargetURI) ;
        if (not crawled(TargetURI) & not .intend(crawl(TargetURI))) {
            !crawl(TargetURI)
        }
    } .

-!crawl(URI)
    <-
    .print("Couldn't crawl ", URI, ". Giving up.") ;
    +crawled(URI) .

+!listThings <- .print("Things:") ; for (thing(T)) { .print("* ", T) } .

+!listPropertyAffordances(TType)
    <-
    .print("Property affordances:") ; 
    for (type(T, TType) & hasPropertyAffordance(T, Af) & name(Af, P)) {
        .print("* ", P)
    } .

+!readProperty(TType, PType)
    : type(T, TType)
    & hasPropertyAffordance(T, Af)
    & type(Af, PType)
    & name(Af, P)
    & hasForm(Af, F)
    & hasTarget(F, URI)
    <-
    !prepareForm(Fp) ;
    get(URI, Fp) ;
    ?(json(Val)[source(URI)]) ;
    .print(P, " = ", Val) .

+!writeProperty(TType, PType, Val)
    : type(T, TType)
    & hasPropertyAffordance(T, Af)
    & type(Af, PType)
    & hasForm(Af, F)
    & hasTarget(F, URI)
    <-
    !prepareForm(Fp) ;
    put(URI, [json(Val)], Fp) .

+!invokeAction(TType, AType, In)
    : type(T, TType)
    & hasActionAffordance(T, Af)
    & type(Af, AType)
    & hasForm(Af, F)
    & hasTarget(F, URI)
    <-
    !prepareForm(Fp) ;
    post(URI, [json(In)], Fp) .

+!prepareForm(F) : credentials(User, Pw)
    <-
    h.basic_auth_credentials(User, Pw, H) ;
    F = [kv("urn:hypermedea:http:authorization", H)] .

/*
Step 4: find, without knowing its name, a robotic arm able to reach the
output area of a machine of type MType, and compute the coordinates it must
move to, relative to itself, to reach that output area -- wherever the
machine and the robot happen to be located in the factory.
*/
+!locateOutputOf(MType)
    : type(M, MType) & outputArea(M, Area) & relativeCoordinates(Area, C)
    & absoluteCoordinates(C, AX, AY, AZ)
    <-
    .print("Absolute coordinates of the output area of ", M, ": (", AX, ", ", AY, ", ", AZ, ")") ;
    for ( robotic_arm(R) & hasOriginCoordinates(R, RO) & absoluteCoordinates(RO, RX, RY, RZ) ) {
        .print(
            R, " must move to (", AX - RX, ", ", AY - RY, ", ", AZ - RZ,
            ") relative to itself to reach that output area"
        )
    } .