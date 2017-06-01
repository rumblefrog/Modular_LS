#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "Fishy"
#define PLUGIN_VERSION "0.0.1"

#include <sourcemod>
#include <sdktools>
#include <morecolors>

#pragma newdecls required

#define BaseXP 10

#define MaxPL 5
#define MaxPLL 50

enum LSPL
{
	LSPL_0 = 1.13,
	LSPL_1 = 1.137,
	LSPL_2 = 1.144,
	LSPL_3 = 1.151,
	LSPL_4 = 1.158,
	LSPL_Total
}

public Plugin myinfo = 
{
	name = "Dodgeball LS",
	author = PLUGIN_AUTHOR,
	description = "Dodgeball Leveling System",
	version = PLUGIN_VERSION,
	url = "https://keybase.io/rumblefrog"
};

public void OnPluginStart()
{
	
}

int GetLevelFromXP(int xp, LSPL multiplier)
{
	return Logarithm(xp / BaseXP, multiplier);
}
