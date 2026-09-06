/**
 * Mason Assassin.
 *
 * Fifth class for Mason. Man-At-Arms stats and weapon selection, but with the
 * Archer's ninja-roll dodge. Extends MustModFamilyInfo_Archer so the roll config
 * (MustModRoll reads MustModFamilyInfo_Archer) applies; all stats and weapons are
 * then overridden to match the Man-At-Arms.
 *
 * ClassReference uses ECLASS_SiegeEngineer (enum index 4), which is the reserved
 * fifth class slot in AOCGRI.FamilyInfos (index 4 for Agatha, 9 for Mason).
 */
class MustModFamilyInfo_Mason_Assassin extends MustModFamilyInfo_Archer
	dependson(AOCPawn);

DefaultProperties
{
	FamilyID="Assassin"
	Faction="Mason"
	FamilyFaction=EFAC_MASON
	ClassName="Assassin"
	ClassReference=ECLASS_SiegeEngineer

	// Roll config (bUseCustomDodgeAnims, DodgeAnimUp*, iRollStaminaCost, etc.) is
	// inherited from MustModFamilyInfo_Archer and left untouched.

	// Man-At-Arms weapon selection (copied from MustModFamilyInfo_Mason_ManAtArms)
	NewPrimaryWeapons.empty;
	NewPrimaryWeapons(0)=(CWeapon=class'MustModWeapon_Broadsword')
	NewPrimaryWeapons(1)=(CWeapon=class'MustModWeapon_NorseSword')
	NewPrimaryWeapons(2)=(CWeapon=class'MustModWeapon_Falchion',CorrespondingDuelProp=EDUEL_FalchionUse)
	NewPrimaryWeapons(3)=(CWeapon=class'MustModWeapon_Hatchet',CorrespondingDuelProp=EDUEL_HatchetUse)
	NewPrimaryWeapons(4)=(CWeapon=class'MustModWeapon_WarAxe',CorrespondingDuelProp=EDUEL_WarAxeUse)
	NewPrimaryWeapons(5)=(CWeapon=class'MustModWeapon_Dane',CorrespondingDuelProp=EDUEL_DaneUse)
	NewPrimaryWeapons(6)=(CWeapon=class'MustModWeapon_Mace',CorrespondingDuelProp=EDUEL_MaceUse)
	NewPrimaryWeapons(7)=(CWeapon=class'MustModWeapon_MorningStar',CorrespondingDuelProp=EDUEL_MorningStarUse)
	NewPrimaryWeapons(8)=(CWeapon=class'MustModWeapon_HolyWaterSprinkler',CorrespondingDuelProp=EDUEL_HolyWaterSprinklerUse)
	NewPrimaryWeapons(9)=(CWeapon=class'MustModWeapon_QuarterStaff',CorrespondingDuelProp=EDUEL_QStaffUse)
	NewPrimaryWeapons(10)=(CWeapon=class'MustModWeapon_DualBucklers')
	NewPrimaryWeapons(11)=(CWeapon=class'MustModWeapon_Firebug')

	NewSecondaryWeapons.empty;
	NewSecondaryWeapons(0)=(CWeapon=class'MustModWeapon_Saber')
	NewSecondaryWeapons(1)=(CWeapon=class'MustModWeapon_Cudgel')
	NewSecondaryWeapons(2)=(CWeapon=class'MustModWeapon_Dagesse')

	NewTertiaryWeapons.empty;
	NewTertiaryWeapons(0)=(CWeapon=class'MustModWeapon_ThrowingKnife')
	NewTertiaryWeapons(1)=(CWeapon=class'MustModWeapon_ThrowingAxe')
	NewTertiaryWeapons(2)=(CWeapon=class'MustModWeapon_OilPot')
	NewTertiaryWeapons(3)=(CWeapon=class'MustModWeapon_Heater_Mason',bEnabledDefault=true)

	bCanDodge=true

	ProjectileLocationModifiers(EHIT_Head) = 1.5
	ProjectileLocationModifiers(EHIT_Torso) = 1
	ProjectileLocationModifiers(EHIT_Arm) = 1
	CrossbowLocationModifiers(EHIT_Head) = 2
	CrossbowLocationModifiers(EHIT_Torso) = 1
	CrossbowLocationModifiers(EHIT_Arm) = 1
	// damage modifiers
	DamageResistances(EDMG_Swing) = 0.8
	DamageResistances(EDMG_Pierce) = 0.85
	DamageResistances(EDMG_Blunt) = 0.65

	// Man-At-Arms movement/stats (override archer base where they differ)
	AirControl=0.5
	GroundSpeed=210.0
	SprintModifier=1.55
	BACK_MODIFY=0.7
	STRAFE_MODIFY=0.9
	FORWARD_MODIFY=1.0
	AccelRate=600.0
	iKickCost=20
	iDodgeCost=20
	PercentDamageToTake=0.9
	fShieldStaminaAbsorption=6
	MaxSprintSpeedTime=2.0
	// SprintTurnSpeed=999999
}
