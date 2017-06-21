#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "Fishy"
#define PLUGIN_VERSION "0.0.2"

#include <sourcemod>
#include <sdktools>
#include <morecolors>
#undef REQUIRE_PLUGIN
#include <EventLogs>

#pragma newdecls required

#define BaseXP 10.0

#define MaxBonusHour 2

#define MaxPL 5
#define MaxPLL 50

#define Bar_Fill "█"
#define Bar_Empty "▒"


#define Sound_LVL "ls/lvl.wav"
#define Sound_Prestige "ls/prestige.wav"

#define Sound_LVL_Absolute "sound/ls/lvl.wav"
#define Sound_Prestige_Absolute "sound/ls/prestige.wav"

enum LSPL
{
	LSPL_0,
	LSPL_1,
	LSPL_2,
	LSPL_3,
	LSPL_4
}

enum LSPL_Multiplier
{
	float:LSPL_Multiplier_0 = 1.13,
	float:LSPL_Multiplier_1 = 1.137,
	float:LSPL_Multiplier_2 = 1.144,
	float:LSPL_Multiplier_3 = 1.151,
	float:LSPL_Multiplier_4 = 1.158,
	LSPL_Multiplier_Invalid
}

char LSPL_Titles[6][] = {

	"D",
	"C",
	"B",
	"A",
	"H",
	"S"

};

//<!-- Main -->
Database hDB;

bool Verbose;

int XP[MAXPLAYERS + 1] =  { -1, ... };
int Prestige[MAXPLAYERS + 1] =  { -1, ... };
int Level[MAXPLAYERS + 1] =  { -1, ... };

int XPAtLevel[MAXPLAYERS + 1] =  { -1, ... };
int XPToNextLevel[MAXPLAYERS + 1] =  { -1, ... };

Handle Progression_Hud;

public Plugin myinfo = 
{
	name = "Modular LS",
	author = PLUGIN_AUTHOR,
	description = "Modular Leveling System",
	version = PLUGIN_VERSION,
	url = "https://keybase.io/rumblefrog"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	hDB = SQL_Connect("modular_ls", true, error, err_max);
	
	if (hDB == INVALID_HANDLE)
		return APLRes_Failure;
	
	char TableCreateSQL[] = "CREATE TABLE IF NOT EXISTS `Modular_LS` ( `id` INT NOT NULL AUTO_INCREMENT , `steamid` VARCHAR(32) NOT NULL , `xp` BIGINT NOT NULL DEFAULT '0' , `prestige` TINYINT NOT NULL DEFAULT '0' , `creation_date` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP , PRIMARY KEY (`id`), INDEX (`prestige`), UNIQUE (`steamid`)) ENGINE = InnoDB CHARSET=utf8mb4 COLLATE utf8mb4_general_ci";
	
	SQL_SetCharset(hDB, "utf8mb4");
			
	hDB.Query(OnTableCreate, TableCreateSQL, _, DBPrio_High);
	
	RegPluginLibrary("Modular_LS");

	CreateNative("MLS_GetUserLevel", Native_GetUserLevel);
	CreateNative("MLS_GetUserPrestige", Native_GetUserPrestige);
	CreateNative("MLS_GetPrestigeColorRGB", Native_GetPrestigeColorRGB);
	CreateNative("MLS_GetPrestigeColorHex", Native_GetPrestigeColorHex);
	CreateNative("MLS_GetPrestigeTitle", Native_GetPrestigeTitle);
	CreateNative("MLS_AddXP", Native_AddXP);
	
	return APLRes_Success;
}

public void OnTableCreate(Database db, DBResultSet results, const char[] error, any pData)
{
	if (results == null)
	{
		EL_LogPlugin(LOG_FATAL, "Unable to create DBLS table: %s", error);
		SetFailState("Unable to create table: %s", error);
	}
}

public void OnPluginStart()
{
	RegConsoleCmd("sm_prestige", CmdPrestige, "Prestige!");
	RegAdminCmd("sm_mls_dump", CmdDump, 0, "Dump user data");
	RegAdminCmd("sm_mls_debug", CmdToggleDebug, ADMFLAG_CHEATS, "Toggle Console Debugging");
	RegAdminCmd("sm_mls_addxp", CmdAddXP, ADMFLAG_ROOT, "DEBUG: Add XP");
	RegAdminCmd("sm_mls_setprestige", CmdSetPrestige, ADMFLAG_ROOT, "DEBUG: Set Prestige Level");
	
	Progression_Hud = CreateHudSynchronizer();
}

public void OnMapStart()
{
	CreateTimer(0.5, Timer_Progression_Hud, _, TIMER_REPEAT);
	
	PrecacheSound(Sound_LVL, true);
	PrecacheSound(Sound_Prestige, true);	
	
	AddFileToDownloadsTable(Sound_LVL_Absolute);
	AddFileToDownloadsTable(Sound_Prestige_Absolute);
}

public Action Timer_Progression_Hud(Handle hTimer)
{	
	char ProgressBar[64];
	int colors[3];
	
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (IsValidClient(iClient))
		{
			GetColorRGB(colors, iClient);
			SetHudTextParams(0.05, 0.10, 0.6, 0, colors[0], colors[1], colors[2], 0);
					
			if (Prestige[iClient] != 5)
			{
				if (Level[iClient] == -1 || XPAtLevel[iClient] == -1 || XPToNextLevel[iClient] == -1)
					ShowSyncHudText(iClient, Progression_Hud, "N/A");
				else
				{
					GenerateProgressBar(XPAtLevel[iClient], XPToNextLevel[iClient], ProgressBar, sizeof ProgressBar);
					ShowSyncHudText(iClient, Progression_Hud, "%i: %s %i/%i", Level[iClient], ProgressBar, XPAtLevel[iClient], XPToNextLevel[iClient]);
				}
			} else
				ShowSyncHudText(iClient, Progression_Hud, "Reached Max Prestige");
		}
	}
}

public Action CmdToggleDebug(int client, int args)
{
	if (!Verbose)
		CReplyToCommand(client, "{lightseagreen}[MaxDB] {grey}Enabled verbose logging");
	else
		CReplyToCommand(client, "{lightseagreen}[MaxDB] {grey}Disabled verbose logging");
		
	Verbose = !Verbose;
	
	return Plugin_Handled;
}

public Action CmdAddXP(int client, int args)
{
	if (args < 1)
	{
		CReplyToCommand(client, "{lightseagreen}[MaxDB] {grey}Missing XP");
		
		return Plugin_Handled;
	}
	
	if (!CanGainXP(client))
	{
		CReplyToCommand(client, "{lightseagreen}[MaxDB] {grey}Cannot gain XP");
		
		return Plugin_Handled;
	}
	
	char buffer[16];
	
	GetCmdArg(1, buffer, sizeof buffer);
	
	int input = StringToInt(buffer);
	
	int EXP = GetXPValue(client, input);
	
	AddXPToUser(client, EXP);
	
	CReplyToCommand(client, "{lightseagreen}[MaxDB] {grey}Requested %i XP to be added", EXP);
	
	return Plugin_Handled;
}
public Action CmdSetPrestige(int client, int args)
{
	if (args < 1)
	{
		CReplyToCommand(client, "{lightseagreen}[MaxDB] {grey}Missing Prestige");
		
		return Plugin_Handled;
	}
	
	char buffer[16];
	
	GetCmdArg(1, buffer, sizeof buffer);
	
	int prestigel = StringToInt(buffer);
	
	Prestige[client] = prestigel;
	
	return Plugin_Handled;
}

public Action CmdDump(int client, int args)
{
	PrintToConsole(client, "Base: %f", BaseXP);
	PrintToConsole(client, "XP: %i", XP[client]);
	PrintToConsole(client, "Prestige: %i", Prestige[client]);
	PrintToConsole(client, "Prestige Multiplier: %f", view_as<float>(GetMultiplierByPrestige(client)));
	PrintToConsole(client, "Level: %i", Level[client]);
	PrintToConsole(client, "XPAtLevel: %i", XPAtLevel[client]);
	PrintToConsole(client, "XPToNextLevel: %i", XPToNextLevel[client]);
	
	PrintToConsole(client, "<-------------------------->");
	
	PrintToConsole(client, "TEST1: %f", XP[client] / BaseXP);
	
	return Plugin_Handled;
}

public Action CmdPrestige(int client, int args)
{
	if (XP[client] == -1 || Prestige[client] == -1)
	{
		CReplyToCommand(client, "{lightseagreen}[MaxDB] {grey}Oops, unable to prestige.");
		
		return Plugin_Handled;
	}
		
	
	if (Prestige[client] >= 5)
	{
		CReplyToCommand(client, "{lightseagreen}[MaxDB] {grey}You have reached the highest prestige!");
			
		return Plugin_Handled;
	}
	
	int UserLevel = GetUserLevel(client);
	
	if (UserLevel != 50 || UserLevel == -1)
	{
		CReplyToCommand(client, "{lightseagreen}[MaxDB] {grey}You can only prestige at level 50!");
			
		return Plugin_Handled;
	}

	char Update_Query[1024], Client_SteamID64[32];
	
	GetClientAuthId(client, AuthId_SteamID64, Client_SteamID64, sizeof Client_SteamID64);
	
	Format(Update_Query, sizeof Update_Query, "UPDATE Modular_LS SET `xp` = 0, `prestige`= `prestige` + 1 WHERE `steamid` = '%s'", Client_SteamID64);
	
	DataPack pData = CreateDataPack();
	
	WritePackCell(pData, GetCmdReplySource());
	WritePackCell(pData, client);
	
	hDB.Query(SQL_OnPlayerPrestige, Update_Query, pData);
	
	return Plugin_Handled;
}

public void SQL_OnPlayerPrestige(Database db, DBResultSet results, const char[] error, any pData)
{
	ResetPack(pData);
	
	ReplySource CmdOrigin = ReadPackCell(pData);
	int client = ReadPackCell(pData);
	
	SetCmdReplySource(CmdOrigin);
	
	if (results == null)
	{
		ReplyToCommand(client, "Fail to prestige, please try again later");
		return;
	}
	
	CPrintToChat(client, "{lightseagreen}[MaxDB] {grey}You have prestiged!");
	
	
	EmitSoundToClient(client, Sound_Prestige, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_GUNFIRE);
	
	XP[client] = 0;
	Prestige[client]++;
	
	CalculateValues(client);
}

public void OnClientPostAdminCheck(int client)
{
	if (IsFakeClient(client))
		return;
	
	char Select_Query[1024], Client_SteamID64[32];
	
	GetClientAuthId(client, AuthId_SteamID64, Client_SteamID64, sizeof Client_SteamID64);
	
	Format(Select_Query, sizeof Select_Query, "SELECT * FROM Modular_LS WHERE `steamid` = '%s'", Client_SteamID64);
	
	DataPack pData = CreateDataPack();
	WritePackCell(pData, client);
	WritePackString(pData, Client_SteamID64);
	
	hDB.Query(SQL_OnFetchPlayerData, Select_Query, pData);
}

public void SQL_OnFetchPlayerData(Database db, DBResultSet results, const char[] error, any pData)
{
	if (results == null)
	{
		EL_LogPlugin(LOG_ERROR, "Unable to fetch player data: %s", error);
		return;
	}
	
	ResetPack(pData);
	
	int client = ReadPackCell(pData);
	
	if (results.RowCount == 0)
	{
		char Client_SteamID64[32], Insert_Query[1024];
	
		ReadPackString(pData, Client_SteamID64, sizeof Client_SteamID64);
		
		Format(Insert_Query, sizeof Insert_Query, "INSERT INTO Modular_LS (`steamid`) VALUES ('%s')", Client_SteamID64);
		
		db.Query(SQL_OnCreatePlayerData, Insert_Query, client);
		
		return;
	}
	
	results.FetchRow();
	
	XP[client] = results.FetchInt(2);
	Prestige[client] = results.FetchInt(3);
	
	CalculateValues(client);
}

public void SQL_OnCreatePlayerData(Database db, DBResultSet results, const char[] error, any client)
{
	if (results == null)
	{
		EL_LogPlugin(LOG_ERROR, "Unable to create player data: %s", error);
		
		if (Verbose)
			PrintToConsole(client, "Unable to create player data: %s", error);
	}
	
	XP[client] = 0;
	Prestige[client] = 0;
	
	CalculateValues(client);
}

int GetXPValue(int client, int base_xp)
{
	float SessionTime = GetClientTime(client);
	float MaxBonusMultiplier = ((MaxBonusHour * 0.5) + 1.0);
	int MaxBonusSession = (60 * 60 * MaxBonusHour);
	
	if (SessionTime >= MaxBonusSession)
		return RoundToNearest(base_xp * MaxBonusMultiplier);
	else
		return RoundToNearest(base_xp * ((SessionTime / MaxBonusSession) + 1.0));
}

void AddXPToUser(int client, int xp)
{
	if (!CanGainXP(client))
		return;
	
	char Update_Query[1024], Client_SteamID64[32];
	
	GetClientAuthId(client, AuthId_SteamID64, Client_SteamID64, sizeof Client_SteamID64);
	
	Format(Update_Query, sizeof Update_Query, "UPDATE Modular_LS SET `xp` = `xp` + '%u' WHERE `steamid` = '%s'", xp, Client_SteamID64);
	
	DataPack pData = CreateDataPack();
	WritePackCell(pData, client);
	WritePackCell(pData, xp);
	
	hDB.Query(SQL_OnAddXPToUser, Update_Query, pData);
}

public void SQL_OnAddXPToUser(Database db, DBResultSet results, const char[] error, any pData)
{
	ResetPack(pData);
	int client = ReadPackCell(pData);
	int xp = ReadPackCell(pData);
	
	if (results == null)
	{
		EL_LogPlugin(LOG_ERROR, "Unable to add XP to player: %s", error);
		
		if (Verbose)
			PrintToConsole(pData, "Unable to add XP to player: %s", error);
	}
	
	XP[client] += xp;
	CalculateValues(client);
}

LSPL_Multiplier GetMultiplierByPrestige(int client)
{
	if (!IsValidClient(client))
		return LSPL_Multiplier_Invalid;
	
	switch (Prestige[client])
	{
		case 0:
			return LSPL_Multiplier_0;
		case 1:
			return LSPL_Multiplier_1;
		case 2:
			return LSPL_Multiplier_2;
		case 3:
			return LSPL_Multiplier_3;
		case 4:
			return LSPL_Multiplier_4;
		default:
			return LSPL_Multiplier_Invalid;
	}
	
	return LSPL_Multiplier_Invalid;
}

bool CanGainXP(int client)
{
	if (XP[client] == -1 || Prestige[client] == -1)
		return false;
		
	int UserLevel = GetUserLevel(client);
	
	if (UserLevel == -1)
	{
		if (Verbose)
			CPrintToChat(client, "{lightseagreen}[MaxDB] {grey}Invalid Level.");
			
		return false;
	}
	
	CalculateValues(client);
	
	if (UserLevel >= 50)
	{
		if (Verbose)
			CPrintToChat(client, "{lightseagreen}[MaxDB] {grey}In order to earn more levels, prestige first!");
			
		return false;
	}
	
	if (Prestige[client] >= 5)
	{
		if (Verbose)
			CPrintToChat(client, "{lightseagreen}[MaxDB] {grey}You have reached the highest prestige!");
			
		return false;
	}
		
	return true;
}

void CalculateValues(int client)
{
	int OriginLevel = Level[client];
	
	Level[client] = GetUserLevel(client);
	
	if (Level[client] == -1)
	{
		XPToNextLevel[client] = -1;
		XPAtLevel[client] = -1;
		return;
	}
	
	LSPL_Multiplier Multiplier = GetMultiplierByPrestige(client);
	
	if (Multiplier == LSPL_Multiplier_Invalid)
	{
		XPToNextLevel[client] = -1;
		XPAtLevel[client] = -1;
		return;
	}
	
	if (Level[client] >= 50)
	{
		int MaxXPAtCurrent = GetXPFromLevel(50, Multiplier);
		XPToNextLevel[client] = MaxXPAtCurrent;
		XPAtLevel[client] = MaxXPAtCurrent;
		return;
	}
		
	if (XP[client] < BaseXP)
	{
		XPToNextLevel[client] = 10;
		XPAtLevel[client] = 0;
		
		return;
	}
	
	if (OriginLevel != -1 && Level[client] > OriginLevel)
	{
		EmitSoundToClient(client, Sound_LVL, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_GUNFIRE);
		CPrintToChat(client, "{lightseagreen}[MaxDB] {grey}You have leveled up!");
	}
	
	int CurrentLevelXPBuffer = GetXPFromLevel(Level[client], Multiplier);
	int NextLevel = Level[client] + 1;
	int NextLevelBuffer = GetXPFromLevel(NextLevel, Multiplier);
	
	XPToNextLevel[client] = NextLevelBuffer - CurrentLevelXPBuffer;
	XPAtLevel[client] = XP[client] - CurrentLevelXPBuffer;
}

int GetUserLevel(int client)
{
	LSPL_Multiplier multiplier = GetMultiplierByPrestige(client);
	
	if (multiplier == LSPL_Multiplier_Invalid)
	{
		if (Verbose)
			CPrintToChat(client, "{lightseagreen}[MaxDB] {grey}Received Invalid Multiplier.");
		return -1;
	}
	
	if (XP[client] < BaseXP)
		return 0;
					
	int result = RoundToFloor( 1 + Logarithm((XP[client] / BaseXP), view_as<float>(multiplier)));
	
	if (result >= 50)
		return 50;
	else
		return result;
}

// < -- Unused -- >
//int GetLevelFromXP(int xp, LSPL_Multiplier multiplier)
//{
//	return RoundToFloor( 1 + Logarithm(xp / BaseXP, view_as<float>(multiplier)));
//}

int GetXPFromLevel(int level, LSPL_Multiplier multiplier)
{
	return RoundToCeil(BaseXP * Pow(view_as<float>(multiplier), (level - 1) * 1.0));
}

bool IsValidClient(int iClient, bool bAlive = false)
{
	if (iClient >= 1 && iClient <= MaxClients && IsClientConnected(iClient) && IsClientInGame(iClient) && !IsFakeClient(iClient) && XP[iClient] != -1 && Prestige[iClient] != -1 && (bAlive == false || IsPlayerAlive(iClient)))
	{
		return true;
	}

	return false;
}

void GenerateProgressBar(int value, int base, char[] buffer, int size)
{
	int filled = RoundToFloor((float(value) / float(base)) * 10);
	
	int empty = 10 - filled;
	
	for (int i = 1; i <= filled; i++)
	{
		Format(buffer, size, "%s%s", buffer, Bar_Fill);
	}
	
	for (int i = 1; i <= empty; i++)
	{
		Format(buffer, size, "%s%s", buffer, Bar_Empty);
	}
}

void GetColorRGB(int color[3], int client)
{
	switch (Prestige[client])
	{
		case 0:
			color =  { 211, 218, 229 };
		case 1:
			color =  { 50, 10, 141 };
		case 2:
			color =  { 184, 134, 11 };
		case 3:
			color =  { 14, 237, 199 };
		case 4:
			color =  { 158, 20, 20 };
		case 5:
			color =  { 211, 44, 230 };
		default:
			color =  { 211, 211, 211 };
	}
}

int GetColorHex(int client)
{
	switch (Prestige[client])
	{
		case 0:
			return 0xd3dae5;
		case 1:
			return 0x320a8d;
		case 2:
			return 0x0eedc7;
		case 3:
			return 0xd3dae5;
		case 4:
			return 0x9e1414;
		case 5:
			return 0xd32ce6;
		default:
			return 0xd3d3dd;
	}
	
	return 0xd3d3dd;
}

public int Native_GetUserLevel(Handle plugin, int numParams)
{
	if (numParams < 1)
		return ThrowNativeError(SP_ERROR_NATIVE, "Missing client parameter");
	
	int client = GetNativeCell(1);
	
	if (!IsValidClient(client))
		return ThrowNativeError(SP_ERROR_NATIVE, "Client %d is not connected", client);
		
	return Level[client];
}

public int Native_GetUserPrestige(Handle plugin, int numParams)
{
	if (numParams < 1)
		return ThrowNativeError(SP_ERROR_NATIVE, "Missing client parameter");
	
	int client = GetNativeCell(1);
	
	if (!IsValidClient(client))
		return ThrowNativeError(SP_ERROR_NATIVE, "Client %d is not connected", client);
		
	return Prestige[client];
}

public int Native_GetPrestigeColorRGB(Handle plugin, int numParams)
{
	if (numParams < 2)
		return ThrowNativeError(SP_ERROR_NATIVE, "Missing parameter(s)");
		
	int client = GetNativeCell(2);
	
	if (!IsValidClient(client))
		return ThrowNativeError(SP_ERROR_NATIVE, "Client %d is not connected", client);
	
	int colors[3];
	
	GetColorRGB(colors, client);
	
	SetNativeArray(1, colors, sizeof colors);
	
	return 0;
}

public int Native_GetPrestigeColorHex(Handle plugin, int numParams)
{
	if (numParams < 1)
		return ThrowNativeError(SP_ERROR_NATIVE, "Missing parameter(s)");
		
	int client = GetNativeCell(1);
	
	if (!IsValidClient(client))
		return ThrowNativeError(SP_ERROR_NATIVE, "Client %d is not connected", client);
	
	return GetColorHex(client);
}

public int Native_GetPrestigeTitle(Handle plugin, int numParams)
{
	if (numParams < 3)
		return ThrowNativeError(SP_ERROR_NATIVE, "Missing parameter(s)");
		
	int client = GetNativeCell(3);
	
	if (!IsValidClient(client))
		return ThrowNativeError(SP_ERROR_NATIVE, "Client %d is not connected", client);
	
	if (Prestige[client] == -1 || Prestige[client] > 5)
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid prestige data for client %d", client);
		
	int buffer_size = GetNativeCell(2);
	
	SetNativeString(1, LSPL_Titles[Prestige[client]], buffer_size);
	
	return 0;
}

public int Native_AddXP(Handle plugin, int numParams)
{
	if (numParams < 3)
		return ThrowNativeError(SP_ERROR_NATIVE, "Missing parameter(s)");
		
	int client = GetNativeCell(1);
	
	if (!IsValidClient(client))
		return ThrowNativeError(SP_ERROR_NATIVE, "Client %d is not connected", client);
		
	if (!CanGainXP(client))
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid prestige data for client %d", client);
		
	int buffer = GetNativeCell(2);
		
	if (buffer < 0)
		return ThrowNativeError(SP_ERROR_NATIVE, "Cannot add negative XP");
		
	bool bonus = GetNativeCell(3);
		
	if (bonus)
		buffer = GetXPValue(client, buffer);
	
	AddXPToUser(client, buffer);
	
	return 1;
}
