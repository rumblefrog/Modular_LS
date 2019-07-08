#pragma semicolon 1

#define PLUGIN_AUTHOR "Fishy"
#define PLUGIN_VERSION "2.0.0"

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

// Prestige is 0 indexed
int g_iPrestigeColors[MaxPL + 1][3] = {
	{ 211, 218, 229 },
	{ 50,  10,  141 },
	{ 184, 134, 11 },
	{ 14,  237, 199 },
	{ 158, 20,  20 },
	{ 211, 44,  230 },
};

int g_iPrestigeDefaultColor[3] = { 211, 211, 211 };

//<!-- Main -->
Database hDB;

bool Verbose;

Handle Progression_Hud;

Handle LevelForward;
Handle PrestigeForward;
Handle LoadedForward;

bool DoubleXP;

enum struct Player {
	bool bIsLoaded;

	bool bInMemberGroup;
	bool bInTesterGroup;

	int iXPGained;
	int iXP;
	int iPrestige;
	int iLevel;

	int iXPAtLevel;
	int iXPToNextLevel;

	char sProgressBar[64];

	int iColors[3];

	void UpdateColors() {
		if (this.iPrestige > MaxPL) {
			this.iColors[0] = g_iPrestigeDefaultColor[0];
			this.iColors[1] = g_iPrestigeDefaultColor[1];
			this.iColors[2] = g_iPrestigeDefaultColor[2];

			return;
		}

		this.iColors[0] = g_iPrestigeColors[this.iPrestige][0];
		this.iColors[1] = g_iPrestigeColors[this.iPrestige][1];
		this.iColors[2] = g_iPrestigeColors[this.iPrestige][2];
	}

	// Incase we don't want foreign plugins to modify it
	void CloneColors(iColors[3]) {
		this.UpdateColors();

		iColors[0] = this.iColors[0];
		iColors[1] = this.iColors[1];
		iColors[2] = this.iColors[2];
	}
}

Player g_pPlayers[MAXPLAYERS + 1];

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
			g_pPlayers[iClient].UpdateColors();

			SetHudTextParams(0.05, 0.10, 0.6, 0, g_pPlayers[iClient].iColors[0], g_pPlayers[iClient].iColors[1], g_pPlayers[iClient].iColors[2], 0);
					
			if (g_pPlayers[iClient].iPrestige != MaxPL)
			{
				if (g_pPlayers[iClient].iLevel == -1 || g_pPlayers[iClient].iXPAtLevel == -1 || g_pPlayers[iClient].iXPToNextLevel == -1)
					ShowSyncHudText(iClient, Progression_Hud, "N/A");
				else
				{
					GenerateProgressBar(g_pPlayers[iClient].iXPAtLevel, g_pPlayers[iClient].iXPToNextLevel, g_pPlayers[iClient].sProgressBar, sizeof Player::sProgressBar);
					ShowSyncHudText(iClient, Progression_Hud, "[Lvl] %i: %s %i/%i %s", g_pPlayers[iClient].iLevel, g_pPlayers[iClient].sProgressBar, g_pPlayers[iClient].iXPAtLevel, g_pPlayers[iClient].iXPToNextLevel, (DoubleXP ? DoubleXPSymbol : ""));
				}
			} else
				ShowSyncHudText(iClient, Progression_Hud, "Reached Max Prestige: %i XP", g_pPlayers[iClient].iXP);
		}
	}
}

public Action CmdVoid(int iClient, int args)
{
	return Plugin_Handled;
}

public Action CmdTop10(int iClient, int args)
{
	ShowTop10(iClient);
	
	return Plugin_Handled;
}

public Action CmdRank(int iClient, int args)
{
	ShowRank(iClient);
	
	return Plugin_Handled;
}

public Action CmdSession(int iClient, int args)
{
	ShowSession(iClient);
	
	return Plugin_Handled;
}

public Action CmdDoubleXP(int iClient, int args)
{
	if (DoubleXP)
	{
		CReplyToCommand(iClient, "{lightseagreen}[MaxDB] {grey}Disabled Double XP Session");
		
		CPrintToChatAll("{lightseagreen}[MaxDB] {deeppink}DoubleXP Event was ended by {chartreuse}%N{deeppink}.", iClient);
	}
	else
	{
		CReplyToCommand(iClient, "{lightseagreen}[MaxDB] {grey}Enabled Double XP Session");
		
		CPrintToChatAll("{lightseagreen}[MaxDB] {deeppink}DoubleXP Event was started by {chartreuse}%N{deeppink}.", iClient);
		
		EmitSoundToAll(Sound_Alarm);
		EmitSoundToAll(Sound_Alarm);
	}
		
	DoubleXP = !DoubleXP;
	
	return Plugin_Handled;
}

public void OnClientSayCommand_Post(int iClient, const char[] command, const char[] sArgs)
{
	if (strcmp(command, "say") == 0 || strcmp(command, "say_team") == 0)
	{
		if (strcmp(sArgs, "top10") == 0)
			ShowTop10(iClient);
			
		if (strcmp(sArgs, "rank") == 0)
			ShowRank(iClient);
			
		if (strcmp(sArgs, "session") == 0)
			ShowSession(iClient);
	}
}

public Action CmdToggleDebug(int iClient, int args)
{
	if (!Verbose)
		CReplyToCommand(iClient, "{lightseagreen}[MaxDB] {grey}Enabled verbose logging");
	else
		CReplyToCommand(iClient, "{lightseagreen}[MaxDB] {grey}Disabled verbose logging");
		
	Verbose = !Verbose;
	
	return Plugin_Handled;
}

public Action CmdAddXP(int iClient, int args)
{
	if (args < 1)
	{
		CReplyToCommand(iClient, "{lightseagreen}[MaxDB] {grey}Missing XP");
		
		return Plugin_Handled;
	}
	
	if (!CanGainXP(iClient))
	{
		CReplyToCommand(iClient, "{lightseagreen}[MaxDB] {grey}Cannot gain XP");
		
		return Plugin_Handled;
	}
	
	char buffer[16];
	
	GetCmdArg(1, buffer, sizeof buffer);
	
	int input = StringToInt(buffer);
	
	int EXP = GetXPValue(iClient, input);
	
	AddXPToUser(iClient, EXP);
	
	CReplyToCommand(iClient, "{lightseagreen}[MaxDB] {grey}Requested %i XP to be added", EXP);
	
	return Plugin_Handled;
}

public Action CmdSetPrestige(int iClient, int args)
{
	if (args < 1)
	{
		CReplyToCommand(iClient, "{lightseagreen}[MaxDB] {grey}Missing Prestige");
		
		return Plugin_Handled;
	}
	
	char buffer[16];
	
	GetCmdArg(1, buffer, sizeof buffer);
	
	int prestigel = StringToInt(buffer);
	
	g_pPlayers[iClient].iPrestige = prestigel;
	
	return Plugin_Handled;
}

public Action CmdDump(int iClient, int args)
{
	PrintToConsole(iClient, "Base: %f", BaseXP);
	PrintToConsole(iClient, "XP: %i", g_pPlayers[iClient].iXP);
	PrintToConsole(iClient, "Prestige: %i", g_pPlayers[iClient].iPrestige);
	PrintToConsole(iClient, "Prestige Multiplier: %f", view_as<float>(GetMultiplierByPrestige(iClient)));
	PrintToConsole(iClient, "Level: %i", g_pPlayers[iClient].iLevel);
	PrintToConsole(iClient, "XPAtLevel: %i", g_pPlayers[iClient].iXPAtLevel);
	PrintToConsole(iClient, "XPToNextLevel: %i", g_pPlayers[iClient].iXPToNextLevel);
	
	PrintToConsole(iClient, "<-------------------------->");
	
	PrintToConsole(iClient, "TEST1: %f", g_pPlayers[iClient].iXP / BaseXP);
	PrintToConsole(iClient, "TEST2: %i", g_pPlayers[iClient].bInMemberGroup);
	PrintToConsole(iClient, "TEST3: %i", g_pPlayers[iClient].bInTesterGroup);
	
	return Plugin_Handled;
}

public Action CmdPrestige(int iClient, int args)
{
	if (g_pPlayers[iClient].iXP == -1 || g_pPlayers[iClient].iPrestige == -1)
	{
		CReplyToCommand(iClient, "{lightseagreen}[MaxDB] {grey}Oops, unable to prestige.");
		
		return Plugin_Handled;
	}
		
	
	if (g_pPlayers[iClient].iPrestige >= MaxPL)
	{
		CReplyToCommand(iClient, "{lightseagreen}[MaxDB] {grey}You have reached the highest prestige!");
			
		return Plugin_Handled;
	}
	
	int UserLevel = GetUserLevel(iClient);
	
	if (UserLevel != MaxPLL || UserLevel == -1)
	{
		CReplyToCommand(iClient, "{lightseagreen}[MaxDB] {grey}You can only prestige at level %i!", MaxPLL);
			
		return Plugin_Handled;
	}

	char Update_Query[1024], Client_SteamID64[32];
	
	GetClientAuthId(iClient, AuthId_SteamID64, Client_SteamID64, sizeof Client_SteamID64);
	
	Format(Update_Query, sizeof Update_Query, "UPDATE Modular_LS SET `xp` = 0, `prestige`= `prestige` + 1 WHERE `steamid` = '%s'", Client_SteamID64);
	
	DataPack pData = CreateDataPack();
	
	WritePackCell(pData, GetCmdReplySource());
	WritePackCell(pData, iClient);
	
	hDB.Query(SQL_OnPlayerPrestige, Update_Query, pData);
	
	return Plugin_Handled;
}

public void SQL_OnPlayerPrestige(Database db, DBResultSet results, const char[] error, any pData)
{
	ResetPack(pData);
	
	ReplySource CmdOrigin = ReadPackCell(pData);
	int iClient = ReadPackCell(pData);
	
	SetCmdReplySource(CmdOrigin);
	
	if (results == null)
	{
		ReplyToCommand(iClient, "Fail to prestige, please try again later");
		return;
	}
	
	EmitSoundToClient(iClient, Sound_Prestige);
	EmitSoundToClient(iClient, Sound_Prestige);
	
	CPrintToChat(iClient, "{lightseagreen}[MaxDB] {grey}You have prestiged!");
	
	g_pPlayers[iClient].iXP = 0;
	g_pPlayers[iClient].iPrestige++;
	
	Call_StartForward(PrestigeForward);
	
	Call_PushCell(iClient);
	Call_PushCell(0); //Always 0 on prestige "g_pPlayers[iClient].iXP = 0;"
	Call_PushCell(g_pPlayers[iClient].iPrestige);
	
	Call_Finish();
	
	CalculateValues(iClient);
}

void ShowTop10(int iClient)
{
	char Select_Query[128];
	
	Format(Select_Query, sizeof Select_Query, "SELECT * FROM Modular_LS ORDER BY `prestige` DESC, `xp` DESC LIMIT 10");
	
	hDB.Query(SQL_OnShowTop10, Select_Query, iClient);
}

void ShowRank(int iClient)
{
	char Select_Query[512], Client_SteamID64[32];
	
	GetClientAuthId(iClient, AuthId_SteamID64, Client_SteamID64, sizeof Client_SteamID64);
	
	// MariaDB 10.x OR MySQL 8.x above only
	// Format(Select_Query, sizeof Select_Query, "SELECT rank, total FROM (SELECT ROW_NUMBER() OVER (ORDER BY `prestige` DESC, `xp` DESC) AS rank, (SELECT COUNT(*) FROM Modular_LS) AS total, steamid FROM Modular_LS) sub WHERE sub.steamid = '%s'", Client_SteamID64);
	
	// MariaDB 10.x OR MySQL 8.x below only
	Format(Select_Query, sizeof Select_Query, "SELECT sub.rank, sub.total FROM (SELECT t.id, t.steamid, @rownum := @rownum + 1 AS rank, (SELECT COUNT(*) FROM Modular_LS) AS total FROM Modular_LS t JOIN (SELECT @rownum := 0) r ORDER BY t.prestige DESC, t.xp DESC) sub WHERE sub.steamid = '%s'", Client_SteamID64);
	
	hDB.Query(SQL_OnShowRank, Select_Query, iClient);
}

void ShowSession(int iClient)
{
	char buffer[64];
	
	Panel Session = new Panel();
	
	Session.SetTitle("Current Session");
	
	Session.DrawItem("Name");
	GetClientName(iClient, buffer, sizeof buffer);
	Session.DrawText(buffer);
	
	Session.DrawItem("Rank");
	GetUserPrefix(iClient, buffer, sizeof buffer, true);
	Session.DrawText(buffer);
	
	Session.DrawItem("XP Gained");
	Format(buffer, sizeof buffer, "%i", g_pPlayers[iClient].iXPGained);
	Session.DrawText(buffer);
	
	Session.DrawItem("Session Time");
	int Client_Time = RoundToNearest(GetClientTime(iClient));
	Format(buffer, sizeof buffer, "%ih %im %is", Client_Time / 3600 % 24, Client_Time / 60 % 60, Client_Time % 60);
	Session.DrawText(buffer);
	
	Session.Send(iClient, VoidMenuHandler, MENU_TIME_FOREVER);
	
	delete Session;
}

public void SQL_OnShowRank(Database db, DBResultSet results, const char[] error, any iClient)
{
	if (results == null)
	{
		EL_LogPlugin(LOG_ERROR, "Unable to fetch player rank: %s", error);
		
		CPrintToChat(iClient, "{lightseagreen}[MaxDB] {grey}Unable to fetch your rank.");
		
		if (Verbose)
			PrintToConsole(iClient, "Query Error: %s", error);
		
		return;
	}
	
	results.FetchRow();
	
	char Hex_Name[16], Prefix[64], Client_Name[32];
	
	int Pos = results.FetchInt(0); //TODO: Sometimes invalid
	int Total = results.FetchInt(1);
	int Hex = GetColorHex(iClient);
	
	IntToString(Hex, Hex_Name, sizeof Hex_Name);
	
	CAddColor(Hex_Name, Hex);
	
	GetUserPrefix(iClient, Prefix, sizeof Prefix, true);
	GetClientName(iClient, Client_Name, sizeof Client_Name);
	
	CPrintToChatAll("{lightseagreen}[MaxDB] {grey}Player {lightseagreen}[{%s}%s{lightseagreen}] {chartreuse}%s {grey}is rank {aqua}%i {gray}out of {deepskyblue}%i{grey}.", Hex_Name, Prefix, Client_Name, Pos, Total);
}

public void SQL_OnShowTop10(Database db, DBResultSet results, const char[] error, any iClient)
{
	if (results == null)
	{
		EL_LogPlugin(LOG_ERROR, "Unable to fetch top 10: %s", error);
		
		CPrintToChat(iClient, "{lightseagreen}[MaxDB] {grey}Unable to fetch top 10 data.");
		
		if (Verbose)
			PrintToConsole(iClient, "Query Error: %s", error);
		
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
	
	Top10.Send(iClient, VoidMenuHandler, MENU_TIME_FOREVER);
	
	delete Top10;
}

public int VoidMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	
}

public void OnClientPostAdminCheck(int iClient)
{
	if (!IsValidClientExcludeData(iClient))
		return;
		
	if (!IsClientConnected(iClient))
		return;
	
	char Select_Query[1024], Client_SteamID64[32];
	
	GetClientAuthId(iClient, AuthId_SteamID64, Client_SteamID64, sizeof Client_SteamID64);
	
	SteamWorks_GetUserGroupStatus(iClient, MemberGroupID32);
	SteamWorks_GetUserGroupStatus(iClient, TesterGroupID32);
	
	Format(Select_Query, sizeof Select_Query, "SELECT * FROM Modular_LS WHERE `steamid` = '%s'", Client_SteamID64);
	
	DataPack pData = CreateDataPack();
	WritePackCell(pData, iClient);
	WritePackString(pData, Client_SteamID64);
	
	hDB.Query(SQL_OnFetchPlayerData, Select_Query, pData);
}

public void OnClientDisconnect(int iClient)
{
	g_pPlayers[iClient].bIsLoaded = false;
	
	g_pPlayers[iClient].bInMemberGroup = false;
	g_pPlayers[iClient].bInTesterGroup = false;
	
	g_pPlayers[iClient].iXPGained = 0;
	
	g_pPlayers[iClient].iXP = -1;
	g_pPlayers[iClient].iPrestige = -1;
	g_pPlayers[iClient].iLevel = -1;
	
	g_pPlayers[iClient].iXPAtLevel = -1;
	g_pPlayers[iClient].iXPToNextLevel = -1;
}

public void SQL_OnFetchPlayerData(Database db, DBResultSet results, const char[] error, any pData)
{
	if (results == null)
	{
		EL_LogPlugin(LOG_ERROR, "Unable to fetch player data: %s", error);
		return;
	}
	
	ResetPack(pData);
	
	int iClient = ReadPackCell(pData);
	
	if (results.RowCount == 0)
	{
		char Client_SteamID64[32], Insert_Query[1024], Client_Name[32], Escaped_Client_Name[65];
	
		ReadPackString(pData, Client_SteamID64, sizeof Client_SteamID64);
		GetClientName(iClient, Client_Name, sizeof Client_Name);
		db.Escape(Client_Name, Escaped_Client_Name, sizeof Escaped_Client_Name);
		
		Format(Insert_Query, sizeof Insert_Query, "INSERT INTO Modular_LS (`steamid`, `name`) VALUES ('%s', '%s')", Client_SteamID64, Escaped_Client_Name);
		
		db.Query(SQL_OnCreatePlayerData, Insert_Query, iClient);
		
		return;
	}
	
	results.FetchRow();
	
	g_pPlayers[iClient].iXP = results.FetchInt(3);
	g_pPlayers[iClient].iPrestige = results.FetchInt(4);
	
	CalculateValues(iClient);
	
	g_pPlayers[iClient].bIsLoaded = true;
	
	Call_StartForward(LoadedForward);
	
	Call_PushCell(iClient);
	
	Call_Finish();
}

public void SQL_OnCreatePlayerData(Database db, DBResultSet results, const char[] error, any iClient)
{
	if (results == null)
	{
		EL_LogPlugin(LOG_ERROR, "Unable to create player data: %s", error);
		
		if (Verbose)
			PrintToConsole(iClient, "Unable to create player data: %s", error);
	}
	
	g_pPlayers[iClient].iXP = 0;
	g_pPlayers[iClient].iPrestige = 0;
	
	CalculateValues(iClient);
	
	g_pPlayers[iClient].bIsLoaded = true;
	
	Call_StartForward(LoadedForward);
	
	Call_PushCell(iClient);
	
	Call_Finish();
}

int GetXPValue(int iClient, int base_xp)
{
	float MaxBase = 1.0;
	
	if (g_pPlayers[iClient].bInMemberGroup)
		MaxBase += 0.2;
	
	float SessionTime = GetClientTime(iClient);
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

void AddXPToUser(int iClient, int xp)
{
	if (!CanGainXP(iClient))
		return;
	
	char Update_Query[1024], Client_SteamID64[32], Client_Name[32], Escaped_Client_Name[65];
	
	GetClientAuthId(iClient, AuthId_SteamID64, Client_SteamID64, sizeof Client_SteamID64);
	GetClientName(iClient, Client_Name, sizeof Client_Name);
	
	hDB.Escape(Client_Name, Escaped_Client_Name, sizeof Escaped_Client_Name);
	
	Format(Update_Query, sizeof Update_Query, "UPDATE Modular_LS SET `xp` = `xp` + '%u', `name` = '%s' WHERE `steamid` = '%s'", xp, Escaped_Client_Name, Client_SteamID64);
	
	DataPack pData = CreateDataPack();
	WritePackCell(pData, iClient);
	WritePackCell(pData, xp);
	
	hDB.Query(SQL_OnAddXPToUser, Update_Query, pData);
}

public void SQL_OnAddXPToUser(Database db, DBResultSet results, const char[] error, any pData)
{
	ResetPack(pData);
	int iClient = ReadPackCell(pData);
	int xp = ReadPackCell(pData);
	
	if (results == null)
	{
		EL_LogPlugin(LOG_ERROR, "Unable to add XP to player: %s", error);
		
		if (Verbose)
			PrintToConsole(pData, "Unable to add XP to player: %s", error);
	}
	
	g_pPlayers[iClient].iXP += xp;
	g_pPlayers[iClient].iXPGained += xp;
	
	CalculateValues(iClient);
}

LSPL_Multiplier GetMultiplierByPrestige(int iClient)
{
	if (!IsValidClient(iClient))
		return LSPL_Multiplier_Invalid;
	
	switch (g_pPlayers[iClient].iPrestige)
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
}

bool CanGainXP(int iClient)
{
	if (g_pPlayers[iClient].iXP == -1 || g_pPlayers[iClient].iPrestige == -1)
		return false;
		
	int UserLevel = GetUserLevel(iClient);
	
	if (UserLevel == -1)
	{
		if (Verbose)
			CPrintToChat(iClient, "{lightseagreen}[MaxDB] {grey}Invalid Level.");
			
		return false;
	}
	
	CalculateValues(iClient);
	
	if (UserLevel >= MaxPLL)
	{
		if (g_pPlayers[iClient].iPrestige >= MaxPL) //Allow progressing further but no levels
			return true;
		else
		{
			if (Verbose)
				CPrintToChat(iClient, "{lightseagreen}[MaxDB] {grey}In order to earn more levels, prestige first!");
			
			return false;
		}
	}
		
	return true;
}

void CalculateValues(int iClient)
{
	int OriginLevel = g_pPlayers[iClient].iLevel;
	
	g_pPlayers[iClient].iLevel = GetUserLevel(iClient);
	
	if (g_pPlayers[iClient].iLevel == -1)
	{
		g_pPlayers[iClient].iXPToNextLevel = -1;
		g_pPlayers[iClient].iXPAtLevel = -1;
		return;
	}
	
	LSPL_Multiplier Multiplier = GetMultiplierByPrestige(iClient);
	
	if (Multiplier == LSPL_Multiplier_Invalid)
	{
		g_pPlayers[iClient].iXPToNextLevel = -1;
		g_pPlayers[iClient].iXPAtLevel = -1;
		return;
	}
	
	if (g_pPlayers[iClient].iLevel >= MaxPLL)
	{
		int MaxXPAtCurrent = GetXPFromLevel(MaxPLL, Multiplier);
		g_pPlayers[iClient].iXPToNextLevel = MaxXPAtCurrent;
		g_pPlayers[iClient].iXPAtLevel = MaxXPAtCurrent;
		return;
	}
	
	if (g_pPlayers[iClient].iXP < BaseXP)		
	{		
		g_pPlayers[iClient].iXPToNextLevel = 10;		
		g_pPlayers[iClient].iXPAtLevel = 0;
		return;
	}
	
	if (OriginLevel != -1 && g_pPlayers[iClient].iLevel > OriginLevel)
	{
		Call_StartForward(LevelForward);
		
		Call_PushCell(iClient);
		Call_PushCell(g_pPlayers[iClient].iLevel);
		Call_PushCell(g_pPlayers[iClient].iPrestige);
		
		Call_Finish();
		
		EmitSoundToClient(iClient, Sound_LVL);
		EmitSoundToClient(iClient, Sound_LVL);
		
		CPrintToChat(iClient, "{lightseagreen}[MaxDB] {grey}You have leveled up!");
	}
	
	int CurrentLevelXPBuffer = GetXPFromLevel(g_pPlayers[iClient].iLevel, Multiplier);
	int NextLevel = g_pPlayers[iClient].iLevel + 1;
	int NextLevelBuffer = GetXPFromLevel(NextLevel, Multiplier);
	
	g_pPlayers[iClient].iXPToNextLevel = NextLevelBuffer - CurrentLevelXPBuffer;
	g_pPlayers[iClient].iXPAtLevel = g_pPlayers[iClient].iXP - CurrentLevelXPBuffer;
}

int GetUserLevel(int iClient)
{
	LSPL_Multiplier multiplier = GetMultiplierByPrestige(iClient);
	
	if (multiplier == LSPL_Multiplier_Invalid)
	{
		if (Verbose)
			CPrintToChat(iClient, "{lightseagreen}[MaxDB] {grey}Received Invalid Multiplier.");
		return -1;
	}
	
	if (g_pPlayers[iClient].iXP < BaseXP)
		return 0;
	
	int result = GetLevelFromXP(g_pPlayers[iClient].iXP, multiplier);
	
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

void GetUserPrefix(int iClient, char[] buffer, int size, bool rank = false)
{	
	if (rank)
		if (g_pPlayers[iClient].iPrestige >= MaxPL)
			if (StrEqual(LSRL_Titles[view_as<int>(GetUserRank(iClient))], ""))
				Format(buffer, size, "%s", LSPL_Titles[g_pPlayers[iClient].iPrestige]);
			else
				Format(buffer, size, "%s %s", LSRL_Titles[view_as<int>(GetUserRank(iClient))], LSPL_Titles[g_pPlayers[iClient].iPrestige]);
		else
			if (StrEqual(LSRL_Titles[view_as<int>(GetUserRank(iClient))], ""))
				Format(buffer, size, "%s%i", LSPL_Titles[g_pPlayers[iClient].iPrestige], g_pPlayers[iClient].iLevel);
			else
				Format(buffer, size, "%s %s%i", LSRL_Titles[view_as<int>(GetUserRank(iClient))], LSPL_Titles[g_pPlayers[iClient].iPrestige], g_pPlayers[iClient].iLevel);
	else
		if (g_pPlayers[iClient].iPrestige >= MaxPL)
			Format(buffer, size, "%s", LSPL_Titles[g_pPlayers[iClient].iPrestige]);
		else
			Format(buffer, size, "%s%i", LSPL_Titles[g_pPlayers[iClient].iPrestige], g_pPlayers[iClient].iLevel);
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

stock int GetXPFromUserLevel(int level, int iClient)
{
	LSPL_Multiplier Multiplier = GetMultiplierByPrestige(iClient);
	
	return GetXPFromLevel(level, Multiplier);
}

bool IsValidClient(int iClient, bool bAlive = false)
{
	if (iClient >= 1 && iClient <= MaxClients && IsClientConnected(iClient) && IsClientInGame(iClient) && !IsFakeClient(iClient) && g_pPlayers[iClient].iXP != -1 && g_pPlayers[iClient].iPrestige != -1 && (bAlive == false || IsPlayerAlive(iClient)))
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

int GetColorHex(int iClient)
{
	switch (g_pPlayers[iClient].iPrestige)
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
}

LSRL GetUserRank(int iClient)
{
	if (CheckCommandAccess(iClient, "mls_core_admin_permission", ADMFLAG_GENERIC))
		return LSRL_Admin;
		
	if (g_pPlayers[iClient].bInTesterGroup)
		return LSRL_Tester;
		
	if (CheckCommandAccess(iClient, "mls_core_donor_permission", ADMFLAG_RESERVATION))
		return LSRL_Donor;
		
	if (g_pPlayers[iClient].bInMemberGroup)
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
			g_pPlayers[iClient].bInMemberGroup = true;
		if (groupid == TesterGroupID32)
			g_pPlayers[iClient].bInTesterGroup = true;
	}
}

//In cases where Steamtools is also loaded and Steamworks fails to see the callback
public void Steam_GroupStatusResult(int iClient, int groupAccountID, bool groupMember, bool groupOfficer)
{
	if (groupAccountID != MemberGroupID32 && groupAccountID != TesterGroupID32)
		return;	
		
	if (!IsValidClientExcludeData(iClient))
		return;
			
	if (groupMember || groupOfficer)
	{
		if (groupAccountID == MemberGroupID32)
			g_pPlayers[iClient].bInMemberGroup = true;
		if (groupAccountID == TesterGroupID32)
			g_pPlayers[iClient].bInTesterGroup = true;
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
		return ThrowNativeError(SP_ERROR_NATIVE, "Missing iClient parameter");
	
	int iClient = GetNativeCell(1);
	
	if (!IsValidClient(iClient))
		return ThrowNativeError(SP_ERROR_NATIVE, "iClient %d is not valid", iClient);
		
	return g_pPlayers[iClient].iLevel;
}

public int Native_GetUserPrestige(Handle plugin, int numParams)
{
	if (numParams < 1)
		return ThrowNativeError(SP_ERROR_NATIVE, "Missing iClient parameter");
	
	int iClient = GetNativeCell(1);
	
	if (!IsValidClient(iClient))
		return ThrowNativeError(SP_ERROR_NATIVE, "iClient %d is not valid", iClient);
		
	return g_pPlayers[iClient].iPrestige;
}

public int Native_GetUserRank(Handle plugin, int numParams)
{
	if (numParams < 1)
		return ThrowNativeError(SP_ERROR_NATIVE, "Missing iClient parameter");
	
	int iClient = GetNativeCell(1);
	
	if (!IsValidClient(iClient))
		return ThrowNativeError(SP_ERROR_NATIVE, "iClient %d is not valid", iClient);
		
	return view_as<int>(GetUserRank(iClient));
}

public int Native_GetPrestigeColorRGB(Handle plugin, int numParams)
{
	if (numParams < 2)
		return ThrowNativeError(SP_ERROR_NATIVE, "Missing parameter(s)");
		
	int iClient = GetNativeCell(2);
	
	if (!IsValidClient(iClient))
		return ThrowNativeError(SP_ERROR_NATIVE, "iClient %d is not valid", iClient);
	
	int color_buffer[3];
	
	g_pPlayers[iClient].CloneColors(color_buffer);
	
	SetNativeArray(1, color_buffer, sizeof color_buffer);
	
	return 0;
}

public int Native_GetPrestigeColorHex(Handle plugin, int numParams)
{
	if (numParams < 1)
		return ThrowNativeError(SP_ERROR_NATIVE, "Missing parameter(s)");
		
	int iClient = GetNativeCell(1);
	
	if (!IsValidClient(iClient))
		return ThrowNativeError(SP_ERROR_NATIVE, "iClient %d is not valid", iClient);
	
	return GetColorHex(iClient);
}

public int Native_GetPrestigeTitle(Handle plugin, int numParams)
{
	if (numParams < 3)
		return ThrowNativeError(SP_ERROR_NATIVE, "Missing parameter(s)");
		
	int iClient = GetNativeCell(3);
	
	if (!IsValidClient(iClient))
		return ThrowNativeError(SP_ERROR_NATIVE, "iClient %d is not valid", iClient);
		
	int buffer_size = GetNativeCell(2);
	
	SetNativeString(1, LSPL_Titles[g_pPlayers[iClient].iPrestige], buffer_size);
	
	return 0;
}

public int Native_GetRankTitle(Handle plugin, int numParams)
{
	if (numParams < 3)
		return ThrowNativeError(SP_ERROR_NATIVE, "Missing parameter(s)");
		
	int iClient = GetNativeCell(3);
	
	if (!IsValidClient(iClient))
		return ThrowNativeError(SP_ERROR_NATIVE, "iClient %d is not valid", iClient);
		
	int buffer_size = GetNativeCell(2);
	
	SetNativeString(1, LSRL_Titles[view_as<int>(GetUserRank(iClient))], buffer_size);
	
	return 0;
}

public int Native_AddXP(Handle plugin, int numParams)
{
	if (numParams < 3)
		return ThrowNativeError(SP_ERROR_NATIVE, "Missing parameter(s)");
		
	int iClient = GetNativeCell(1);
	
	if (!IsValidClient(iClient))
		return ThrowNativeError(SP_ERROR_NATIVE, "iClient %d is not valid", iClient);
	
	if (!CanGainXP(iClient))
		return -1;
		
	int buffer = GetNativeCell(2);
		
	if (buffer < 0)
		return ThrowNativeError(SP_ERROR_NATIVE, "Cannot add negative XP");
		
	bool bonus = GetNativeCell(3);
		
	if (bonus)
		buffer = GetXPValue(iClient, buffer);
	
	AddXPToUser(iClient, buffer);
	
	return 1;
}

public int Native_PrintToClient(Handle plugin, int numParams)
{
	if (numParams < 2)
		return ThrowNativeError(SP_ERROR_NATIVE, "Missing parameter(s)");
		
	int iClient = GetNativeCell(1);
	
	if (!IsValidClient(iClient))
		return ThrowNativeError(SP_ERROR_NATIVE, "iClient %d is not valid", iClient);
		
	char buffer[254];
		
	FormatNativeString(0, 2, 3, sizeof buffer, _, buffer);
	
	CPrintToChat(iClient, "{lightseagreen}[MaxDB] {grey}%s", buffer);
	
	return 0;
}

public int Native_IsLoaded(Handle plugin, int numParams)
{
	if (numParams < 1)
		return ThrowNativeError(SP_ERROR_NATIVE, "Missing parameter(s)");
		
	int iClient = GetNativeCell(1);
	
	if (!IsValidClientExcludeData(iClient))
		return ThrowNativeError(SP_ERROR_NATIVE, "iClient %d is not valid", iClient);
		
	return g_pPlayers[iClient].bIsLoaded;
}
