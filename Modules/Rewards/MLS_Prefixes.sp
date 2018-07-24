#pragma semicolon 1

#define PLUGIN_AUTHOR "Fishy"
#define PLUGIN_VERSION "1.0.0"

#include <sourcemod>
#include <scp>
#include <morecolors>
#include <Modular_LS>

#pragma newdecls required

public Plugin myinfo = 
{
	name = "MLS - Chat Prefixes",
	author = PLUGIN_AUTHOR,
	description = "MLS Module - Rewards - Chat Prefixes",
	version = PLUGIN_VERSION,
	url = "https://keybase.io/rumblefrog"
};

public void OnPluginStart()
{
	
}

public Action OnChatMessage(int &author, Handle recipients, char[] name, char[] message)
{
	bool bChanged;

	int Client_Level = MLS_GetUserLevel(author);
	
	int Client_Prestige = MLS_GetUserPrestige(author);
	
	if (Client_Level != -1 && Client_Prestige < 5)
	{
		char title[16], prefix[128], rank[40];
		
		int hex = MLS_GetPrestigeColorHex(author);
		MLS_GetPrestigeTitle(title, sizeof title, author);
		MLS_GetRankTitle(rank, sizeof rank, author);
		
		CAddColor(title, hex);
		
		if (StrEqual(rank, ""))
			Format(prefix, sizeof prefix, "{lightseagreen}[{%s}%s%i{lightseagreen}]", title, title, Client_Level);
		else
			Format(prefix, sizeof prefix, "{lightseagreen}[{%s}%s %s%i{lightseagreen}]", title, rank, title, Client_Level);
		
		CReplaceColorCodes(prefix);
		
		Format(name, MAXLENGTH_NAME, "%s %s", prefix, name);
		
		bChanged = true;
		
	}
	
	if (Client_Prestige == 5)
	{
		char title[16], prefix[128], rank[40];
		
		int hex = MLS_GetPrestigeColorHex(author);
		MLS_GetPrestigeTitle(title, sizeof title, author);
		MLS_GetRankTitle(rank, sizeof rank, author);
		
		CAddColor(title, hex);
		
		if (StrEqual(rank, ""))
			Format(prefix, sizeof prefix, "{lightseagreen}[{%s}%s{lightseagreen}]", title, title);
		else
			Format(prefix, sizeof prefix, "{lightseagreen}[{%s}%s %s{lightseagreen}]", title, rank, title);
		
		CReplaceColorCodes(prefix);
		
		Format(name, MAXLENGTH_NAME, "%s %s", prefix, name);
		
		bChanged = true;
	}

	if(bChanged)
		return Plugin_Changed;
	
	return Plugin_Continue;
}
