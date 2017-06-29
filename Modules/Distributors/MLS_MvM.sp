#pragma semicolon 1

#define PLUGIN_AUTHOR "Fishy"
#define PLUGIN_VERSION "1.0.0"

#include <sourcemod>
#include <Modular_LS>

#pragma newdecls required

#define TankXP 30
#define BusterXP 9
#define CreditBonusXP 6
#define MarkedDeathXP 2
#define PowerupSharedXP 6
#define HeadShotXP 2
#define BombResetXP 6
#define ZeroGatesXP 6

public Plugin myinfo = 
{
	name = "MLS - MvM Event Credits",
	author = PLUGIN_AUTHOR,
	description = "MLS Module - Distributor - MvM Event Credits",
	version = PLUGIN_VERSION,
	url = "https://keybase.io/rumblefrog"
};

public void OnPluginStart()
{
	if (GetEngineVersion() == Engine_TF2)
		PrintToServer("Game Successfully Detected");
	else
		SetFailState("Game Not Supported");
		
	HookEvent("mvm_tank_destroyed_by_players", TankDestroyed, EventHookMode_Post);
	HookEvent("mvm_sentrybuster_killed", BusterKilled, EventHookMode_Post);
	HookEvent("mvm_creditbonus_all_advanced", CreditBonus, EventHookMode_Post);
	HookEvent("mvm_scout_marked_for_death", MarkedDeath, EventHookMode_Post);
	HookEvent("mvm_medic_powerup_shared", PowerupShared, EventHookMode_Post);
	HookEvent("mvm_sniper_headshot_currency", HeadShot, EventHookMode_Post);
	HookEvent("mvm_bomb_reset_by_player", BombReset, EventHookMode_Post);
	HookEvent("mvm_adv_wave_complete_no_gates", ZeroGates, EventHookMode_Post);
}

public void TankDestroyed(Event event, const char[] name, bool dontBroadcast)
{
	MLS_AddXPToAll(TankXP);
}

public void BusterKilled(Event event, const char[] name, bool dontBroadcast)
{
	MLS_AddXPToAll(BusterXP);
}

public void CreditBonus(Event event, const char[] name, bool dontBroadcast)
{
	MLS_AddXPToAll(CreditBonusXP);
}

public void MarkedDeath(Event event, const char[] name, bool dontBroadcast)
{
	MLS_AddXPToAll(MarkedDeathXP);
}

public void PowerupShared(Event event, const char[] name, bool dontBroadcast)
{
	MLS_AddXPToAll(PowerupSharedXP);
}

public void HeadShot(Event event, const char[] name, bool dontBroadcast)
{
	MLS_AddXPToAll(HeadShotXP);
}

public void BombReset(Event event, const char[] name, bool dontBroadcast)
{
	MLS_AddXPToAll(BombResetXP);
}

public void ZeroGates(Event event, const char[] name, bool dontBroadcast)
{
	MLS_AddXPToAll(ZeroGatesXP);
}


