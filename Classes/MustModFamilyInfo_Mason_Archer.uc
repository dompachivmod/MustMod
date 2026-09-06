class MustModFamilyInfo_Mason_Archer extends MustModFamilyInfo_Archer
	dependson(AOCPawn);

DefaultProperties
{
	FamilyID="Archer"
	Faction="Mason"
	FamilyFaction=EFAC_MASON

	// ParryBoxScale=(X=0.20,Y=0.17,Z=0.35)
    // ParryBoxTranslation=(X=10, Z=-28)

	NewPrimaryWeapons.empty;
	NewPrimaryWeapons(0)=(CWeapon=class'MustModWeapon_Shortbow',CForceTertiary=(class'AOCWeapon_ProjBodkin', class'AOCWeapon_ProjBroadhead'))
	NewPrimaryWeapons(1)=(CWeapon=class'MustModWeapon_Longbow',CForceTertiary=(class'AOCWeapon_ProjBodkin', class'AOCWeapon_ProjBroadhead'))
	NewPrimaryWeapons(2)=(CWeapon=class'MustModWeapon_Warbow',CForceTertiary=(class'AOCWeapon_ProjBodkin', class'AOCWeapon_ProjBroadhead'))
	NewPrimaryWeapons(3)=(CWeapon=class'MustModWeapon_ShortSpearMelee',CForceTertiary=(class'MustModWeapon_Buckler_Mason'))
	NewPrimaryWeapons(4)=(CWeapon=class'MustModWeapon_JavelinMelee',CForceTertiary=(class'MustModWeapon_Buckler_Mason'))
	NewPrimaryWeapons(5)=(CWeapon=class'MustModWeapon_HeavyJavelinMelee',CForceTertiary=(class'MustModWeapon_Buckler_Mason'))
	NewPrimaryWeapons(6)=(CWeapon=class'MustModWeapon_Spear',CorrespondingDuelProp=EDUEL_SpearUse)
	NewPrimaryWeapons(7)=(CWeapon=class'MustModWeapon_Brandistock',CorrespondingDuelProp=EDUEL_BrandistockUse)
	NewPrimaryWeapons(8)=(CWeapon=class'MustModWeapon_MasonFlag',CorrespondingDuelProp=EDUEL_SpearUse)
	NewPrimaryWeapons(9)=(CWeapon=class'MustModWeapon_SpikedMace',CorrespondingDuelProp=EDUEL_DagesseUse)
	NewPrimaryWeapons(10)=(CWeapon=class'MustModWeapon_BastardSword',CorrespondingDuelProp=EDUEL_LongswordUse)
	// NewPrimaryWeapons(11)=(CWeapon=class'MustModWeapon_DoubleBlade',CorrespondingDuelProp=EDUEL_HolyWaterSprinklerUse)
	// NewPrimaryWeapons(11)=(CWeapon=class'MustModWeapon_GrandLance')
	// NewPrimaryWeapons(10)=(CWeapon=class'MustModWeapon_SpikedMace',CorrespondingDuelProp=EDUEL_HolyWaterSprinklerUse)
	// NewPrimaryWeapons(11)=(CWeapon=class'MustModWeapon_Firebug')
	// NewPrimaryWeapons(12)=(CWeapon=class'MustModWeapon_BoStaff',CorrespondingDuelProp=EDUEL_BillUse)

	NewSecondaryWeapons.empty;
	NewSecondaryWeapons(0)=(CWeapon=class'MustModWeapon_Broadsword')
	NewSecondaryWeapons(1)=(CWeapon=class'MustModWeapon_NorseSword')
	NewSecondaryWeapons(2)=(CWeapon=class'MustModWeapon_Falchion',CorrespondingDuelProp=EDUEL_FalchionUse)
	NewSecondaryWeapons(3)=(CWeapon=class'AOCWeapon_Cudgel',CorrespondingDuelProp=EDUEL_CudgelUse)
	NewSecondaryWeapons(4)=(CWeapon=class'MustModWeapon_WarAxe',CorrespondingDuelProp=EDUEL_WarAxeUse)
	NewSecondaryWeapons(5)=(CWeapon=class'MustModWeapon_Dane',CorrespondingDuelProp=EDUEL_DaneUse)
	NewSecondaryWeapons(6)=(CWeapon=class'MustModWeapon_Mace',CorrespondingDuelProp=EDUEL_MaceUse)
	NewSecondaryWeapons(7)=(CWeapon=class'MustModWeapon_MorningStar',CorrespondingDuelProp=EDUEL_MorningStarUse)
	NewSecondaryWeapons(8)=(CWeapon=class'MustModWeapon_HolyWaterSprinkler',CorrespondingDuelProp=EDUEL_HolyWaterSprinklerUse)


	NewTertiaryWeapons.empty;
	NewTertiaryWeapons(0)=(CWeapon=class'AOCWeapon_ProjBodkin',bEnabledDefault=false)
	NewTertiaryWeapons(1)=(CWeapon=class'AOCWeapon_ProjBroadhead',bEnabledDefault=false)
	NewTertiaryWeapons(2)=(CWeapon=class'MustModWeapon_HuntingKnife',CorrespondingDuelProp=EDUEL_HuntingKnifeUse)
	NewTertiaryWeapons(3)=(CWeapon=class'MustModWeapon_Buckler_Mason',bEnabledDefault=false)
	


	ProjectileLocationModifiers(EHIT_Head) = 2.5
	ProjectileLocationModifiers(EHIT_Torso) = 2.0
	ProjectileLocationModifiers(EHIT_Arm) = 2.0
	ProjectileLocationModifiers(EHIT_Legs) = 1.75
	CrossbowLocationModifiers(EHIT_Head) = 2.5
	CrossbowLocationModifiers(EHIT_Torso) = 2.25
	CrossbowLocationModifiers(EHIT_Arm) = 2.25


	DamageResistances(EDMG_Swing) = 0.85
	DamageResistances(EDMG_Pierce) = 0.85
	DamageResistances(EDMG_Blunt) = 0.65

	AirSpeed=440.0
	WaterSpeed=220.0
	AirControl=0.35
	GroundSpeed=190.0
	AccelRate=500.0
	SprintAccelRate=100.0
	JumpZ=380.0
	SprintModifier=1.65
	SprintTime=10.0
	DodgeSpeed=400.0
	DodgeSpeedZ=200.0
	Health=100
	BACK_MODIFY=0.7
	STRAFE_MODIFY=0.85
	FORWARD_MODIFY=1.0
	CROUCH_MODIFY=0.65
	MaxSprintSpeedTime=3.5
	bCanDodge=true
	iKickCost=25
	iDodgeCost=40
	fComboAggressionBonus=1.0
	fBackstabModifier=1.0
	iMissMeleeStrikePenalty=10
	iMissMeleeStrikePenaltyBonus=0
	bCanSprintAttack=false
	fStandingSpread=0.05f
	fCrouchingSpread=0.0f
	fWalkingSpread=0.1
	fSprintingSpread=0.25
	fFallingSpread=0.25
	fSpreadPenaltyPerSecond=0.5
	fSpreadRecoveryPerSecond=0.3
	// SprintTurnSpeed=999999

}
