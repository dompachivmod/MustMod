class MustModFamilyInfo_Mason_Knight extends AOCFamilyInfo_Mason_Knight;

DefaultProperties
{
	// ParryBoxScale=(X=0.20,Y=0.17,Z=0.35)
    // ParryBoxTranslation=(X=10, Z=-28)

	NewPrimaryWeapons.empty;
	NewPrimaryWeapons(0)=(CWeapon=class'MustModWeapon_DoubleAxe',CForceTertiary=(class'MustModWeapon_HuntingKnife', class'MustModWeapon_Kite_Agatha', class'MustModWeapon_TowerShield_Agatha'))
	NewPrimaryWeapons(1)=(CWeapon=class'MustModWeapon_PoleAxe',CForceTertiary=(class'MustModWeapon_HuntingKnife', class'MustModWeapon_Kite_Agatha', class'MustModWeapon_TowerShield_Agatha'))
	NewPrimaryWeapons(2)=(CWeapon=class'MustModWeapon_Bearded',CForceTertiary=(class'MustModWeapon_HuntingKnife', class'MustModWeapon_Kite_Agatha', class'MustModWeapon_TowerShield_Agatha'))
	NewPrimaryWeapons(3)=(CWeapon=class'MustModWeapon_WarHammer',CForceTertiary=(class'MustModWeapon_HuntingKnife', class'MustModWeapon_Kite_Agatha', class'MustModWeapon_TowerShield_Agatha'))
	NewPrimaryWeapons(4)=(CWeapon=class'MustModWeapon_Maul',CForceTertiary=(class'MustModWeapon_HuntingKnife', class'MustModWeapon_Kite_Agatha', class'MustModWeapon_TowerShield_Agatha'))
	NewPrimaryWeapons(5)=(CWeapon=class'MustModWeapon_GrandMace',CForceTertiary=(class'MustModWeapon_HuntingKnife', class'MustModWeapon_Kite_Agatha', class'MustModWeapon_TowerShield_Agatha'))
	NewPrimaryWeapons(6)=(CWeapon=class'MustModWeapon_Longsword',CForceTertiary=(class'MustModWeapon_HuntingKnife', class'MustModWeapon_Kite_Agatha', class'MustModWeapon_TowerShield_Agatha'))
	NewPrimaryWeapons(7)=(CWeapon=class'MustModWeapon_SwordOfWar',CForceTertiary=(class'MustModWeapon_HuntingKnife', class'MustModWeapon_Kite_Agatha', class'MustModWeapon_TowerShield_Agatha'))
	NewPrimaryWeapons(8)=(CWeapon=class'MustModWeapon_Messer',CForceTertiary=(class'MustModWeapon_HuntingKnife', class'MustModWeapon_Kite_Agatha', class'MustModWeapon_TowerShield_Agatha'))
	NewPrimaryWeapons(9)=(CWeapon=class'MustModWeapon_Katana',CForceTertiary=(class'MustModWeapon_HuntingKnife', class'MustModWeapon_Kite_Agatha', class'MustModWeapon_TowerShield_Agatha'))
	


	NewSecondaryWeapons.empty;
	NewSecondaryWeapons(0)=(CWeapon=class'MustModWeapon_HuntingKnife',CorrespondingDuelProp=EDUEL_HuntingKnifeUse)
	
	
	NewTertiaryWeapons.empty;
	NewTertiaryWeapons(0)=(CWeapon=class'MustModWeapon_HuntingKnife',CorrespondingDuelProp=EDUEL_HuntingKnifeUse)
	NewTertiaryWeapons(1)=(CWeapon=class'MustModWeapon_Kite_Agatha',bEnabledDefault=true)
	NewTertiaryWeapons(2)=(CWeapon=class'MustModWeapon_TowerShield_Agatha',bEnabledDefault=true)

	
	DamageResistances(EDMG_Swing) = 0.4
	DamageResistances(EDMG_Pierce) = 0.5
	DamageResistances(EDMG_Blunt) = 0.61

	ProjectileLocationModifiers(EHIT_Head) = 1.5
	ProjectileLocationModifiers(EHIT_Torso) = 1
	ProjectileLocationModifiers(EHIT_Arm) = 1


	CrossbowLocationModifiers(EHIT_Head) = 2
	CrossbowLocationModifiers(EHIT_Torso) = 1.2
	CrossbowLocationModifiers(EHIT_Arm) = 1.2

	MaxSprintSpeedTime=4.0
	SprintModifier=1.7
	BACK_MODIFY=0.7
	// SprintTurnSpeed=999999

}
