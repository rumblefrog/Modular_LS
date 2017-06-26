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
		
	if (!IsLucky(iAttacker))
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

bool IsLucky(int client)
{
	int Level = MLS_GetUserLevel(client);
	
	int Prestige = MLS_GetUserPrestige(client);
	
	if (Level < 15 && Prestige == 0)
		return false;
		
	if (Prestige == 5)
		return true;
		
	if (Prestige == 0 && Level >= 15)
		return IsLuckyPercentage(15);
		
	if (Prestige == 1 && Level >= 25)
		return IsLuckyPercentage(30);
	if (Prestige == 1 && Level < 25)
		return IsLuckyPercentage(15);
		
	if (Prestige == 2 && Level >= 25)
		return IsLuckyPercentage(45);
	if (Prestige == 2 && Level < 25)
		return IsLuckyPercentage(30);
		
	if (Prestige == 3 && Level >= 45)
		return IsLuckyPercentage(60);
	if (Prestige == 3 && Level < 45)
		return IsLuckyPercentage(45);
		
	if (Prestige == 4 && Level >= 45)
		return IsLuckyPercentage(75);		
	if (Prestige == 4 && Level < 45)
		return IsLuckyPercentage(60);
		
	return false;
}

public void MLS_OnClientLeveledUp(int client, int level, int prestige)
{
	
	if (CheckCommandAccess(client, "mls_ird_permission", ADMFLAG_RESERVATION))
			return;
			
	if (DoubleEqual(level, prestige, 15, 0))
	{
		MLS_PrintToClient(client, "You have unlocked {chartreuse}Ice Ragdolls [I]{grey}! Now whenever you kill someone, they have a 15% chance to turn into a ice statue.");
		
		return;
	}
	
	if (DoubleEqual(level, prestige, 25, 1))
	{
		MLS_PrintToClient(client, "You have unlocked {chartreuse}Ice Ragdolls [II]{grey}! Now whenever you kill someone, they have a 30% chance to turn into a ice statue.");
		
		return;
	}
	
	if (DoubleEqual(level, prestige, 25, 2))
	{
		MLS_PrintToClient(client, "You have unlocked {chartreuse}Ice Ragdolls [III]{grey}! Now whenever you kill someone, they have a 45% chance to turn into a ice statue.");
		
		return;
	}
	
	if (DoubleEqual(level, prestige, 45, 3))
	{
		MLS_PrintToClient(client, "You have unlocked {chartreuse}Ice Ragdolls [IV]{grey}! Now whenever you kill someone, they have a 60% chance to turn into a ice statue.");
		
		return;
	}
	
	if (DoubleEqual(level, prestige, 45, 4))
	{
		MLS_PrintToClient(client, "You have unlocked {chartreuse}Ice Ragdolls [V]{grey}! Now whenever you kill someone, they have a 75% chance to turn into a ice statue.");
		
		return;
	}
	
	if (prestige == 5)
		MLS_PrintToClient(client, "You have unlocked {chartreuse}Ice Ragdolls [VI]{grey}! Now whenever you kill someone, they have a 100% chance to turn into a ice statue.");
	
}
