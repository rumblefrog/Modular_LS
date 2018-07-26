#pragma semicolon 1

#define PLUGIN_AUTHOR "Fishy"
#define PLUGIN_VERSION "1.0.0"

#include <sourcemod>
#include <sdktools>
#include <morecolors>
#include <SteamWorks>
#undef REQUIRE_PLUGIN
#include <EventLogs>
#undef REQUIRE_EXTENSIONS
#include <steamtools>

#pragma newdecls required

#define BaseXP 10.0

#define MaxBonusHour 2

#define MaxPL 5
#define MaxPLL 50

#define Bar_Fill "█"
#define Bar_Empty "░"

#define DoubleXPSymbol "ϟ"

#define Sound_LVL "ls/lvl.wav"
#define Sound_Prestige "ls/prestige.wav"
#define Sound_Alarm "ambient_mp3/alarms/doomsday_lift_alarm.mp3"

#define Sound_LVL_Absolute "sound/ls/lvl.wav"
#define Sound_Prestige_Absolute "sound/ls/prestige.wav"
#define Sound_Alarm_Absolute "sound/ambient_mp3/alarms/doomsday_lift_alarm.mp3"

#define MemberGroupID32 28307369
#define TesterGroupID32 29292279

enum LSPL
{
	LSPL_0,
	LSPL_1,
	LSPL_2,
	LSPL_3,
	LSPL_4,
	LSPL_5,
	LSPL_Count
}

enum LSRL
{
	LSRL_Admin,
	LSRL_Tester,
	LSRL_Donor,
	LSRL_Member,
	LSRL_Normal,
	LSRL_Count
}

enum LSPL_Multiplier
{
	float:LSPL_Multiplier_0 = 1.175,
	float:LSPL_Multiplier_1 = 1.185,
	float:LSPL_Multiplier_2 = 1.195,
	float:LSPL_Multiplier_3 = 1.20,
	float:LSPL_Multiplier_4 = 1.22,
	LSPL_Multiplier_Invalid
}

char LSPL_Titles[LSPL_Count][] = {

	"F",
	"D",
	"C",
	"B",
	"A",
	"S"

};

char LSRL_Titles[LSRL_Count][] = {

	"Chief",
	"Tester",
	"Spark",
	"Member",
	""

};

//<!-- Main -->
Database hDB;

bool Verbose;
bool IsLoaded[MAXPLAYERS + 1];

bool InMemberGroup[MAXPLAYERS + 1];
bool InTesterGroup[MAXPLAYERS + 1];

int XP_Gained[MAXPLAYERS + 1];

int XP[MAXPLAYERS + 1] = { -1, ... };
int Prestige[MAXPLAYERS + 1] = { -1, ... };
int Level[MAXPLAYERS + 1] = { -1, ... };

int XPAtLevel[MAXPLAYERS + 1] = { -1, ... };
int XPToNextLevel[MAXPLAYERS + 1] = { -1, ... };

Handle Progression_Hud;

Handle LevelForward;
Handle PrestigeForward;
Handle LoadedForward;

char ProgressBar[MAXPLAYERS + 1][64];
int colors[MAXPLAYERS + 1][3];

bool DoubleXP;

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
	
	char TableCreateSQL[] = "CREATE TABLE IF NOT EXISTS `Modular_LS` ( `id` INT NOT NULL AUTO_INCREMENT , `steamid` VARCHAR(32) NOT NULL , `name` VARCHAR(32) NOT NULL , `xp` BIGINT NOT NULL DEFAULT '0' , `prestige` TINYINT NOT NULL DEFAULT '0' , `creation_date` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP , PRIMARY KEY (`id`), INDEX (`prestige`), UNIQUE (`steamid`)) ENGINE = InnoDB CHARSET=utf8mb4 COLLATE utf8mb4_general_ci";
	
	SQL_SetCharset(hDB, "utf8mb4");
			
	hDB.Query(OnTableCreate, TableCreateSQL, _, DBPrio_High);
	
	RegPluginLibrary("Modular_LS");

	CreateNative("MLS_GetUserLevel", Native_GetUserLevel);
	CreateNative("MLS_GetUserPrestige", Native_GetUserPrestige);
	CreateNative("MLS_GetUserRank", Native_GetUserRank);
	CreateNative("MLS_GetPrestigeColorRGB", Native_GetPrestigeColorRGB);
	CreateNative("MLS_GetPrestigeColorHex", Native_GetPrestigeColorHex);
	CreateNative("MLS_GetPrestigeTitle", Native_GetPrestigeTitle);
	CreateNative("MLS_GetRankTitle", Native_GetRankTitle);
	CreateNative("MLS_AddXP", Native_AddXP);
	CreateNative("MLS_PrintToClient", Native_PrintToClient);
	CreateNative("MLS_IsLoaded", Native_IsLoaded);
	
	return APLRes_Success;
}

public void OnTableCreate(Database db, DBResultSet results, const char[] error, any pData)
{
	if (results == null)
	{
		EL_LogPlugin(LOG_FATAL, "Unable to create MLS table: %s", error);
		SetFailState("Unable to create table: %s", error);
	}
}

public void OnPluginStart()
{
	RegConsoleCmd("sm_prestige", CmdPrestige, "Prestige!");
	
	RegConsoleCmd("sm_top10", CmdTop10, "Displays Top 10");
	RegConsoleCmd("sm_rank", CmdRank, "Displays Current Rank");
	RegConsoleCmd("sm_session", CmdSession, "Displays Session Data");
	
	RegAdminCmd("sm_mls_dump", CmdDump, 0, "Dump user data");
	RegAdminCmd("sm_mls_debug", CmdToggleDebug, ADMFLAG_CHEATS, "Toggle Console Debugging");
	//RegAdminCmd("sm_mls_addxp", CmdAddXP, 0, "DEBUG: Add XP"); //TODO: REMOVE FOR RELEASE
	RegAdminCmd("sm_mls_setprestige", CmdSetPrestige, ADMFLAG_ROOT, "DEBUG: Set Prestige Level");
	RegAdminCmd("sm_mls_doublexp", CmdDoubleXP, ADMFLAG_ROOT, "Toggle Double XP Session");
	
	RegAdminCmd("mls_core_donor_permission", CmdVoid, ADMFLAG_RESERVATION);
	RegAdminCmd("mls_core_admin_permission", CmdVoid, ADMFLAG_GENERIC);
	
	Progression_Hud = CreateHudSynchronizer();
	
	LevelForward = CreateGlobalForward("MLS_OnClientLeveledUp", ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
	PrestigeForward = CreateGlobalForward("MLS_OnClientPrestige", ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
	LoadedForward = CreateGlobalForward("MLS_OnClientDataLoaded", ET_Ignore, Param_Cell);
}

public void OnMapStart()
{
	CreateTimer(0.5, Timer_Progression_Hud, _, TIMER_REPEAT);
	
	PrecacheSound(Sound_LVL, true);
	PrecacheSound(Sound_Prestige, true);	
	PrecacheSound(Sound_Alarm, true); //No need to download, already in TF2 assets
	
	AddFileToDownloadsTable(Sound_LVL_Absolute);
	AddFileToDownloadsTable(Sound_Prestige_Absolute);
}

public void OnMapEnd()
{
	DoubleXP = false;
}

public Action Timer_Progression_Hud(Handle hTimer)
{	
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (IsValidClient(iClient))
		{
			GetColorRGB(colors[iClient], iClient);
			SetHudTextParams(0.05, 0.10, 0.6, 0, colors[iClient][0], colors[iClient][1], colors[iClient][2], 0);
					
			if (Prestige[iClient] != MaxPL)
			{
				if (Level[iClient] == -1 || XPAtLevel[iClient] == -1 || XPToNextLevel[iClient] == -1)
					ShowSyncHudText(iClient, Progression_Hud, "N/A");
				else
				{
					GenerateProgressBar(XPAtLevel[iClient], XPToNextLevel[iClient], ProgressBar[iClient], sizeof ProgressBar[]);
					ShowSyncHudText(iClient, Progression_Hud, "[Lvl] %i: %s %i/%i %s", Level[iClient], ProgressBar[iClient], XPAtLevel[iClient], XPToNextLevel[iClient], (DoubleXP ? DoubleXPSymbol : ""));
				}
			} else
				ShowSyncHudText(iClient, Progression_Hud, "Reached Max Prestige: %i XP", XP[iClient]);
		}
	}
}

public Action CmdVoid(int client, int args)
{
	return Plugin_Handled;
}

public Action CmdTop10(int client, int args)
{
	ShowTop10(client);
	
	return Plugin_Handled;
}

public Action CmdRank(int client, int args)
{
	ShowRank(client);
	
	return Plugin_Handled;
}

public Action CmdSession(int client, int args)
{
	ShowSession(client);
	
	return Plugin_Handled;
}

public Action CmdDoubleXP(int client, int args)
{
	if (DoubleXP)
	{
		CReplyToCommand(client, "{lightseagreen}[MaxDB] {grey}Disabled Double XP Session");
		
		CPrintToChatAll("{lightseagreen}[MaxDB] {deeppink}DoubleXP Event was ended by {chartreuse}%N{deeppink}.", client);
	}
	else
	{
		CReplyToCommand(client, "{lightseagreen}[MaxDB] {grey}Enabled Double XP Session");
		
		CPrintToChatAll("{lightseagreen}[MaxDB] {deeppink}DoubleXP Event was started by {chartreuse}%N{deeppink}.", client);
		
		EmitSoundToAll(Sound_Alarm);
		EmitSoundToAll(Sound_Alarm);
	}
		
	DoubleXP = !DoubleXP;
	
	return Plugin_Handled;
}

public void OnClientSayCommand_Post(int client, const char[] command, const char[] sArgs)
{
	if (strcmp(command, "say") == 0 || strcmp(command, "say_team") == 0)
	{
		if (strcmp(sArgs, "top10") == 0)
			ShowTop10(client);
			
		if (strcmp(sArgs, "rank") == 0)
			ShowRank(client);
			
		if (strcmp(sArgs, "session") == 0)
			ShowSession(client);
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
	PrintToConsole(client, "TEST2: %i", InMemberGroup[client]);
	PrintToConsole(client, "TEST3: %i", InTesterGroup[client]);
	
	return Plugin_Handled;
}

public Action CmdPrestige(int client, int args)
{
	if (XP[client] == -1 || Prestige[client] == -1)
	{
		CReplyToCommand(client, "{lightseagreen}[MaxDB] {grey}Oops, unable to prestige.");
		
		return Plugin_Handled;
	}
		
	
	if (Prestige[client] >= MaxPL)
	{
		CReplyToCommand(client, "{lightseagreen}[MaxDB] {grey}You have reached the highest prestige!");
			
		return Plugin_Handled;
	}
	
	int UserLevel = GetUserLevel(client);
	
	if (UserLevel != MaxPLL || UserLevel == -1)
	{
		CReplyToCommand(client, "{lightseagreen}[MaxDB] {grey}You can only prestige at level %i!", MaxPLL);
			
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
	
	EmitSoundToClient(client, Sound_Prestige);
	EmitSoundToClient(client, Sound_Prestige);
	
	CPrintToChat(client, "{lightseagreen}[MaxDB] {grey}You have prestiged!");
	
	XP[client] = 0;
	Prestige[client]++;
	
	Call_StartForward(PrestigeForward);
	
	Call_PushCell(client);
	Call_PushCell(0); //Always 0 on prestige "XP[client] = 0;"
	Call_PushCell(Prestige[client]);
	
	Call_Finish();
	
	CalculateValues(client);
}

void ShowTop10(int client)
{
	char Select_Query[128];
	
	Format(Select_Query, sizeof Select_Query, "SELECT * FROM Modular_LS ORDER BY `prestige` DESC, `xp` DESC LIMIT 10");
	
	hDB.Query(SQL_OnShowTop10, Select_Query, client);
}

void ShowRank(int client)
{
	char Select_Query[512], Client_SteamID64[32];
	
	GetClientAuthId(client, AuthId_SteamID64, Client_SteamID64, sizeof Client_SteamID64);
	
	// MariaDB 10.x OR MySQL 8.x above only
	// Format(Select_Query, sizeof Select_Query, "SELECT rank, total FROM (SELECT ROW_NUMBER() OVER (ORDER BY `prestige` DESC, `xp` DESC) AS rank, (SELECT COUNT(*) FROM Modular_LS) AS total, steamid FROM Modular_LS) sub WHERE sub.steamid = '%s'", Client_SteamID64);
	
	// MariaDB 10.x OR MySQL 8.x below only
	Format(Select_Query, sizeof Select_Query, "SELECT sub.rank, sub.total FROM (SELECT t.id, t.steamid, @rownum := @rownum + 1 AS rank, (SELECT COUNT(*) FROM Modular_LS) AS total FROM Modular_LS t JOIN (SELECT @rownum := 0) r ORDER BY t.prestige DESC, t.xp DESC) sub WHERE sub.steamid = '%s'", Client_SteamID64);
	
	hDB.Query(SQL_OnShowRank, Select_Query, client);
}

void ShowSession(int client)
{
	char buffer[64];
	
	Panel Session = new Panel();
	
	Session.SetTitle("Current Session");
	
	Session.DrawItem("Name");
	GetClientName(client, buffer, sizeof buffer);
	Session.DrawText(buffer);
	
	Session.DrawItem("Rank");
	GetUserPrefix(client, buffer, sizeof buffer, true);
	Session.DrawText(buffer);
	
	Session.DrawItem("XP Gained");
	Format(buffer, sizeof buffer, "%i", XP_Gained[client]);
	Session.DrawText(buffer);
	
	Session.DrawItem("Session Time");
	int Client_Time = RoundToNearest(GetClientTime(client));
	Format(buffer, sizeof buffer, "%ih %im %is", Client_Time / 3600 % 24, Client_Time / 60 % 60, Client_Time % 60);
	Session.DrawText(buffer);
	
	Session.Send(client, VoidMenuHandler, MENU_TIME_FOREVER);
	
	delete Session;
}

public void SQL_OnShowRank(Database db, DBResultSet results, const char[] error, any client)
{
	if (results == null)
	{
		EL_LogPlugin(LOG_ERROR, "Unable to fetch player rank: %s", error);
		
		CPrintToChat(client, "{lightseagreen}[MaxDB] {grey}Unable to fetch your rank.");
		
		if (Verbose)
			PrintToConsole(client, "Query Error: %s", error);
		
		return;
	}
	
	results.FetchRow();
	
	char Hex_Name[16], Prefix[64], Client_Name[32];
	
	int Pos = results.FetchInt(0); //TODO: Sometimes invalid
	int Total = results.FetchInt(1);
	int Hex = GetColorHex(client);
	
	IntToString(Hex, Hex_Name, sizeof Hex_Name);
	
	CAddColor(Hex_Name, Hex);
	
	GetUserPrefix(client, Prefix, sizeof Prefix, true);
	GetClientName(client, Client_Name, sizeof Client_Name);
	
	CPrintToChatAll("{lightseagreen}[MaxDB] {grey}Player {lightseagreen}[{%s}%s{lightseagreen}] {chartreuse}%s {grey}is rank {aqua}%i {gray}out of {deepskyblue}%i{grey}.", Hex_Name, Prefix, Client_Name, Pos, Total);
}

public void SQL_OnShowTop10(Database db, DBResultSet results, const char[] error, any client)
{
	if (results == null)
	{
		EL_LogPlugin(LOG_ERROR, "Unable to fetch top 10: %s", error);
		
		CPrintToChat(client, "{lightseagreen}[MaxDB] {grey}Unable to fetch top 10 data.");
		
		if (Verbose)
			PrintToConsole(client, "Query Error: %s", error);
		
		return;
	}
	
	Panel Top10 = new Panel();
	
	char Position[128], Name[32], Prefix[64];
	
	int Prestige_Buffer, XP_Buffer, Index = 1;
	
	Top10.SetTitle("Top 10 Ranking");
	
	while (results.FetchRow())
	{
		results.FetchString(2, Name, sizeof Name);
		XP_Buffer = results.FetchInt(3);
		Prestige_Buffer = results.FetchInt(4);
		
		GetUserPrefixFromData(Prestige_Buffer, XP_Buffer, Prefix, sizeof Prefix);
		
		if (Index >= 10)
		{
			Format(Position, sizeof Position, "%i. %s - %s", Index, Name, Prefix);
			Top10.DrawText(Position);
		} else
		{
			Format(Position, sizeof Position, "%s - %s", Name, Prefix);
			Top10.DrawItem(Position);
		}
		
		Index++;
	}
	
	Top10.Send(client, VoidMenuHandler, MENU_TIME_FOREVER);
	
	delete Top10;
}

public int VoidMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	
}

public void OnClientPostAdminCheck(int client)
{
	if (!IsValidClientExcludeData(client))
		return;
		
	if (!IsClientConnected(client))
		return;
	
	char Select_Query[1024], Client_SteamID64[32];
	
	GetClientAuthId(client, AuthId_SteamID64, Client_SteamID64, sizeof Client_SteamID64);
	
	SteamWorks_GetUserGroupStatus(client, MemberGroupID32);
	SteamWorks_GetUserGroupStatus(client, TesterGroupID32);
	
	Format(Select_Query, sizeof Select_Query, "SELECT * FROM Modular_LS WHERE `steamid` = '%s'", Client_SteamID64);
	
	DataPack pData = CreateDataPack();
	WritePackCell(pData, client);
	WritePackString(pData, Client_SteamID64);
	
	hDB.Query(SQL_OnFetchPlayerData, Select_Query, pData);
}

public void OnClientDisconnect(int client)
{
	IsLoaded[client] = false;
	
	InMemberGroup[client] = false;
	InTesterGroup[client] = false;
	
	XP_Gained[client] = 0;
	
	XP[client] = -1;
	Prestige[client] = -1;
	Level[client] = -1;
	
	XPAtLevel[client] = -1;
	XPToNextLevel[client] = -1;
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
		char Client_SteamID64[32], Insert_Query[1024], Client_Name[32], Escaped_Client_Name[65];
	
		ReadPackString(pData, Client_SteamID64, sizeof Client_SteamID64);
		GetClientName(client, Client_Name, sizeof Client_Name);
		db.Escape(Client_Name, Escaped_Client_Name, sizeof Escaped_Client_Name);
		
		Format(Insert_Query, sizeof Insert_Query, "INSERT INTO Modular_LS (`steamid`, `name`) VALUES ('%s', '%s')", Client_SteamID64, Escaped_Client_Name);
		
		db.Query(SQL_OnCreatePlayerData, Insert_Query, client);
		
		return;
	}
	
	results.FetchRow();
	
	XP[client] = results.FetchInt(3);
	Prestige[client] = results.FetchInt(4);
	
	CalculateValues(client);
	
	IsLoaded[client] = true;
	
	Call_StartForward(LoadedForward);
	
	Call_PushCell(client);
	
	Call_Finish();
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
	
	IsLoaded[client] = true;
	
	Call_StartForward(LoadedForward);
	
	Call_PushCell(client);
	
	Call_Finish();
}

int GetXPValue(int client, int base_xp)
{
	float MaxBase = 1.0;
	
	if (InMemberGroup[client])
		MaxBase += 0.2;
	
	float SessionTime = GetClientTime(client);
	float MaxBonusMultiplier = ((MaxBonusHour * 0.5) + MaxBase);
	int MaxBonusSession = (60 * 60 * MaxBonusHour);
	int StandardXP;
	
	if (SessionTime >= MaxBonusSession)
		StandardXP = RoundToNearest(base_xp * MaxBonusMultiplier);
	else
		StandardXP = RoundToNearest(base_xp * ((SessionTime / MaxBonusSession) + MaxBase));
		
	if (DoubleXP)
		return (StandardXP * 2);
	else
		return StandardXP;
}

void AddXPToUser(int client, int xp)
{
	if (!CanGainXP(client))
		return;
	
	char Update_Query[1024], Client_SteamID64[32], Client_Name[32], Escaped_Client_Name[65];
	
	GetClientAuthId(client, AuthId_SteamID64, Client_SteamID64, sizeof Client_SteamID64);
	GetClientName(client, Client_Name, sizeof Client_Name);
	
	hDB.Escape(Client_Name, Escaped_Client_Name, sizeof Escaped_Client_Name);
	
	Format(Update_Query, sizeof Update_Query, "UPDATE Modular_LS SET `xp` = `xp` + '%u', `name` = '%s' WHERE `steamid` = '%s'", xp, Escaped_Client_Name, Client_SteamID64);
	
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
	XP_Gained[client] += xp;
	
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

LSPL_Multiplier GetMultiplierByPrestigeData(int prestige_data)
{	
	switch (prestige_data)
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
	
	if (UserLevel >= MaxPLL)
	{
		if (Prestige[client] >= MaxPL) //Allow progressing further but no levels
			return true;
		else
		{
			if (Verbose)
				CPrintToChat(client, "{lightseagreen}[MaxDB] {grey}In order to earn more levels, prestige first!");
			
			return false;
		}
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
	
	if (Level[client] >= MaxPLL)
	{
		int MaxXPAtCurrent = GetXPFromLevel(MaxPLL, Multiplier);
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
		Call_StartForward(LevelForward);
		
		Call_PushCell(client);
		Call_PushCell(Level[client]);
		Call_PushCell(Prestige[client]);
		
		Call_Finish();
		
		EmitSoundToClient(client, Sound_LVL);
		EmitSoundToClient(client, Sound_LVL);
		
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
	
	int result = GetLevelFromXP(XP[client], multiplier);
	
	if (result >= MaxPLL)
		return MaxPLL;
	else
		return result;
}

void GetUserPrefixFromData(int prestige, int xp, char[] buffer, int size)
{
	LSPL_Multiplier Multiplier = GetMultiplierByPrestigeData(prestige);
	
	int Level_Buffer = GetLevelFromXP(xp, Multiplier);
	
	if (prestige >= MaxPL)
		Format(buffer, size, "%s", LSPL_Titles[prestige]);
	else
		Format(buffer, size, "%s%i", LSPL_Titles[prestige], Level_Buffer);
}

void GetUserPrefix(int client, char[] buffer, int size, bool rank = false)
{	
	if (rank)
		if (Prestige[client] >= MaxPL)
			if (StrEqual(LSRL_Titles[view_as<int>(GetUserRank(client))], ""))
				Format(buffer, size, "%s", LSPL_Titles[Prestige[client]]);
			else
				Format(buffer, size, "%s %s", LSRL_Titles[view_as<int>(GetUserRank(client))], LSPL_Titles[Prestige[client]]);
		else
			if (StrEqual(LSRL_Titles[view_as<int>(GetUserRank(client))], ""))
				Format(buffer, size, "%s%i", LSPL_Titles[Prestige[client]], Level[client]);
			else
				Format(buffer, size, "%s %s%i", LSRL_Titles[view_as<int>(GetUserRank(client))], LSPL_Titles[Prestige[client]], Level[client]);
	else
		if (Prestige[client] >= MaxPL)
			Format(buffer, size, "%s", LSPL_Titles[Prestige[client]]);
		else
			Format(buffer, size, "%s%i", LSPL_Titles[Prestige[client]], Level[client]);
}

int GetLevelFromXP(int xp, LSPL_Multiplier multiplier)
{
	if (xp < BaseXP)
		return 0;
		
	int calculated_level = RoundToFloor( 1 + Logarithm(xp / BaseXP, view_as<float>(multiplier)));
	
	if (calculated_level > MaxPLL)
		return MaxPLL;
	else
		return calculated_level;
}

int GetXPFromLevel(int level, LSPL_Multiplier multiplier)
{
	return RoundToCeil(BaseXP * Pow(view_as<float>(multiplier), (level - 1) * 1.0));
}

stock int GetXPFromUserLevel(int level, int client)
{
	LSPL_Multiplier Multiplier = GetMultiplierByPrestige(client);
	
	return GetXPFromLevel(level, Multiplier);
}

bool IsValidClient(int iClient, bool bAlive = false)
{
	if (iClient >= 1 && iClient <= MaxClients && IsClientConnected(iClient) && IsClientInGame(iClient) && !IsFakeClient(iClient) && XP[iClient] != -1 && Prestige[iClient] != -1 && (bAlive == false || IsPlayerAlive(iClient)))
	{
		return true;
	}

	return false;
}

bool IsValidClientExcludeData(int iClient, bool bAlive = false)
{
	if (iClient >= 1 && iClient <= MaxClients && IsClientConnected(iClient) && IsClientInGame(iClient) && !IsFakeClient(iClient) && (bAlive == false || IsPlayerAlive(iClient)))
	{
		return true;
	}

	return false;
}

void GenerateProgressBar(int value, int base, char[] buffer, int size)
{
	Format(buffer, size, "");
	
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
			return 0xb8860b;
		case 3:
			return 0x0eedc7;
		case 4:
			return 0x9e1414;
		case 5:
			return 0xd32ce6;
		default:
			return 0xd3d3dd;
	}
	
	return 0xd3d3dd;
}

LSRL GetUserRank(int client)
{
	if (CheckCommandAccess(client, "mls_core_admin_permission", ADMFLAG_GENERIC))
		return LSRL_Admin;
		
	if (InTesterGroup[client])
		return LSRL_Tester;
		
	if (CheckCommandAccess(client, "mls_core_donor_permission", ADMFLAG_RESERVATION))
		return LSRL_Donor;
		
	if (InMemberGroup[client])
		return LSRL_Member;
		
	return LSRL_Normal;
}

public int SteamWorks_OnClientGroupStatus(int authid, int groupid, bool isMember, bool isOfficer)
{
	
	if (groupid != MemberGroupID32 && groupid != TesterGroupID32)
		return;
	
	int iClient = GetUserFromAuthID(authid);	
	
	if (iClient == -1 || !IsValidClientExcludeData(iClient))
		return;
			
	if (isMember || isOfficer)
	{
		if (groupid == MemberGroupID32)
			InMemberGroup[iClient] = true;
		if (groupid == TesterGroupID32)
			InTesterGroup[iClient] = true;
	}
}

//In cases where Steamtools is also loaded and Steamworks fails to see the callback
public int Steam_GroupStatusResult(int client, int groupAccountID, bool groupMember, bool groupOfficer)
{
	
	if (groupAccountID != MemberGroupID32 && groupAccountID != TesterGroupID32)
		return;	
		
	if (!IsValidClientExcludeData(client))
		return;
			
	if (groupMember || groupOfficer)
	{
		if (groupAccountID == MemberGroupID32)
			InMemberGroup[client] = true;
		if (groupAccountID == TesterGroupID32)
			InTesterGroup[client] = true;
	}
}

public int GetUserFromAuthID(int authid)
{
    for (int i = 1; i <= MaxClients; i++)
    {
        if(IsClientInGame(i))
        {
            char charauth[64];
            GetClientAuthId(i, AuthId_Steam3, charauth, sizeof(charauth));
               
            char charauth2[64];
            IntToString(authid, charauth2, sizeof(charauth2));
           
            if(StrContains(charauth, charauth2, false) > -1)
            {
                return i;
            }
        }
    }
    return -1;
}

public int Native_GetUserLevel(Handle plugin, int numParams)
{
	if (numParams < 1)
		return ThrowNativeError(SP_ERROR_NATIVE, "Missing client parameter");
	
	int client = GetNativeCell(1);
	
	if (!IsValidClient(client))
		return ThrowNativeError(SP_ERROR_NATIVE, "Client %d is not valid", client);
		
	return Level[client];
}

public int Native_GetUserPrestige(Handle plugin, int numParams)
{
	if (numParams < 1)
		return ThrowNativeError(SP_ERROR_NATIVE, "Missing client parameter");
	
	int client = GetNativeCell(1);
	
	if (!IsValidClient(client))
		return ThrowNativeError(SP_ERROR_NATIVE, "Client %d is not valid", client);
		
	return Prestige[client];
}

public int Native_GetUserRank(Handle plugin, int numParams)
{
	if (numParams < 1)
		return ThrowNativeError(SP_ERROR_NATIVE, "Missing client parameter");
	
	int client = GetNativeCell(1);
	
	if (!IsValidClient(client))
		return ThrowNativeError(SP_ERROR_NATIVE, "Client %d is not valid", client);
		
	return view_as<int>(GetUserRank(client));
}

public int Native_GetPrestigeColorRGB(Handle plugin, int numParams)
{
	if (numParams < 2)
		return ThrowNativeError(SP_ERROR_NATIVE, "Missing parameter(s)");
		
	int client = GetNativeCell(2);
	
	if (!IsValidClient(client))
		return ThrowNativeError(SP_ERROR_NATIVE, "Client %d is not valid", client);
	
	int color_buffer[3];
	
	GetColorRGB(color_buffer, client);
	
	SetNativeArray(1, color_buffer, sizeof color_buffer);
	
	return 0;
}

public int Native_GetPrestigeColorHex(Handle plugin, int numParams)
{
	if (numParams < 1)
		return ThrowNativeError(SP_ERROR_NATIVE, "Missing parameter(s)");
		
	int client = GetNativeCell(1);
	
	if (!IsValidClient(client))
		return ThrowNativeError(SP_ERROR_NATIVE, "Client %d is not valid", client);
	
	return GetColorHex(client);
}

public int Native_GetPrestigeTitle(Handle plugin, int numParams)
{
	if (numParams < 3)
		return ThrowNativeError(SP_ERROR_NATIVE, "Missing parameter(s)");
		
	int client = GetNativeCell(3);
	
	if (!IsValidClient(client))
		return ThrowNativeError(SP_ERROR_NATIVE, "Client %d is not valid", client);
		
	int buffer_size = GetNativeCell(2);
	
	SetNativeString(1, LSPL_Titles[Prestige[client]], buffer_size);
	
	return 0;
}

public int Native_GetRankTitle(Handle plugin, int numParams)
{
	if (numParams < 3)
		return ThrowNativeError(SP_ERROR_NATIVE, "Missing parameter(s)");
		
	int client = GetNativeCell(3);
	
	if (!IsValidClient(client))
		return ThrowNativeError(SP_ERROR_NATIVE, "Client %d is not valid", client);
		
	int buffer_size = GetNativeCell(2);
	
	SetNativeString(1, LSRL_Titles[view_as<int>(GetUserRank(client))], buffer_size);
	
	return 0;
}

public int Native_AddXP(Handle plugin, int numParams)
{
	if (numParams < 3)
		return ThrowNativeError(SP_ERROR_NATIVE, "Missing parameter(s)");
		
	int client = GetNativeCell(1);
	
	if (!IsValidClient(client))
		return ThrowNativeError(SP_ERROR_NATIVE, "Client %d is not valid", client);
	
	if (!CanGainXP(client))
		return -1;
		
	int buffer = GetNativeCell(2);
		
	if (buffer < 0)
		return ThrowNativeError(SP_ERROR_NATIVE, "Cannot add negative XP");
		
	bool bonus = GetNativeCell(3);
		
	if (bonus)
		buffer = GetXPValue(client, buffer);
	
	AddXPToUser(client, buffer);
	
	return 1;
}

public int Native_PrintToClient(Handle plugin, int numParams)
{
	if (numParams < 2)
		return ThrowNativeError(SP_ERROR_NATIVE, "Missing parameter(s)");
		
	int client = GetNativeCell(1);
	
	if (!IsValidClient(client))
		return ThrowNativeError(SP_ERROR_NATIVE, "Client %d is not valid", client);
		
	char buffer[254];
		
	FormatNativeString(0, 2, 3, sizeof buffer, _, buffer);
	
	CPrintToChat(client, "{lightseagreen}[MaxDB] {grey}%s", buffer);
	
	return 0;
}

public int Native_IsLoaded(Handle plugin, int numParams)
{
	if (numParams < 1)
		return ThrowNativeError(SP_ERROR_NATIVE, "Missing parameter(s)");
		
	int client = GetNativeCell(1);
	
	if (!IsValidClientExcludeData(client))
		return ThrowNativeError(SP_ERROR_NATIVE, "Client %d is not valid", client);
		
	return IsLoaded[client];
}
