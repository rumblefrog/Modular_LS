#pragma semicolon 1

#define PLUGIN_AUTHOR "Fishy"
#define PLUGIN_VERSION "1.0.0"

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <Modular_LS>

#pragma newdecls required

#define BaseXP 1
#define BaseBonus 0.05

#define MPH_CF 0.042614 

#define Max_Rockets 1000

int g_iRocketOwner[Max_Rockets];

public Plugin myinfo = 
{
	name = "MLS - XP On Rocket Reflect",
	author = PLUGIN_AUTHOR,
	description = "MLS Module - Distributor - XP On Rocket Reflect",
	version = PLUGIN_VERSION,
	url = "https://keybase.io/rumblefrog"
};

public void OnPluginStart()
{
	if (GetEngineVersion() == Engine_TF2)
		PrintToServer("Game Successfully Detected");
	else
		SetFailState("Game Not Supported");
}

public void OnGameFrame()
{
	int iEntity = -1;
	while((iEntity = FindEntityByClassname(iEntity, "tf_projectile_rocket")) != INVALID_ENT_REFERENCE)
	{
		int iClient = GetEntPropEnt(iEntity, Prop_Send, "m_hOwnerEntity");
				
		if (g_iRocketOwner[iEntity] == iClient)
			continue;
			
		if (!IsValidClient(iClient))
			continue;
					
		g_iRocketOwner[iEntity] = iClient;
		
		int iReflect = GetEntProp(iEntity, Prop_Send, "m_iDeflected");
		
		int EXP = RoundToNearest(((iReflect * BaseBonus) + 1) * BaseXP);
		
		MLS_AddXP(iClient, EXP);
	}
}