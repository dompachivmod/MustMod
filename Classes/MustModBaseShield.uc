/**
* MustMod Base Shield - Reverted to vanilla AOC behavior
*/

class MustModBaseShield extends AOCBaseShield;

DefaultProperties
{
	// MUSTMOD: Zero shield raise cost - shields are free to activate
	fShieldRaiseCost = 0.0
	// Small passive stamina drain while shield is held active
	fStaminaDrain = 1.0
}
