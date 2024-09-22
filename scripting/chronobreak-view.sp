#include <sourcemod>
#include <sdkhooks>
#include <sdktools>

#include <usermessages_stock>
#include <nmrih_player>
#include <chronobreak>

#pragma newdecls required
#pragma semicolon 1

#define PLUGIN_NAME         "EkkoChronobreak"
#define PLUGIN_DESCRIPTION  "Ekko Abilitie Chronobreak"
#define PLUGIN_VERSION      "1.0.0"

public Plugin myinfo =
{
    name        = PLUGIN_NAME,
    author      = "F1F88",
    description = PLUGIN_DESCRIPTION,
    version     = PLUGIN_VERSION,
    url         = "https://github.com/F1F88/"
};

#define private             /**/
#define NMR_MAXPLAYERS      9
#define MODEL_TRAIL         "effects/tracer_middle.vmt"
#define MODEL_XFIREBALL3    "materials/sprites/xfireball3.vmt"
#define MODEL_LASER         "sprites/laser.vmt"
#define MODEL_HALO01        "sprites/halo01.vmt"
#define SOUND_EXPLODE3      "weapons/explode3.wav"


enum struct TrailData
{
    int userId;
    int trailRef;
}


bool        g_pluginLate;
int         g_SpriteBeam;
int         g_SpriteHalo;
TrailData   g_trailPool[MAXPLAYERS + 1];


public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    g_pluginLate = late;

    return APLRes_Success;
}

public void OnPluginStart()
{
    // Init
    for(int index = 0; index < sizeof(g_trailPool); ++index)
    {
        // g_trailPool[index].userId = 0;
        g_trailPool[index].trailRef = INVALID_ENT_REFERENCE;
    }

    if (g_pluginLate)
    {
        for(int client = 1; client <= MaxClients; ++client)
        {
            if (IsClientInGame(client) && IsPlayerAlive(client))
            {
                if (Chronobreak(client).GetState() != ChronobreakState_Disabled)
                {
                    AddTrail(client);
                }
            }
        }
    }
}

public void OnMapStart()
{
    PrecacheModel(MODEL_TRAIL, true);
    PrecacheModel(MODEL_XFIREBALL3, true);

    g_SpriteBeam = PrecacheModel(MODEL_LASER, true);
    g_SpriteHalo = PrecacheModel(MODEL_HALO01, true);

    PrecacheSound(SOUND_EXPLODE3, true);
}

public void OnPluginEnd()
{
    // Clear
    for(int index = 0; index < sizeof(g_trailPool); ++index)
    {
        RemoveTrail(index); // 函数负责检测尾拖有效性
    }
}


public void OnChronobreakEnablePost(int userId)
{
    int client = GetClientOfUserId(userId);
    AddTrail(client); // 启用后立即添加尾拖，可视化回溯点
}

public void OnChronobreakUsePost(int userId)
{
    int client = GetClientOfUserId(userId);

    MarkStartPosition(client); // 标记技能使用开始的回溯点位

    // 隐藏正在回溯的玩家，否则其他玩家看起来像是在乱飞
    // SDKHook(client, SDKHook_SetTransmit, Hook_PlayerSetTransmit);
}

public void OnChronobreakUseOverPost(int userId)
{
    int client = GetClientOfUserId(userId);
    if (IsValidClient(client))
    {

        // SDKUnhook(client, SDKHook_SetTransmit, Hook_PlayerSetTransmit); // 回溯的玩家现在起应该可见
    }
    else
    {
        for (int index = 0; index < sizeof(g_trailPool); ++index)
        {
            if (userId == g_trailPool[index].userId)
            {
                RemoveTrail(index); // 移除尾拖
            }
        }
    }
}

public void OnChronobreakDisablePost(int userId, ChronobreakDisabledReason reason)
{
    if (reason == ChronobreakReason_ClientDisconnect || reason == ChronobreakReason_InvalidClient)
    {
        // 无法根据 userId 查询 client 的状态，手动遍历查找尾拖
        for (int index = 0; index < sizeof(g_trailPool); ++index)
        {
            if (userId == g_trailPool[index].userId)
                RemoveTrail(index); // 移除尾拖
        }
    }
    else
    {
        int client = GetClientOfUserId(userId);
        RemoveTrail(client); // 移除尾拖

        if (IsValidClient(client))
        {
            MarkEndPosition(client); // 标记技能使用结束的回溯点位

            SendDazzleEffect(client); // 用屏幕白光模拟眩晕效果（类似使用药丸）

            CreateExplosion(client); // 爆炸实体（造成伤害）
        }
    }
}


private void AddTrail(int client)
{
    // ref: https://forums.alliedmods.net/showthread.php?t=338934
    int trail = CreateEntityByName("env_spritetrail");
    if (!IsValidEdict(trail))
        ThrowError("Can't create entity 'env_spritetrail'. (%N-%d)", client, trail);

    char parent[16];
    FormatEx(parent, sizeof(parent), "player%i", client);
    DispatchKeyValue(client, "targetname", parent);

    DispatchKeyValue(trail, "parentname", "A trail");
    DispatchKeyValueFloat(trail, "lifetime", Chronobreak(client).GetPastTime());
    DispatchKeyValue(trail, "startwidth", "3");
    DispatchKeyValue(trail, "endwidth", "1");
    DispatchKeyValue(trail, "spritename", MODEL_TRAIL);
    DispatchKeyValue(trail, "renderamt", "255");
    DispatchKeyValue(trail, "rendercolor", "255 255 255");
    DispatchKeyValue(trail, "rendermode", "5");

    DispatchSpawn(trail);

    float position[3];
    GetClientAbsOrigin(client, position);

    // 略微增加高度以避免被部分地形遮挡
    position[2] += 5.0;
    TeleportEntity(trail, position, NULL_VECTOR, NULL_VECTOR);

    SetVariantString(parent);
    AcceptEntityInput(trail, "SetParent");

    SetEntPropEnt(trail, Prop_Send, "m_hOwnerEntity", client);
    SetEntPropEnt(trail, Prop_Data, "m_hOwnerEntity", client);

    int trailRef = EntIndexToEntRef(trail);
    g_trailPool[client].trailRef = trailRef;
    g_trailPool[client].userId = GetClientUserId(client);

    // 对其他玩家隐藏尾拖
    SDKHook(trail, SDKHook_SetTransmit, Hook_TrailSetTransmit);
}

private void RemoveTrail(int index)
{
    int trailRef = g_trailPool[index].trailRef;
    if (trailRef == INVALID_ENT_REFERENCE)
        return;

    int trail = EntRefToEntIndex(trailRef);
    if (IsValidEntity(trail))
        AcceptEntityInput(trail, "Kill");

    g_trailPool[index].trailRef = INVALID_ENT_REFERENCE;
    g_trailPool[index].userId = 0;
}

private void MarkStartPosition(int client)
{
    Chronobreak cb = Chronobreak(client);
    float useTime = cb.GetUseTime();

    float absPos[3];
    GetClientAbsOrigin(client, absPos);

    float startRadius;
    float endRadius = 0.0;
    int startFrame = 0;
    int frameRate = 10;
    float life = useTime;
    float width = 7.0;
    float amplitude = 0.0; // 振幅
    int redColor[4] = {0, 128, 0, 0};
    int speed;
    int flags = 0;

    absPos[2] += 5.0;
    startRadius = 90.0;
    speed = RoundToCeil(FloatAbs(startRadius - endRadius) / life);
    TE_SetupBeamRingPoint(absPos, startRadius, endRadius, g_SpriteBeam, g_SpriteHalo, startFrame, frameRate, life, width, amplitude, redColor, speed, flags);
    TE_SendToAll();

    absPos[2] += 5.0;
    startRadius = 128.0;
    speed = RoundToCeil(FloatAbs(startRadius - endRadius) / life);
    TE_SetupBeamRingPoint(absPos, startRadius, endRadius, g_SpriteBeam, g_SpriteHalo, startFrame, frameRate, life, width, amplitude, redColor, speed, flags);
    TE_SendToAll();
}

private void SendDazzleEffect(int client)
{
    NMR_Player player = NMR_Player(client);
    if (player.IsInfected())
    {
        player.TakePills();
    }
    else
    {
        UTIL_ScreenFade(client, 500, 300, 17, 220, 220, 220, 128);
    }
}

private void MarkEndPosition(int client)
{
    Chronobreak cb = Chronobreak(client);
    float useTime = cb.GetUseTime();

    float absPos[3];
    GetClientAbsOrigin(client, absPos);

    float startRadius;
    float endRadius;
    int startFrame = 0;
    int frameRate = 10;
    float life = useTime * 1.25;
    float width = 10.0;
    float amplitude = 1.0; // 振幅
    int blueColor[4] = {0, 62, 152, 180};
    int speed;
    int flags = 0;

    // 回溯最终点位
    absPos[2] += 5.0;
    endRadius = 150.0;
    startRadius = 30.0;
    speed = RoundToCeil(FloatAbs(startRadius - endRadius) / life);
    TE_SetupBeamRingPoint(absPos, startRadius, endRadius, g_SpriteBeam, g_SpriteHalo, startFrame, frameRate, life, width, amplitude, blueColor, speed, flags);
    TE_SendToAll();

    absPos[2] += 5.0;
    endRadius = 128.0;
    startRadius = 16.0;
    speed = RoundToCeil(FloatAbs(startRadius - endRadius) / life);
    TE_SetupBeamRingPoint(absPos, startRadius, endRadius, g_SpriteBeam, g_SpriteHalo, startFrame, frameRate, life, width, amplitude, blueColor, speed, flags);
    TE_SendToAll();

    // 烟尘效果
    // float scale = 0.1;
    // int radius = 128;
    // int magnitude = 5000;
    // TE_SetupExplosion(absPos, g_SpriteExplostion, scale, frameRate, flags, radius, magnitude);
    // TE_SendToAll();

    // 爆炸音效
    // EmitAmbientSound(SOUND_EXPLODE3, absPos, client);
    EmitAmbientGameSound(SOUND_EXPLODE3, absPos, client);
    // EmitGameSoundToAll(SOUND_EXPLODE3, client, .origin=absPos);
}

private void CreateExplosion(int client)
{
    int explode = CreateEntityByName("env_explosion");
    if (explode != -1)
    {
        for (int i = 1; i <= MaxClients; ++i) // 玩家应该免疫爆炸伤害
        {
            if (IsClientInGame(i) && IsPlayerAlive(i))
                SDKHook(i, SDKHook_OnTakeDamage, Hook_OnTakeDamage);
        }

        float origin[3];
        NMR_Player(client).GetAbsOrigin(origin);

        origin[2] += 15.0; // 抬高以避免伤害被地形遮挡
        DispatchKeyValueVector(explode, "origin", origin);
        DispatchKeyValue(explode, "fireballsprite", MODEL_XFIREBALL3);
        DispatchKeyValue(explode, "iMagnitude", "3000");
        DispatchKeyValue(explode, "iRadiusOverride", "170"); // 比标记光圈略大
        DispatchKeyValue(explode, "rendermode", "0");
        DispatchKeyValue(explode, "DamageForce", "3000");
        DispatchKeyValue(explode, "spawnflags", "3896");
        // DispatchKeyValue(explode, "spawnflags", "3960");
        DispatchKeyValue(explode, "ignoredClass", "1");

        DispatchSpawn(explode);

        SetEntPropEnt(explode, Prop_Send, "m_hOwnerEntity", client);
        SetEntPropEnt(explode, Prop_Data, "m_hOwnerEntity", client);
        SetEntPropEnt(explode, Prop_Data, "m_hInflictor", client);

        AcceptEntityInput(explode, "Explode");
        AcceptEntityInput(explode, "Kill");

        for (int i = 1; i <= MaxClients; ++i) // 不要忘记取消 Hook，否则可能会造出超人
        {
            if (IsClientInGame(i) && IsPlayerAlive(i))
                SDKUnhook(i, SDKHook_OnTakeDamage, Hook_OnTakeDamage);
        }
    }
    else
    {
        LogError("Create entity 'env_explosion' failed.");
    }
}


private Action Hook_TrailSetTransmit(int entity, int client)
{
    static int offset;
    if(offset == -1)
        return Plugin_Continue;

    if (offset == 0)
    {
        offset = FindDataMapInfo(entity, "m_hOwnerEntity");
        if (offset == -1)
        {
            char classname[64];
            GetEntityClassname(entity, classname, sizeof(classname));
            ThrowError("Cannot find prop 'm_hOwnerEntity' for entity %s.", classname);
        }
    }

    int owner = GetEntDataEnt2(entity, offset);
    return owner == client ? Plugin_Continue : Plugin_Handled;
}

// private Action Hook_PlayerSetTransmit(int entity, int client)
// {
//     return entity == client ? Plugin_Continue : Plugin_Handled;
// }

private Action Hook_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
    if (attacker == inflictor && damagetype == DMG_BLAST)
        return Plugin_Stop;

    return Plugin_Continue;
}



