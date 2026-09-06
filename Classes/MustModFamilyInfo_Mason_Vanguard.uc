class MustModFamilyInfo_Mason_Vanguard extends AOCFamilyInfo_Mason_Vanguard;

DefaultProperties
{
	// ParryBoxScale=(X=0.20,Y=0.17,Z=0.35)
    // ParryBoxTranslation=(X=10, Z=-28)

	NewPrimaryWeapons.empty;
	NewPrimaryWeapons(0)=(CWeapon=class'MustModWeapon_Greatsword',CorrespondingDuelProp=EDUEL_GreatswordUse)
	NewPrimaryWeapons(1)=(CWeapon=class'MustModWeapon_Claymore',CorrespondingDuelProp=EDUEL_ClaymoreUse)
	NewPrimaryWeapons(2)=(CWeapon=class'MustModWeapon_Zweihander',CorrespondingDuelProp=EDUEL_ZweihanderUse)
	NewPrimaryWeapons(3)=(CWeapon=class'MustModWeapon_Bardiche',CorrespondingDuelProp=EDUEL_BardicheUse)
	NewPrimaryWeapons(4)=(CWeapon=class'MustModWeapon_Bill',CorrespondingDuelProp=EDUEL_BillUse)
	NewPrimaryWeapons(5)=(CWeapon=class'MustModWeapon_Halberd',CorrespondingDuelProp=EDUEL_HalberdUse)
	NewPrimaryWeapons(6)=(CWeapon=class'MustModWeapon_PoleHammer',CorrespondingDuelProp=EDUEL_PoleHammerUse)
	NewPrimaryWeapons(7)=(CWeapon=class'MustModWeapon_Nodachi',CorrespondingDuelProp=EDUEL_ZweihanderUse)
	NewPrimaryWeapons(8)=(CWeapon=class'MustModWeapon_DoubleBlade',CorrespondingDuelProp=EDUEL_HolyWaterSprinklerUse)
	NewPrimaryWeapons(9)=(CWeapon=class'MustModWeapon_Fork',CorrespondingDuelProp=EDUEL_ForkUse)
	

	NewSecondaryWeapons.empty;
	NewSecondaryWeapons(0)=(CWeapon=class'MustModWeapon_Saber')
	NewSecondaryWeapons(1)=(CWeapon=class'MustModWeapon_Cudgel')
	NewSecondaryWeapons(3)=(CWeapon=class'MustModWeapon_WarAxe')
	NewSecondaryWeapons(4)=(CWeapon=class'MustModWeapon_Dane')
	NewSecondaryWeapons(5)=(CWeapon=class'MustModWeapon_Falchion')
	NewSecondaryWeapons(6)=(CWeapon=class'MustModWeapon_Dagesse')


	NewTertiaryWeapons.empty;
	NewTertiaryWeapons(0)=(CWeapon=class'MustModWeapon_HuntingKnife',CorrespondingDuelProp=EDUEL_HuntingKnifeUse)
	NewTertiaryWeapons(1)=(CWeapon=class'MustModWeapon_Buckler_Mason',bEnabledDefault=false)

	DamageResistances(EDMG_Swing) = 0.6
	DamageResistances(EDMG_Pierce) = 0.8
	DamageResistances(EDMG_Blunt) = 0.7



	bCanSprintAttack=false

	ProjectileLocationModifiers(EHIT_Head) = 1.5
	ProjectileLocationModifiers(EHIT_Torso) = 1
	ProjectileLocationModifiers(EHIT_Arm) = 1
	CrossbowLocationModifiers(EHIT_Head) = 2
	CrossbowLocationModifiers(EHIT_Torso) = 1
	CrossbowLocationModifiers(EHIT_Arm) = 1

	MaxSprintSpeedTime=3.5
	SprintModifier=1.64
	BACK_MODIFY=0.7
	// SprintTurnSpeed=999999
}
