#pragma semicolon 1

#define PLUGIN_AUTHOR "Fishy"
#define PLUGIN_VERSION "1.0.0"

#include <sourcemod>
#include <Modular_LS>

#pragma newdecls required

#define Team_1 2 //Blue on TF2
#define Team_2 3 //Red on TF2

public Plugin myinfo = 
{
	name = "MLS - Switch Team",
	author = PLUGIN_AUTHOR,
	description = "MLS Module - Reward - Switch Team",
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
	
	RegConsoleCmd("sm_switchteam", CmdSwitchTeam, "Switches player to other team");
	
	RegAdminCmd("mls_switchteam_permission", CmdVoid, ADMFLAG_RESERVATION);
}

public Action CmdVoid(int iClient, int iArgs)
{
	return Plugin_Handled;
}

public Action CmdSwitchTeam(int client, int args)
{
	if (CheckCommandAccess(client, "mls_switchteam_permission", ADMFLAG_RESERVATION))
	{
		ChangeClientTeam(client, GetOtherTeam(client));
		return Plugin_Handled;
	}
		
	if (!IsAERank(client, 4, 15))
	{
		MLS_PrintToClient(client, "This ability unlocks at prestige 4 level 15");
		return Plugin_Handled;
	}
	
	ChangeClientTeam(client, GetOtherTeam(client));
	
	return Plugin_Handled;
}

int GetOtherTeam(int client)
{
	if (GetClientTeam(client) == Team_1)
		return Team_2;
	else
		return Team_1;
}
