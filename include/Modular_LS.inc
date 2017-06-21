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
native int MLS_GetPrestigeColorRGB(int colors[3], int client);

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
native int MLS_GetPrestigeTitle(char[] buffer, int size, int client);


/**
* Add XP to client
* 
* @param client			Client Index
* @param xp				XP Value
* @param bonus			Whether to consider other factors (playtime, membership, etc)
* @noreturn
*/
native int MLS_AddXP(int client, int xp, bool bonus = true);

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
}
#endif