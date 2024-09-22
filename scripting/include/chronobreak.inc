#if defined _chronobreak_included
 #endinput
#endif
#define _chronobreak_included

#pragma newdecls required
#pragma semicolon 1



enum ChronobreakState
{
    /**
     * 禁用
     * 进入：可以在任意状态调用 Disable() 进入此状态
     * 离开：只能调用 Enable 转入 Charging 状态
     */
    ChronobreakState_Disabled,

    /**
     * 充能中
     * 进入：只能在 Disable 状态调用 Enbale() 进入此状态
     * 离开1：任意时刻调用 Disable() 转为 Disabled 状态
     * 离开2：充能完毕后 [自动] 转为 Ready 状态
     */
    ChronobreakState_Charging,

    /**
     * 已就绪
     * 进入：只能在 Charging 状态 [自动] 进入此状态
     * 离开1：任意时刻调用 Disable() 转为 Disabled 状态
     * 离开2：任意时刻调用 Use() 转为 InUse 状态
     */
    ChronobreakState_Ready,

    /**
     * 正在释放
     * 进入：只能在 Ready 状态调用 Use() 转入
     * 离开1：任意时刻调用 Disable() 转为 Disabled 状态
     * 离开2: 释放期间玩家无效 [自动] 转为 Disabled 状态
     * 离开3：释放完毕后 [自动] 转为 Disabled 状态
     */
    ChronobreakState_InUse,
}

enum ChronobreakDisabledReason
{
    ChronobreakReason_CallDisable,
    ChronobreakReason_UseEnd,
    ChronobreakReason_MapReset,
    ChronobreakReason_ClientDisconnect,
    ChronobreakReason_ClientDeath,
    ChronobreakReason_InvalidClient
}


methodmap Chronobreak
{
    public Chronobreak(int client)
    {
        return view_as<Chronobreak>(client);
    }

    /**
     * @return  技能状态
     */
    public native ChronobreakState GetState();

    /**
     * @return  技能释放时长
     */
    public native float GetUseTime();

    /**
     * @return  技能回溯秒数（技能释放完后回到几秒前的位置）
     */
    public native float GetPastTime();

    /**
     * @return  技能充能进度（0.0 - 1.0）
     */
    public native float GetChargingProgress();

    /**
     * @return  技能释放进度（0.0 - 1.0）
     */
    public native float GetlUseProgress();

    /**
     * 禁用技能（可重复调用）
     */
    public native void Disable();

    /**
     * 启用技能（不可重复调用）
     *
     * tick时长     =   0.015 （66 tick）
     * 释放时长     =   1.0 （固定写死值)
     * 数据长度     =   67 （1 ➗ tick时长 × 释放时长)
     * factor       =   0   1   2   3   4   5
     * interval     =   ∞   2   4   8  16  32 （1 << factor - 1）(每隔多少帧 记录/更新 一次位置数据)
     * 回溯秒数     =   ∞   2   4   8  16  32  (数据长度 × tick时长 × interval） （估算 = 2 ^ factor）
     *
     * @param   factor    控制间隔多少帧记录一次数据
     *
     * @error   Invalid client.
     *          Client is dead.
     *          Not in disabled state.
     *          Param factor <= 0.
     */
    public native void Enable(int factor=2);

    /**
     * 触发技能（不可重复调用）
     *
     * @error   Invalid client.
     *          Client is dead.
     *          Not in ready state.
     */
    public native void Use();
}



forward void OnChronobreakDisablePost(int oldUserId, ChronobreakDisabledReason reason);
forward void OnChronobreakEnablePost(int userId);
forward void OnChronobreakReadyPost(int userId);
forward void OnChronobreakUsePost(int userId);
