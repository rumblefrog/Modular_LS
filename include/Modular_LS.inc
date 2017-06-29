#if defined _Modular_LS_included
 #endinput
#endif
#define _Modular_LS_included


/**
* Get client level
* 
* @param client			Client Index
* @return				User Level (-1 If Invalid Data)
*/
native int MLS_GetUserLevel(int client);

/**
* Get client prestige level
* 
* @param client			Client Index
* @return				User Prestige (-1 If Invalid Data)
*/
native int MLS_GetUserPrestige(int client);

/**
* Get client prestige colors
* 
* @param colors[3]		Int Array of 3 as Reference
* @param client			Client Index
* @noreturn
*/
native void MLS_GetPrestigeColorRGB(int colors[3], int client);

/**
* Get client prestige colors
* 
* @param color			Int Reference
* @param client			Client Index
* @return				Color Hex
*/
native int MLS_GetPrestigeColorHex(int client);

/**
* Get client prestige title
* 
* @param buffer			Buffer Reference
* @param size			Buffer Size
* @param client			Client Index
* @noreturn
*/
native void MLS_GetPrestigeTitle(char[] buffer, int size, int client);


/**
* Add XP to client
* 
* @param client			Client Index
* @param xp				XP Value
* @param bonus			Whether to consider other factors (playtime, membership, etc)
* @noreturn
*/
native void MLS_AddXP(int client, int xp, bool bonus = true);

/**
* Add XP to all clients
* 
* @param xp				XP Value
* @param bonus			Whether to consider other factors (playtime, membership, etc)
* @noreturn
*/
stock void MLS_AddXPToAll(int xp, bool bonus = true)
{
	for (int i = 1; i <= MaxClients; i++)
		if (IsValidClient(i))
			MLS_AddXP(i, xp, bonus);
}

/**
* Called whenever a client levels up
*
* @param client			Client Index
* @param level			Client Level
* @param prestige		Client Prestige
* @noreturn
*/
forward void MLS_OnClientLeveledUp(int client, int level, int prestige);

/**
* Called whenever a client prestige
*
* @param client			Client Index
* @param level			Client Level (Should be always 0 on prestige)
* @param prestige		Client Prestige
* @noreturn
*/
forward void MLS_OnClientPrestige(int client, int level, int prestige);

/**
* Print to client chat using core format
* 
* @param client			Client Index
* @param format			Format
* @param ...			Any additional formating data
* @noreturn
*/
native void MLS_PrintToClient(int client, const char[] format, any ...);

/**
* Checks if client is above or equal rank
* 
* @param client			Client Index
* @param prestige		Prestige
* @param level			Level
* @return				True if passed, false otherwise
*/
stock bool IsAERank(int client, int prestige, int level)
{
	if (!IsValidClient(client))
		return false;
	
	int EPrestige = MLS_GetUserPrestige(client);
	
	if (EPrestige < prestige)
		return false;
		
	int ELevel = MLS_GetUserLevel(client);
		
	if (EPrestige == prestige && ELevel < level)
		return false;
		
	return true;
}

/**
* Checks if it is a valid client
* 
* @param client			Client Index
* @param bAlive			Check if alive
* @return				True if valid, false if not
*/
stock bool IsValidClient(int client, bool bAlive = false)
{
	if (client >= 1 && client <= MaxClients && IsClientConnected(client) && IsClientInGame(client) && !IsFakeClient(client) &&
	(bAlive == false || IsPlayerAlive(client)))
	{
		return true;
	}

	return false;
}

/**
* Return random integer within range
* 
* @param iMin			Minimum Range
* @param iMax			Max Range
* @return				Random Integer within range
*/
stock int GetURandomIntRange(int iMin, int iMax)
{
	return iMin + (GetURandomInt() % (iMax - iMin + 1));
}

/**
* Return true/false if lucky or not
* 
* @param Chance			A percentage to compare
* @return				True if lucky, false otherwise
*/
stock bool IsLuckyPercentage(int Chance)
{
	return (GetURandomIntRange(0, 99) < Chance);
}

/**
* Return true/false whether if both conditions match
* 
* @param var1			Variable 1
* @param var2			Variable 2
* @param val1			Expected value for variable 1
* @param val2			Expected value for variable 2
* @return				True if both pass, false otherwise
*/
stock bool DoubleEqual(int var1, int var2, int val1, int val2)
{
	return (var1 == val1 && var2 == val2);
}

public SharedPlugin __pl_Modular_LS =
{
	name = "Modular_LS",
	file = "Modular_LS.smx",
	#if defined REQUIRE_PLUGIN
	required = 1,
	#else
	required = 0,
	#endif
};


#if !defined REQUIRE_PLUGIN
public __pl_Modular_LS_SetNTVOptional()
{
	MarkNativeAsOptional("MLS_GetUserLevel");
	MarkNativeAsOptional("MLS_GetUserPrestige");
	MarkNativeAsOptional("MLS_GetPrestigeColorRGB");
	MarkNativeAsOptional("MLS_GetPrestigeColorHex");
	MarkNativeAsOptional("MLS_GetPrestigeTitle");
	MarkNativeAsOptional("MLS_AddXP");
	MarkNativeAsOptional("MLS_PrintToClient");
}
#endif