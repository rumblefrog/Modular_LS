#pragma semicolon 1

#define PLUGIN_AUTHOR "Fishy"
#define PLUGIN_VERSION "1.0.0"

#include <sourcemod>
#include <clientprefs>
#include <tf2attributes>
#include <Modular_LS>

#pragma newdecls required

Handle Cookie;

float FootprintID[MAXPLAYERS + 1];

public Plugin myinfo = 
{
	name = "MLS - Footprints",
	author = PLUGIN_AUTHOR,
	description = "MLS Module - Reward - Footprints",
	version = PLUGIN_VERSION,
	url = "https://keybase.io/rumblefrog"
};

public void OnPluginStart()
{
	if (GetEngineVersion() == Engine_TF2)
		PrintToServer("Game Successfully Detected");
	else
		SetFailState("Game Not Supported");
		
	RegConsoleCmd("sm_footprints", CmdFootprints, "Set User Footprints");
	RegConsoleCmd("sm_footsteps", CmdFootprints, "Set User Footsteps");
	
	RegAdminCmd("mls_fp_permission", CmdVoid, ADMFLAG_RESERVATION);
	
	Cookie = RegClientCookie("footprints_pref", "Client Equipped Footprint", CookieAccess_Private);
	
	HookEvent("player_spawn", PlayerSpawn, EventHookMode_Post);
}

public void OnClientCookiesCached(int client)
{
	char buffer[64];
	
	GetClientCookie(client, Cookie, buffer, sizeof buffer);
	
	FootprintID[client] = StringToFloat(buffer);
}

public void OnClientDisconnect(int client)
{
	char buffer[64]; 
	
	FloatToString(FootprintID[client], buffer, sizeof buffer);
	
	SetClientCookie(client, Cookie, buffer);
	
	if(FootprintID[client] > 0.0)
		FootprintID[client] = 0.0;
}

public Action CmdVoid(int iClient, int iArgs)
{
	return Plugin_Handled;
}

public Action CmdFootprints(int client, int args)
{
	
	if (!CheckCommandAccess(client, "mls_fp_permission", ADMFLAG_RESERVATION) && !IsAERank(client, 2, 50))
	{
		MLS_PrintToClient(client, "This ability unlocks at prestige 2 level 50");
		return Plugin_Handled;
	}
	
	Menu ws = new Menu(FootprintsCallBack);
	
	ws.SetTitle("Choose Your Footprints Effect");

	ws.AddItem("0", "No Effect");
	ws.AddItem("X", "----------", ITEMDRAW_DISABLED);
	ws.AddItem("1", "Team Based");
	ws.AddItem("7777", "Blue");
	ws.AddItem("933333", "Light Blue");
	ws.AddItem("8421376", "Yellow");
	ws.AddItem("4552221", "Corrupted Green");
	ws.AddItem("3100495", "Dark Green");
	ws.AddItem("51234123", "Lime");
	ws.AddItem("5322826", "Brown");
	ws.AddItem("8355220", "Oak Tree Brown");
	ws.AddItem("13595446", "Flames");
	ws.AddItem("8208497", "Cream");
	ws.AddItem("41234123", "Pink");
	ws.AddItem("300000", "Satan's Blue");
	ws.AddItem("2", "Purple");
	ws.AddItem("3", "4 8 15 16 23 42");
	ws.AddItem("83552", "Ghost In The Machine");
	ws.AddItem("9335510", "Holy Flame");

	ws.Display(client, MENU_TIME_FOREVER);

	return Plugin_Handled;
}

public int FootprintsCallBack(Menu menu, MenuAction action, int client, int param2)
{
	if(action == MenuAction_End)
		delete menu;

	if(action == MenuAction_Select)
	{
		char info[12];
		menu.GetItem(param2, info, sizeof(info));

		float weapon_glow = StringToFloat(info);
		
		FootprintID[client] = weapon_glow;
		
		if(weapon_glow == 0.0)
			TF2Attrib_RemoveByName(client, "SPELL: set Halloween footstep type");
		else
			TF2Attrib_SetByName(client, "SPELL: set Halloween footstep type", weapon_glow);
	}
}

public Action PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if(FootprintID[client] > 0.0)
		TF2Attrib_SetByName(client, "SPELL: set Halloween footstep type", FootprintID[client]);
}

public void MLS_OnClientLeveledUp(int client, int level, int prestige)
{
	if (DoubleEqual(level, prestige, 50, 2))
		MLS_PrintToClient(client, "You have unlocked {chartreuse}Ability To Set Footprint{grey}! Now you can set footprint using {chartreuse}!footprints{grey}.");
}
