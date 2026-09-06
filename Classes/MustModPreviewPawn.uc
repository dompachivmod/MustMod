/**
* Copyright 2015, Torn Banner Studios, All rights reserved
*
* A pawn that's used in Customization, etc.
*/
class MustModPreviewPawn extends MustModPawn;

simulated event FellOutOfWorld(class<DamageType> dmgType)
{
	
}

simulated event Tick( float DeltaTime )
{
	super(UTPawn).Tick(DeltaTime);
}