#include <sourcemod>
#include <sdkhooks>
#include <sdktools>

#include <nmrih_player>

#include <chronobreak>

#pragma newdecls required
#pragma semicolon 1

#define PLUGIN_NAME        "EkkoChronobreak"
#define PLUGIN_DESCRIPTION "Ekko Abilitie Chronobreak"
#define PLUGIN_VERSION     "1.0.0"

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

enum ForwardList
{
    Fwd_DisablePost,
    Fwd_EnablePost,
    Fwd_ReadyPost,
    Fwd_UsePost,

    Fwd_Total
}

/**
 * 玩家回溯时需要使用到的位置、角度等数据
 */
enum struct BacktrackingData
{
    float   origin[3];
    float   angles[3];
    int     m_iHealth;
    float   m_flStamina;
    bool    _bleedingOut;
}


GlobalForward       g_forwards[Fwd_Total];
ChronobreakMachine  g_chronobreakPool[NMR_MAXPLAYERS + 1];


public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    CreateNative("Chronobreak.GetState",            Native_Chronobreak_GetState);
    CreateNative("Chronobreak.GetUseTime",          Native_Chronobreak_GetUseTime);
    CreateNative("Chronobreak.GetPastTime",         Native_Chronobreak_GetPastTime);
    CreateNative("Chronobreak.GetChargingProgress", Native_Chronobreak_GetChargingProgress);
    CreateNative("Chronobreak.GetlUseProgress",     Native_Chronobreak_GetlUseProgress);
    CreateNative("Chronobreak.Disable",             Native_Chronobreak_Disable);
    CreateNative("Chronobreak.Enable",              Native_Chronobreak_Enable);
    CreateNative("Chronobreak.Use",                 Native_Chronobreak_Use);

    g_forwards[Fwd_DisablePost] = new GlobalForward("OnChronobreakDisablePost", ET_Ignore, Param_Cell, Param_Cell);
    g_forwards[Fwd_EnablePost]  = new GlobalForward("OnChronobreakEnablePost",  ET_Ignore, Param_Cell);
    g_forwards[Fwd_ReadyPost]   = new GlobalForward("OnChronobreakReadyPost",   ET_Ignore, Param_Cell);
    g_forwards[Fwd_UsePost]     = new GlobalForward("OnChronobreakUsePost",     ET_Ignore, Param_Cell);

    RegPluginLibrary("chronobreak");

    return APLRes_Success;
}

public void OnPluginStart()
{
    HookEvent("player_death",       Event_PlayerDeath);
    HookEvent("nmrih_reset_map",    Event_ResetMap);
}

public void OnGameFrame()
{
    for(int index = 1; index <= MaxClients; ++index)
    {
        ChronobreakState state = g_chronobreakPool[index].GetState();
        switch (state)
        {
            case ChronobreakState_Disabled:
            {
                continue;
            }
            case ChronobreakState_Charging:
            {
                g_chronobreakPool[index].Charge();
            }
            case ChronobreakState_Ready:
            {
                g_chronobreakPool[index].Charge();
            }
            case ChronobreakState_InUse:
            {
                g_chronobreakPool[index].Use();
            }
            default:
            {
                ThrowError("Unknown state. (%d)", state);
            }
        }
    }
}

public void OnClientDisconnect(int client)
{
    if (client > 0 && client < sizeof(g_chronobreakPool))
    {
        g_chronobreakPool[client].Disable(ChronobreakReason_ClientDisconnect);
    }
}

private void Event_PlayerDeath(Event event, char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (client > 0 && client < sizeof(g_chronobreakPool))
    {
        g_chronobreakPool[client].Disable(ChronobreakReason_ClientDeath);
    }
}

private void Event_ResetMap(Event event, char[] name, bool dontBroadcast)
{
    for(int index = 0; index < sizeof(g_chronobreakPool); ++index)
    {
        g_chronobreakPool[index].Disable(ChronobreakReason_MapReset);
    }
}



private any Native_Chronobreak_GetState(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    if (client <= 0 || client >= sizeof(g_chronobreakPool) || !IsClientInGame(client))
    {
        ThrowNativeError(SP_ERROR_PARAM, "Invalid client %d.", client);
    }

    return g_chronobreakPool[client].GetState();
}

private any Native_Chronobreak_GetUseTime(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    if (client <= 0 || client >= sizeof(g_chronobreakPool) || !IsClientInGame(client))
    {
        ThrowNativeError(SP_ERROR_PARAM, "Invalid client %d.", client);
    }

    return g_chronobreakPool[client].GetUseTime();
}

// private int Native_Chronobreak_GetIntervalBit(Handle plugin, int numParams)
// {
//     int client = GetNativeCell(1);
//     if (client <= 0 || client >= sizeof(g_chronobreakPool) || !IsClientInGame(client))
//     {
//         ThrowNativeError(SP_ERROR_PARAM, "Invalid client %d.", client);
//     }

//     return g_chronobreakPool[client].GetIntervalBit();
// }

private any Native_Chronobreak_GetPastTime(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    if (client <= 0 || client >= sizeof(g_chronobreakPool) || !IsClientInGame(client))
    {
        ThrowNativeError(SP_ERROR_PARAM, "Invalid client %d.", client);
    }

    return g_chronobreakPool[client].GetPastTime();
}

private any Native_Chronobreak_GetChargingProgress(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    if (client <= 0 || client >= sizeof(g_chronobreakPool) || !IsClientInGame(client))
    {
        ThrowNativeError(SP_ERROR_PARAM, "Invalid client %d.", client);
    }

    return g_chronobreakPool[client].GetChargingProgress();
}

private any Native_Chronobreak_GetlUseProgress(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    if (client <= 0 || client >= sizeof(g_chronobreakPool) || !IsClientInGame(client))
    {
        ThrowNativeError(SP_ERROR_PARAM, "Invalid client %d.", client);
    }

    return g_chronobreakPool[client].GetlUseProgress();
}

private void Native_Chronobreak_Disable(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    if (client <= 0 || client >= sizeof(g_chronobreakPool) || !IsClientInGame(client))
        ThrowNativeError(SP_ERROR_PARAM, "Invalid client %d.", client);

    g_chronobreakPool[client].Disable(ChronobreakReason_CallDisable);
}

private void Native_Chronobreak_Enable(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    if (!IsValidClient(client))
        ThrowNativeError(SP_ERROR_PARAM, "Invalid client %d.", client);

    if (!IsPlayerAlive(client))
        ThrowNativeError(SP_ERROR_PARAM, "Client %d is dead.", client);

    if (g_chronobreakPool[client].GetState() != ChronobreakState_Disabled)
        ThrowNativeError(SP_ERROR_INVALID_INSTRUCTION, "Not in disabled state. (%d)", g_chronobreakPool[client].GetState());

    // float useTime = GetNativeCell(2);
    // if (FloatCompare(useTime, GetTickInterval()) == -1)
    //     ThrowNativeError(SP_ERROR_PARAM, "Invalid useTime. (%f)", useTime);

    int factor = GetNativeCell(2);
    if (factor <= 0)
        ThrowNativeError(SP_ERROR_PARAM, "Invalid factor. (%d)", factor);

    g_chronobreakPool[client].Enable(client, factor);
}

private void Native_Chronobreak_Use(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    if (client <= 0 || client >= sizeof(g_chronobreakPool) || !IsClientInGame(client))
    {
        ThrowNativeError(SP_ERROR_PARAM, "invalid client %d.", client);
    }

    ChronobreakState state = g_chronobreakPool[client].GetState();
    switch (state)
    {
        case ChronobreakState_Disabled:
        {
            ThrowNativeError(SP_ERROR_INVALID_INSTRUCTION, "Disabled.");
        }
        case ChronobreakState_Charging:
        {
            ThrowNativeError(SP_ERROR_INVALID_INSTRUCTION, "Not yet ready.");
        }
        case ChronobreakState_Ready:
        {
            g_chronobreakPool[client].Use();
        }
        case ChronobreakState_InUse:
        {
            ThrowNativeError(SP_ERROR_INVALID_INSTRUCTION, "In using.");
        }
        default:
        {
            ThrowNativeError(SP_ERROR_NATIVE, "Unknown state. (%d)", state);
        }
    }
}


enum struct ChronobreakMachine
{
    private int                 userId;
    private ChronobreakState    state;
    private ArrayList           datas;          // 存储所有位置数据
    // private float               useTime;        // 技能释放时长
    private int                 datasMaxLength; // 需要记录多少个位置数据
    private int                 intervalBit;    // 用于控制每隔多少 tick 记录一次位置数据
    private float               pastTime;       // 回溯点在多少秒前

    ChronobreakState GetState()
    {
        return this.state;
    }

    // 技能释放时长
    float GetUseTime()
    {
        // return this.useTime;
        return 1.0;
    }

    // 每隔几帧记录一次位置数据（间隔越小，过往时间越短）
    private int GetIntervalBit()
    {
        return this.intervalBit;
    }

    // 过往时间（返回到几秒前）
    float GetPastTime()
    {
        return this.pastTime;
    }

    // 充能进度
    float GetChargingProgress()
    {
        return this.datas.Length * 1.0 / this.datasMaxLength;
    }

    // 释放进度
    float GetlUseProgress()
    {
        return 1.0 - this.datas.Length * 1.0 / this.datasMaxLength;
    }

    void Disable(ChronobreakDisabledReason reason)
    {
        if (this.GetState() == ChronobreakState_Disabled)
        {
            return;
        }

        int oldUserId = this.userId;

        // Reset
        this.userId = 0;
        this.state = ChronobreakState_Disabled;
        if (this.datas == null)
        {
            LogStackTrace("The datas is null.");
        }
        else
        {
            delete this.datas;
        }
        // this.useTime = 0.0;
        this.datasMaxLength = 0;
        this.intervalBit = 0;
        this.pastTime = 0.0;

        Call_StartForward(g_forwards[Fwd_DisablePost]); // 通知技能已禁用
        Call_PushCell(oldUserId);
        Call_PushCell(reason);
        Call_Finish();
    }

    void Enable(int client, int factor)
    {
        if (!IsValidClient(client))
            ThrowError("Invalid client. (%d)", client);

        if (!IsPlayerAlive(client))
            ThrowError("Client %d is dead.", client);

        ChronobreakState state = this.GetState();
        if (state != ChronobreakState_Disabled)
            ThrowError("Not in disabled state. (%d)", state);

        if (this.datas != null) // 内部错误（避免内存泄漏）
            ThrowError("Need to delete old data first.");

        // if (FloatCompare(useTime, GetTickInterval()) == -1)
        //     ThrowError("Invalid useTime. (%f)", useTime);

        if (factor <= 0)
            ThrowError("Invalid factor. (%d)", factor);

        this.userId = GetClientUserId(client);

        this.state = ChronobreakState_Charging;

        this.datas = new ArrayList(sizeof(BacktrackingData));

        // this.useTime = useTime;

        float tickTime = GetTickInterval();

        this.datasMaxLength = RoundToCeil(1.0 / tickTime * this.GetUseTime()); // 每帧回溯一次。逆推需要多少帧 (多少个位置数据)

        this.intervalBit = (1 << factor) - 1; // 用于控制间隔多少帧记录一次位置数据

        this.pastTime = tickTime * this.datasMaxLength * (1 << factor); // 已知位置数据长度，每个数据之间相差多少秒，每一帧用时。逆推技能释放完后返回到几秒前

        Call_StartForward(g_forwards[Fwd_EnablePost]); // 通知技能已启用
        Call_PushCell(this.userId);
        Call_Finish();

        // log.DebugAmxTpl("启用成功，已为玩家 %N 启用技能。", client);
    }

    void Charge()
    {
        int tickCount = GetGameTickCount();
        if (tickCount & this.GetIntervalBit())
            return;

        ChronobreakState state = this.GetState();
        switch (state)
        {
            case ChronobreakState_Disabled:
            {
                ThrowError("Disabled.");
            }
            case ChronobreakState_Charging:
            {
                int client = GetClientOfUserId(this.userId);
                if (!IsValidClient(client))
                    ThrowError("Invalid userId. (%d)", this.userId);

                int length = this.datas.Length;
                if (length > this.datasMaxLength)
                    ThrowError("Datas length overflow. (%d > %d)", length, this.datasMaxLength);

                if (length == this.datasMaxLength)
                {
                    this.state = ChronobreakState_Ready;

                    Call_StartForward(g_forwards[Fwd_ReadyPost]); // 通知技能已充能完毕
                    Call_PushCell(this.userId);
                    Call_Finish();
                }
                else
                {
                    NMR_Player player = NMR_Player(client);
                    BacktrackingData data;
                    player.GetAbsOrigin(data.origin);
                    player.GetAbsAngles(data.angles);
                    data.m_iHealth = player.m_iHealth;
                    data.m_flStamina = player.m_flStamina;
                    data._bleedingOut = player._bleedingOut;
                    this.datas.PushArray(data, sizeof(data));
                }
            }
            case ChronobreakState_Ready:
            {
                int client = GetClientOfUserId(this.userId);
                if (!IsValidClient(client))
                    ThrowError("Invalid userId. (%d)", this.userId);

                int length = this.datas.Length;
                if (length > this.datasMaxLength)
                    ThrowError("Datas length overflow. (%d > %d)", length, this.datasMaxLength);

                // while (this.data.Length >= this.GetMaxDataLength())
                this.datas.Erase(0); // 淘汰旧数据（O(n), 需要将所有元素前移一位)

                // 更新新数据
                NMR_Player player = NMR_Player(client);
                BacktrackingData data;
                player.GetAbsOrigin(data.origin);
                player.GetAbsAngles(data.angles);
                data.m_iHealth = player.m_iHealth;
                data.m_flStamina = player.m_flStamina;
                data._bleedingOut = player._bleedingOut;
                this.datas.PushArray(data, sizeof(data));

                // TODO: OnChronobreakRefreshPost
                // forward void OnChronobreakRefreshPost(int userId, BacktrackingData startData, BacktrackingData endData);

                // log.Debug("充能成功，淘汰 1 个旧数据并添加了 1 个新数据。");
            }
            case ChronobreakState_InUse:
            {
                ThrowError("In using.");
            }
            default:
            {
                ThrowError("Unknown state. (%d)", state);
            }
        }
    }

    void Use()
    {
        int client = GetClientOfUserId(this.userId);
        if (!IsValidClient(client))
        {
            this.Disable(ChronobreakReason_InvalidClient);
            return;
        }

        ChronobreakState state = this.GetState();
        switch (state)
        {
            case ChronobreakState_Disabled:
            {
                ThrowError("Disabled.");
            }
            case ChronobreakState_Charging:
            {
                ThrowError("Not yet ready.");
            }
            case ChronobreakState_Ready:
            {
                this.state = ChronobreakState_InUse; // 标记技能正在释放

                NMR_Player player = NMR_Player(client); // 如果玩家感染了，延长他因感染死亡的时间
                if (player.IsInfected())
                    player.TakePillsInner();

                Call_StartForward(g_forwards[Fwd_UsePost]); // 通知技能开始释放
                Call_PushCell(this.userId);
                Call_Finish();
            }
            case ChronobreakState_InUse:
            {
                int index = this.datas.Length - 1;
                BacktrackingData data;
                this.datas.GetArray(index, data, sizeof(data));
                this.datas.Erase(index); // O(1) 删除末尾元素

                NMR_Player player = NMR_Player(client);
                player.m_iHealth = data.m_iHealth;
                player.m_flStamina = data.m_flStamina;
                player._bleedingOut = data._bleedingOut;
                TeleportEntity(client, data.origin, data.angles, NULL_VECTOR);

                if (index == 0)
                {
                    this.Disable(ChronobreakReason_UseEnd);
                }
            }
            default:
            {
                ThrowError("Unknown state. (%d)", state);
            }
        }
    }
}




















// const float     g_chronobreakTime = 4.0;
    // void SetState(ChronobreakState state)
    // {
    //     switch (state)
    //     {
    //         case ChronobreakState_Disabled:
    //         {
    //             // 任意状态都可以直接 Disable
    //         }
    //         case ChronobreakState_Charging:
    //         {
    //             if (this.state != ChronobreakState_Disabled)
    //                 ThrowError("Not in disabled state. (%d)", this.state);
    //         }
    //         case ChronobreakState_Ready:
    //         {
    //             if (this.state != ChronobreakState_Charging)
    //                 ThrowError("Not in charging state. (%d)", this.state);
    //         }
    //         case ChronobreakState_InUse:
    //         {
    //             if (this.state != ChronobreakState_Ready)
    //                 ThrowError("Not in ready state. (%d)", this.state);
    //         }
    //         default:
    //         {
    //             ThrowError("Invalid param state. (%d)", state);
    //         }
    //     }

    //     // 九九八十一难结束，加冕为状态之王！
    //     this.state = state;
    // }



        // int dataPushInterval = 8; // 记录新位置的帧数间隔
        // float chronobreakTime = RoundToFloor(1.0 / GetTickInterval() * castingTime); // 能够回溯到几秒前
        // 回溯时长 = dataLength * GetTickInterval() * pushDataInterval
        // return RoundToFloor(g_chronobreakTime / GetTickInterval() / 8); // e.g. 3.0 / 0.015 / 8 = 25


// public void OnGameFrame()
// {
//     for(int client = 1; client <= MaxClients; ++client)
//     {
//         if (!IsClientInGame(client))
//         {
//             // clear data
//             if (g_chronobreakData[client] != null)
//             {
//                 delete g_chronobreakData[client];
//             }
//             continue;
//         }

//         if (!IsPlayerAlive(client))
//         {
//             // reset data
//             if (g_chronobreakData[client].Length != 0)
//             {
//                 g_chronobreakData[client].Clear();
//             }
//             continue;
//         }

//         if (g_chronobreakData[client] == null)
//         {
//             LogError("client %d data is null!", client);
//             continue;
//         }

//         NMR_Player player = NMR_Player(client);

//         switch (g_chronobreakState[client])
//         {
//             case ChronobreakState_Disabled:
//             {
//                 if (g_chronobreakData[client].Length != 0)
//                 {
//                     g_chronobreakData[client].Clear();
//                 }
//             }
//             case ChronobreakState_Chargingp:
//             {
//                 while (g_chronobreakData[client].Length >= RoundToFloor(g_chronobreakTime / GetTickInterval()))
//                 {
//                     g_chronobreakData[client].Erase(0); // 比较耗时, 所有元素需要前移
//                 }

//                 ChronobreakData data;
//                 player.GetAbsOrigin(data.origin);
//                 player.GetAbsAngles(data.angles);
//                 data.m_iHealth = player.m_iHealth;
//                 data.stamina = player.m_flStamina;
//                 g_chronobreakData[client].PushArray(data, sizeof(data));
//             }
//             case ChronobreakState_InBacktrace:
//             {
//                 if (g_chronobreakData[client].Length != 0)
//                 {
//                     g_chronobreakData[client].Clear();
//                 }
//                 else
//                 {
//                     g_chronobreakState[client] = ChronobreakState_Enable;
//                 }
//             }
//         }
//     }

// }

// Action Timer_PushBacktrackData(Handle timer)
// {
//     for(int client = 1; client <= MaxClients; ++client)
//     {
//         if (!IsClientInGame(client))
//         {
//             if (g_chronobreakData[client] != null)
//             {
//                 delete g_chronobreakData[client];
//             }
//             continue;
//         }

//         if (!IsPlayerAlive(client))
//         {
//             if (g_chronobreakData[client].Length == 0)
//             {
//                 g_chronobreakData[client].Clear();
//             }
//             continue;
//         }

//         if (g_chronobreakData[client] == null)
//         {
//             ThrowError("client %d data is null!", client);
//         }

//         if (g_chronobreakData[client].Length >= RoundToFloor(1.0 / GetTickInterval()))
//         {
//             g_chronobreakData[client].Erase(0);
//         }

//         ChronobreakData data;
//         NMR_Player player = NMR_Player(client);
//         player.GetAbsOrigin(data.origin);
//         player.GetAbsAngles(data.angles);
//         data.m_iHealth = player.m_iHealth;
//         data.stamina = player.m_flStamina;
//         g_chronobreakData[client].PushArray(data, sizeof(data));
//     }
//     return Plugin_Continue;
// }

// void Chronobreak(int client)
// {
//     RequestFrame(Frame_Chronobreak, GetClientUserId(client));
// }

// void Frame_Chronobreak(int userid)
// {
//     int client = GetClientOfUserId(userid);
//     if (!IsValidClient(client))
//     {
//         if (g_chronobreakData[client] != null)
//         {
//             delete g_chronobreakData[client];
//         }
//         return;
//     }

//     if (!IsPlayerAlive(client))
//     {
//         if (g_chronobreakData[client].Length == 0)
//         {
//             g_chronobreakData[client].Clear();
//         }
//         return;
//     }

//     if (g_chronobreakData[client] == null)
//     {
//         ThrowError("client %d data is null!", client);
//     }

//     if (g_chronobreakData[client].Length == 0)
//     {
//         return;
//     }

//     ChronobreakData data;
//     int index = g_chronobreakData[client].Length - 1;
//     g_chronobreakData[client].GetArray(index, data, sizeof(data));
//     g_chronobreakData[client].Erase(index);

//     NMR_Player player = NMR_Player(client);
//     player.m_iHealth = data.m_iHealth;
//     player.m_flStamina = data.stamina;
//     TeleportEntity(client, data.origin, data.angles, data.velocity);
//     // TeleportEntity(client, data.origin, data.angles, {0.0, 0.0, 0.0});

//     RequestFrame(Frame_Chronobreak, GetClientUserId(client));
// }


// Action CMD_Chronobreak(int client, int args)
// {
//     if (!IsClientInGame(client) || !IsPlayerAlive(client))
//     {
//         ReplyToCommand(client, "只能游戏内存活的玩家可以使用。");
//     }

//     Chronobreak(client);

//     return Plugin_Handled;
// }


// public void OnGameFrame()
// {
//     for (int client = 1; client <= MaxClients; ++client)
//     {
//         if (!IsClientInGame(client))
//         {
//             if (g_chronobreakData[client] != null)
//             {
//                 delete g_chronobreakData[client];
//             }
//             continue;
//         }

//         if (!IsPlayerAlive(client))
//         {
//             if (!g_chronobreakData[client].Empty)
//             {
//                 g_chronobreakData[client].Clear();
//             }
//             continue;
//         }

//         // int statue;
//         // switch(statue)
//         // {
//         //     case 1: // Record
//         //     {
//         //         BacktrackingData data;
//         //         NMR_Player player = NMR_Player(client);
//         //         player.GetAbsOrigin(data.origin);
//         //         player.GetAbsAngles(data.angles);
//         //         data.m_iHealth = player.m_iHealth;
//         //         data.stamina = player.m_flStamina;
//         //         g_chronobreakData[client].PushArray(data);
//         //     }
//         //     case 2:
//         //     {
//         //         BacktrackingData data = g_chronobreakData.Pop();
//         //         NMR_Player player = NMR_Player(client);
//         //         player.m_iHealth = data.m_iHealth;
//         //         player.m_flStamina = data.stamina;
//         //         TeleportEntity(client, data.origin, data.angles, data.velocity);
//         //     }
//         // }
//     }
// }

// void Frame_OnClientPutInServer(int userid)
// {
//     int client = GetClientOfUserId(userid);
//     if (!IsValidClient(client))
//     {
//         return;
//     }

//     HookEvent("player_spawn", Event_OnPlayerSpawn);

//     // NMR_Player player = NMR_Player(client);
// }

// void Event_OnPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
// {
//     int userid = event.GetInt("userid");
//     int client = GetClientOfUserId(userid);
//     if (!IsValidClient(client))
//     {
//         return;
//     }

// }
