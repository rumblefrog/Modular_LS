//#define BarricadeModel "models/props_coalmines/wood_fence_128.mdl" CANNOT BE ROTATED
#define BarricadeModel "models/props_lakeside/wood_crate_01.mdl"
#define MedicShieldModel "models/props_mvm/mvm_player_shield2.mdl"

#define MedicShieldSound "weapons/medi_shield_deploy.wav"
#define EMPSound "items/powerup_pickup_supernova.wav"

public void OnMapStart()
{
	PrecacheModel(BarricadeModel, true);
	PrecacheModel(MedicShieldModel, true);
	
	PrecacheSound(MedicShieldSound, true);
	PrecacheSound(EMPSound, true);
}