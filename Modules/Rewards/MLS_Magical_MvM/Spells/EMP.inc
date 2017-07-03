#define EMPParticle "hammer_bell_ring_shockwave"

void CastEMP(int client)
{
	if (!CanUseSpell(client, Spell_EMP))
		return;
		
	if (!DrainSpellMana(client, Spell_EMP))
		return;
	
	EmitSoundToClient(client, EMPSound);
		
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientConnected(i) && IsFakeClient(i))
			TF2_AddCondition(i, TFCond_MVMBotRadiowave, 15.0, client);
	}
	
	int particle = CreateEntityByName("info_particle_system");

	if (!IsValidEdict(particle))
    	return;
    	
	char name[64];
	float position[3];
	
	GetEntPropVector(client, Prop_Send, "m_vecOrigin", position);
	GetEntPropString(client, Prop_Data, "m_iName", name, sizeof(name));
	
	TeleportEntity(particle, position, NULL_VECTOR, NULL_VECTOR);
	
	DispatchKeyValue(particle, "targetname", "tf2particle");
	DispatchKeyValue(particle, "parentname", name);
	DispatchKeyValue(particle, "effect_name", EMPParticle);
	
	DispatchSpawn(particle);
	
	SetVariantString(name);
	AcceptEntityInput(particle, "SetParent", particle, particle, 0);
	ActivateEntity(particle);
	AcceptEntityInput(particle, "start");
    
	//CreateTimer(time, DeleteEMPParticle, particle);
}

/*
public Action DeleteEMPParticle(Handle timer, any particle)
{
    if (IsValidEntity(particle))
    {
        char classN[64];
        GetEdictClassname(particle, classN, sizeof(classN));
        if (StrEqual(classN, "info_particle_system", false))
            RemoveEdict(particle);
    }
}
*/