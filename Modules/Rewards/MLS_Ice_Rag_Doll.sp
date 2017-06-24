#pragma semicolon 1

#define PLUGIN_AUTHOR "Fishy"
#define PLUGIN_VERSION "1.0.0"

#include <sourcemod>
#include <Modular_LS>
#include <tf2_stocks>

#pragma newdecls required

public Plugin myinfo = 
{
	name = "MLS - Ice Ragdoll On Kill",
	author = PLUGIN_AUTHOR,
	description = "MLS Module - Reward - Ice Ragdoll On Kill",
	version = PLUGIN_VERSION,
	url = "https://keybase.io/rumblefrog"
};

public void OnPluginStart()
{
	if (GetEngineVersion() == Engine_TF2)
		PrintToServer("Game Successfully Detected");
	else
		SetFailState("Game Not Supported");
		
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);
	
	RegAdminCmd("mls_ird_permission", CmdVoid, ADMFLAG_RESERVATION);
}

public Action CmdVoid(int iClient, int iArgs)
{
	return Plugin_Handled;
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int iVictim = GetClientOfUserId(GetEventInt(event, "userid"));
	int iAttacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	
	if (iVictim == iAttacker)
		return;
		
	if (!IsValidClient(iVictim) || !IsValidClient(iAttacker))
		return;
	
	if (CheckCommandAccess(iAttacker, "mls_ird_permission", ADMFLAG_RESERVATION))
		return;
		
	if (MLS_GetUserLevel(iAttacker) < 15)
		return;
	
	int iVteam = GetClientTeam(iVictim);
	int iVclass = view_as<int>(TF2_GetPlayerClass(iVictim));
	int iEnt = CreateEntityByName("tf_ragdoll");
	float fClientOrigin[3];
	
	SetEntPropVector(iEnt, Prop_Send, "m_vecRagdollOrigin", fClientOrigin); 
	SetEntProp(iEnt, Prop_Send, "m_iPlayerIndex", iVictim);
	SetEntProp(iEnt, Prop_Send, "m_iTeam", iVteam);
	SetEntProp(iEnt, Prop_Send, "m_iClass", iVclass);
	SetEntProp(iEnt, Prop_Send, "m_bIceRagdoll", 1);
	
	DataPack hPack = CreateDataPack();
	
	WritePackCell(hPack, iVictim);
	WritePackCell(hPack, iEnt);
	
	DispatchSpawn(iEnt);
	
	CreateTimer(0.0, RemoveBody, hPack);
	CreateTimer(10.0, RemoveRagedoll, iEnt);
}

public Action RemoveBody(Handle timer, any hPack)
{
	ResetPack(hPack);
	
	int iClient = ReadPackCell(hPack);
	int iEnt = ReadPackCell(hPack);
	
	int BodyRagdoll = GetEntPropEnt(iClient, Prop_Send, "m_hRagdoll");
	
	if(IsValidEdict(BodyRagdoll))
	{
		RemoveEdict(BodyRagdoll);
		SetEntPropEnt(iClient, Prop_Send, "m_hRagdoll", iEnt);
	}
}

public Action RemoveRagedoll(Handle timer, any iEnt)
{
	if(IsValidEntity(iEnt))
	{
		char Classname[64];
		GetEdictClassname(iEnt, Classname, sizeof(Classname));
		
		if(StrEqual(Classname, "tf_ragdoll", false))
			RemoveEdict(iEnt);
	}
}

public void MLS_OnClientLeveledUp(int client, int level, int prestige)
{
	if (level == 15 && prestige == 0)
	{
		MLS_PrintToClient(client, "You have unlocked ice rag dolls!");
		MLS_PrintToClient(client, "Now whenever you kill someone, they turn into ice statues!");
	}
}
