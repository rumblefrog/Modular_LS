#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "Fishy"
#define PLUGIN_VERSION "0.0.1"

#include <sourcemod>
#include <sdktools>
#include <morecolors>
#undef REQUIRE_PLUGIN
#include <EventLogs>

#pragma newdecls required

#define BaseXP 10

#define MaxBonusHour 2

#define MaxPL 5
#define MaxPLL 50

#define KillXP 2

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

char LSPL_Titles[5][] = {

	"Silver",
	"Gold",
	"Paladin",
	"World Defender",
	"Global Elite"

};

//<!-- Main -->
Database hDB;

bool Verbose;

int XP[MAXPLAYERS + 1] =  { -1, ... };
int Prestige[MAXPLAYERS + 1] =  { -1, ... };

public Plugin myinfo = 
{
	name = "Dodgeball LS",
	author = PLUGIN_AUTHOR,
	description = "Dodgeball Leveling System",
	version = PLUGIN_VERSION,
	url = "https://keybase.io/rumblefrog"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	hDB = SQL_Connect("dodgeball_ls", true, error, err_max);
	
	if (hDB == INVALID_HANDLE)
		return APLRes_Failure;
	
	char TableCreateSQL[] = "CREATE TABLE `Dodgeball_LS` ( `id` INT NOT NULL AUTO_INCREMENT , `steamid` VARCHAR(32) NOT NULL , `xp` BIGINT NOT NULL DEFAULT '0' , `prestige` TINYINT NOT NULL DEFAULT '0' , `timeplayed` BIGINT NOT NULL DEFAULT '0' , `creation_date` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP , PRIMARY KEY (`id`), INDEX (`prestige`), UNIQUE (`steamid`)) ENGINE = InnoDB CHARSET=utf8mb4 COLLATE utf8mb4_general_ci";
	
	SQL_SetCharset(hDB, "utf8mb4");
			
	hDB.Query(OnTableCreate, TableCreateSQL, _, DBPrio_High);
	
	RegPluginLibrary("Dodgeball_LS");

	//CreateNative("DBLS_GetUserLevel", NativeGetUserLevel);
	
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
	RegAdminCmd("sm_dls_debug", CmdToggleDebug, ADMFLAG_CHEATS, "Toggle console debugging");
	
	HookEvent("player_death", Event_PlayerDeath);
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

public Action CmdPrestige(int client, int args)
{
	if (XP[client] == -1 || Prestige[client] == -1)
	{
		CReplyToCommand(client, "{lightseagreen}[MaxDB] {grey}Oops, unable to prestige. Please contact an admin.");
		
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
	
	//TODO: To be completed
	
	return Plugin_Handled;
}

public void OnClientPostAdminCheck(int client)
{
	char Select_Query[1024], Client_SteamID64[32];
	
	GetClientAuthId(client, AuthId_SteamID64, Client_SteamID64, sizeof Client_SteamID64);
	
	Format(Select_Query, sizeof Select_Query, "SELECT * FROM Dodgeball_LS WHERE `steamid` = '%s'", Client_SteamID64);
	
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
		
		Format(Insert_Query, sizeof Insert_Query, "INSERT INTO Dodgeball_LS (`steamid`) VALUES ('%s')", Client_SteamID64);
		
		db.Query(SQL_OnCreatePlayerData, Insert_Query, client);
		
		return;
	}
	
	results.FetchRow();
	
	XP[client] = results.FetchInt(2);
	Prestige[client] = results.FetchInt(3);
}

public void SQL_OnCreatePlayerData(Database db, DBResultSet results, const char[] error, any pData)
{
	if (results == null)
	{
		EL_LogPlugin(LOG_ERROR, "Unable to create player data: %s", error);
		
		if (Verbose)
			PrintToConsole(pData, "Unable to create player data: %s", error);
	}
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int iVictim = event.GetInt("userid");
	int iAttacker = event.GetInt("attacker");
	
	if (iVictim == iAttacker)
		return;
		
	int XPGain = GetSessionBonus(iAttacker, KillXP);
	AddXPToUser(iAttacker, XPGain);
}

int GetSessionBonus(int client, int base_xp)
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
	
	Format(Update_Query, sizeof Update_Query, "UPDATE Dodgeball_LS SET `xp` = '%u' WHERE `steamid` = '%s'", xp, Client_SteamID64);
	
	hDB.Query(SQL_OnAddXPToUser, Update_Query, client);
}

public void SQL_OnAddXPToUser(Database db, DBResultSet results, const char[] error, any pData)
{
	if (results == null)
	{
		EL_LogPlugin(LOG_ERROR, "Unable to add XP to player: %s", error);
		
		if (Verbose)
			PrintToConsole(pData, "Unable to add XP to player: %s", error);
	}
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
			CPrintToChat(client, "{lightseagreen}[MaxDB] {grey}Invalid prestige data.");
			
		return false;
	}
	
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

int GetUserLevel(int client)
{
	LSPL_Multiplier multiplier = GetMultiplierByPrestige(client);
	
	if (multiplier == LSPL_Multiplier_Invalid)
		return -1;
		
	return RoundToNearest(Logarithm(((XP[client] / BaseXP) * 1.0), view_as<float>(multiplier)));
}

int GetLevelFromXP(int xp, LSPL_Multiplier multiplier)
{
	return RoundToNearest(Logarithm(xp / BaseXP, multiplier));
}

int GetXPFromLevel(int level, LSPL_Multiplier multiplier)
{
	return RoundToNearest(BaseXP * pow(view_as<float>(multiplier), (level - 1)));
}

bool IsValidClient(int iClient, bool bAlive = false)
{
	if (iClient >= 1 && iClient <= MaxClients && IsClientConnected(iClient) && IsClientInGame(iClient) && XP[iClient] != -1 && Prestige[iClient] != -1 && (bAlive == false || IsPlayerAlive(iClient)))
	{
		return true;
	}

	return false;
}
