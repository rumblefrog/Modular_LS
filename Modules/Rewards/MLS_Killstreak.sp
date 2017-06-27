#pragma semicolon 1

#define PLUGIN_AUTHOR "Fishy"
#define PLUGIN_VERSION "1.0.0"

#include <sourcemod>
#include <clientprefs>
#include <Modular_LS>

#pragma newdecls required

public Plugin myinfo = 
{
	name = "MLS - Custom Killstreak",
	author = PLUGIN_AUTHOR,
	description = "MLS Module - Reward - Custom Killstreak",
	version = PLUGIN_VERSION,
	url = "https://keybase.io/rumblefrog"
};

bool KSToggle[MAXPLAYERS + 1];
int KSAmount[MAXPLAYERS + 1];

Handle hKSToggleCookie;
Handle hKSAmountCookie;

public void OnPluginStart()
{
	if (GetEngineVersion() == Engine_TF2)
		PrintToServer("Game Successfully Detected");
	else
		SetFailState("Game Not Supported");
		
	RegConsoleCmd("sm_ks", CommandKillstreak, "Set player killstreak");
	
	hKSToggleCookie = RegClientCookie("killstreak_kstoggle", "Killstreak Toggle", CookieAccess_Protected);
	hKSAmountCookie = RegClientCookie("killstreak_ksamount", "Killstreak Amount", CookieAccess_Protected);
	
	HookEvent("player_spawn", Event_Spawn, EventHookMode_Post);
	
	RegAdminCmd("mls_ks_permission", CmdVoid, ADMFLAG_RESERVATION);

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!AreClientCookiesCached(i)) continue;
		OnClientCookiesCached(i);
	}
}

public Action CmdVoid(int iClient, int iArgs)
{
	return Plugin_Handled;
}

public void OnClientCookiesCached(int client)
{
	int KSAmountValue = 0;
	bool bKSToggleValue = false;

	if (AreClientCookiesCached(client))
	{
		char sKSToggleCookieValue[5];
		GetClientCookie(client, hKSToggleCookie, sKSToggleCookieValue, sizeof(sKSToggleCookieValue));
		bKSToggleValue = StrEqual(sKSToggleCookieValue, "true");

		char sKSAmountCookieValue[4];
		GetClientCookie(client, hKSAmountCookie, sKSAmountCookieValue, sizeof(sKSAmountCookieValue));
		KSAmountValue = StringToInt(sKSAmountCookieValue);
	}

	KSToggle[client] = bKSToggleValue;
	KSAmount[client] = KSAmountValue;

	refreshKillstreak(client);
}

public void OnClientDisconnect(int client)
{
	if (IsClientInGame(client))
	{
		char sToggleValue[5];
		char sAmountValue[4];

		sToggleValue = KSToggle[client] ? "true" : "false";
		IntToString(KSAmount[client], sAmountValue, sizeof(sAmountValue));

		SetClientCookie(client, hKSToggleCookie, sToggleValue);
		SetClientCookie(client, hKSAmountCookie, sAmountValue);
	}
}

public Action CommandKillstreak(int client, int args)
{
	int prestige = MLS_GetUserPrestige(client);
	int level = MLS_GetUserLevel(client);
	
	//True if below P0L50, false if above (expects true) [First Conditional]
	if ((prestige == 0 && level < 50) && !CheckCommandAccess(client, "mls_ks_permission", ADMFLAG_RESERVATION))
		return Plugin_Handled;
	
	if(IsClientInGame(client) && IsPlayerAlive(client))
	{
		char sAmount[4];
		GetCmdArg(1, sAmount, sizeof(sAmount));


		KSAmount[client] = 10;


		if(strlen(sAmount) > 0)
		{
			KSToggle[client] = true;
			KSAmount[client] = StringToInt(sAmount);

			if(KSAmount[client] > 100)
				KSAmount[client] = 100;
				
			if(KSAmount[client] < 0) KSAmount[client] = 0;
		}
		else
			KSToggle[client] = !KSToggle[client];
		
		if(KSAmount[client] == 0)
			KSToggle[client] = false;

		if(!KSToggle[client])
			KSAmount[client] = 0;

		refreshKillstreak(client);

		if(KSAmount[client] > 0)
			MLS_PrintToClient(client, "Killstreak set to {chartreuse}%i{grey}.", KSAmount[client]);
		else
			MLS_PrintToClient(client, "Killstreak reset.");
	}
	return Plugin_Handled;
}

public void Event_Spawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (IsClientInGame(client) && IsPlayerAlive(client))
		refreshKillstreak(client);
}

void refreshKillstreak(int client)
{
	if(IsValidEntity(client) && IsClientInGame(client) && !IsFakeClient(client))
		if(KSToggle[client] || KSAmount[client] == 0)
			SetEntProp(client, Prop_Send, "m_nStreaks", KSAmount[client], _, 0);
}

public void MLS_OnClientLeveledUp(int client, int level, int prestige)
{
	if (DoubleEqual(level, prestige, 50, 0))
		MLS_PrintToClient(client, "You have unlocked {chartreuse}Custom Killstreak{grey}! Now you can set your killstreak using {chartreuse}!ks{grey}.");
}
