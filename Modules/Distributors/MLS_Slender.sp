#pragma semicolon 1

#define PLUGIN_AUTHOR "Fishy"
#define PLUGIN_VERSION "1.0.0"

#include <sourcemod>
#include <Modular_LS>
#include <sf2>

#pragma newdecls required

#define CaughtXP 2
#define EscapeXP 3
#define PageCollectedXP 10

public Plugin myinfo = 
{
	name = "MLS - Slender",
	author = PLUGIN_AUTHOR,
	description = "MLS Module - Distributor - Slender",
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

public int SF2_OnClientEscape(int client)
{
	if (!IsValidClient(client))
		return;
		
	MLS_AddXP(client, EscapeXP);
}

public int SF2_OnClientCollectPage(int pageEnt, int client)
{
	if (!IsValidClient(client))
		return;
		
	MLS_AddXP(client, PageCollectedXP);
}

public int SF2_OnClientCaughtByBoss(int client, int iBossIndex)
{
	if (!IsValidClient(client))
		return;
		
	MLS_AddXP(client, CaughtXP);
}
