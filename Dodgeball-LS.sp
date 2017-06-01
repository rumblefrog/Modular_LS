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

#define MaxPL 5
#define MaxPLL 50

enum LSPL
{
	LSPL_0,
	LSPL_1,
	LSPL_2,
	LSPL_3,
	LSPL_4,
	LSPL_Total
}

enum LSPL_Multiplier
{
	LSPL_Multiplier_0 = 1.13,
	LSPL_Multiplier_1 = 1.137,
	LSPL_Multiplier_2 = 1.144,
	LSPL_Multiplier_3 = 1.151,
	LSPL_Multiplier_4 = 1.158
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
	
	char TableCreateSQL[] = "CREATE TABLE `Dodgeball_LS` ( `id` INT NOT NULL AUTO_INCREMENT , `steamid` VARCHAR(64) NOT NULL , `xp` BIGINT NOT NULL DEFAULT '0' , `prestige` TINYINT NOT NULL DEFAULT '0' , `timeplayed` BIGINT NOT NULL DEFAULT '0' , `creation_date` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP , PRIMARY KEY (`id`), INDEX (`prestige`), UNIQUE (`steamid`)) ENGINE = InnoDB CHARSET=utf8mb4 COLLATE utf8mb4_general_ci";
	
	SQL_SetCharset(hDB, "utf8mb4");
			
	hDB.Query(OnTableCreate, TableCreateSQL);
	
	RegPluginLibrary("Dodgeball_LS");

	//CreateNative("DBLS_GetUserLevel", NativeAddBroadcast);
	
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
	
}

int GetLevelFromXP(int xp, LSPL multiplier)
{
	return Logarithm(xp / BaseXP, multiplier);
}
