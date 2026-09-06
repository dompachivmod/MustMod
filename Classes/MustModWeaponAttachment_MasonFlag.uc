/**
* Copyright 2010-2012, Torn Banner Studios, All rights reserved
*
* Original Author: Michael Bao
*
* MustMod Weapon Attachment: Mason Flag
*/
class MustModWeaponAttachment_MasonFlag extends AOCWeaponAttachment_MasonFlag;

DefaultProperties
{
	// Override WeaponClass to point to MustMod version
	WeaponClass=class'MustModWeapon_MasonFlag'

	// Scale down by 30% (same pattern as SpikedMace scale-up)
	Begin Object Name=SkeletalMeshComponent0
		Scale=0.8
	End Object

	Begin Object Name=SkeletalMeshComponent2
		Scale=0.8
	End Object

	WeaponStaticMeshScale=0.8

	Skins(0)={(
		SkeletalMeshPath="chv_flags.WEP_M_Flag",
		StaticMeshPath="",
		MaterialPath="",
		StaticMeshScale=0.8,
		ImagePath="UI_CustWeaponImages_SWF.skin_bardiche_png"
		)};
}
