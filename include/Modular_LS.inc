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
* Get client prestige colors
* 
* @param colors[3]		Int Array of 3 as Reference
* @param client			Client Index
* @noreturn
*/
native int MLS_GetPrestigeColor(int colors[3], int client);

/**
* Get client prestige title
* 
* @param buffer			Buffer Reference
* @param size			Buffer Size
* @param client			Client Index
* @noreturn
*/
native int MLS_GetPrestigeTitle(char[] buffer, int size, int client);


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
}
#endif