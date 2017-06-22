#pragma semicolon 1

#define PLUGIN_AUTHOR "Fishy"
#define PLUGIN_VERSION "1.0.0"

#include <sourcemod>
#include <Modular_LS>

#pragma newdecls required

#define BaseXP 3

public Plugin myinfo = 
{
	name = "MLS - XP On Player Kill",
	author = PLUGIN_AUTHOR,
	description = "MLS Module - Distributor - XP On Player Kill",
	version = PLUGIN_VERSION,
	url = "https://keybase.io/rumblefrog"
};

public void OnPluginStart()
{
	switch (GetEngineVersion())
	{
		case Engine_TF2, Engine_Left4Dead, Engine_Left4Dead2, Engine_CSGO, Engine_CSS, Engine_HL2DM, Engine_DODS, Engine_Insurgency, Engine_BlackMesa:
			PrintToServer("Game Successfully Detected");
		default:
			SetFailState("Game Engine Not Supported");
	}
	
	HookEvent("player_death", OnPlayerDeath, EventHookMode_Post);
}

public void OnPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int iVictim = event.GetInt("userid");
	int iAttacker = event.GetInt("attacker");
	
	if (iVictim == iAttacker)
		return;
		
	if (!IsValidClient(iVictim) || !IsValidClient(iAttacker))
		return;
		
	MLS_AddXP(iAttacker, BaseXP);
}