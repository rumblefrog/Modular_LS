int SpawnBarricade(int iClient)
{
	if (!CanUseSpell(iClient, Spell_Barricade))
		return -1;
		
	if (!DrainSpellMana(iClient, Spell_Barricade))
		return -1;
		
	float fAngles[3], fCAngles[3], fCOrigin[3], fOrigin[3];

	GetClientAbsAngles(iClient, fAngles);
	
	GetClientEyePosition(iClient, fCOrigin);

	GetClientEyeAngles(iClient, fCAngles);

	Handle hTraceRay = TR_TraceRayFilterEx(fCOrigin, fCAngles, MASK_SOLID, RayType_Infinite, FilterPlayer);

	if(TR_DidHit(hTraceRay))
	{
		TR_GetEndPosition(fOrigin, hTraceRay);

		CloseHandle(hTraceRay);
	}
	
	//Lmao
	int iEnt = CreateEntityByName("prop_physics_override");
	
	//int iEnt = CreateEntityByName("prop_dynamic_override");
	
	if (!IsValidEntity(iEnt))
		return -1;
		
	DispatchKeyValue(iEnt, "model", BarricadeModel);
	
	//SetEntProp(iEnt, Prop_Data, "m_CollisionGroup", 5);
	//SetEntProp(iEnt, Prop_Data, "m_usSolidFlags", 16);
	//SetEntProp(iEnt, Prop_Data, "m_nSolidType", 6);

	DispatchSpawn(iEnt);

	TeleportEntity(iEnt, fOrigin, fAngles, NULL_VECTOR);
	
	CreateTimer(60.0, Timer_BarricadeExpire, iEnt);
	
	return iEnt;
}

public bool FilterPlayer(int iEntity, any aContentsMask)
{
	return iEntity > MaxClients;
}

public Action Timer_BarricadeExpire(Handle timer, any iEnt)
{
	AcceptEntityInput(iEnt, "Kill");
}