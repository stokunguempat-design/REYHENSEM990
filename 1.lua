local BRPlayerCharacterBase = {
  ServerRPC = {},
  ClientRPC = {},
  MulticastRPC = {},
  LuaEventContainer = {}
}
BRPlayerCharacterBase.ServerRPC.ServerRPC_NearDeathGiveupRescue = {
  Reliable = true,
  Params = {}
}
BRPlayerCharacterBase.ServerRPC.ServerRPC_CarryDeadBox = {
  Reliable = true,
  Params = {
    UEnums.EPropertyClass.Object
  }
}
BRPlayerCharacterBase.ServerRPC.RPC_Server_GmPlayAction = {
  Reliable = true,
  Params = {
    UEnums.EPropertyClass.Int
  }
}
BRPlayerCharacterBase.MulticastRPC.MulticastRPC_GmPlayAction = {
  Reliable = true,
  Params = {
    UEnums.EPropertyClass.Int
  }
}
BRPlayerCharacterBase.ClientRPC.RPC_Client_SetShouldCheckPassWall = {
  Reliable = true,
  Params = {
    UEnums.EPropertyClass.Bool
  }
}
BRPlayerCharacterBase.ServerRPC.ServerRPC_NearDeathGiveupRescue = { Reliable = true, Params = {} }
BRPlayerCharacterBase.ServerRPC.ServerRPC_CarryDeadBox = { Reliable = true, Params = { UEnums.EPropertyClass.Object } }
BRPlayerCharacterBase.ServerRPC.RPC_Server_GmPlayAction = { Reliable = true, Params = { UEnums.EPropertyClass.Int } }
BRPlayerCharacterBase.MulticastRPC.MulticastRPC_GmPlayAction = { Reliable = true, Params = { UEnums.EPropertyClass.Int } }
BRPlayerCharacterBase.ClientRPC.RPC_Client_SetShouldCheckPassWall = { Reliable = true, Params = { UEnums.EPropertyClass.Bool } }
BRPlayerCharacterBase.ServerRPC.RPC_Server_ReportSimulateCharacterLocation = { Reliable = true, Params = {} }
BRPlayerCharacterBase.ClientRPC.RPC_Client_ShootVertifyRes = { Reliable = true, Params = {} }
BRPlayerCharacterBase.ClientRPC.RPC_ClientCoronaLab = { Reliable = true, Params = {} }
BRPlayerCharacterBase.ServerRPC.RPC_Server_ReportPlayerKillFlow = { Reliable = true, Params = {} }
BRPlayerCharacterBase.ServerRPC.RPC_Server_ClientSecMrpcsFlow = { Reliable = true, Params = {} }
BRPlayerCharacterBase.ServerRPC.RPC_Server_Heartbeat = { Reliable = true, Params = {} }
BRPlayerCharacterBase.ServerRPC.RPC_Server_SwiftHawk = { Reliable = true, Params = {} }
BRPlayerCharacterBase.ServerRPC.RPC_Server_ClientSwiftHawkWithParams = { Reliable = true, Params = {} }

local ENetRole = import("ENetRole")
local EPawnState = import("EPawnState")
local ESpecialMovementType = import("ESpecialMovementType")
local ESpiderSwingMoveState = import("ESpiderSwingMoveState")
local ESurviveWeaponPropSlot = import("ESurviveWeaponPropSlot")
local EParachuteState = import("EParachuteState")
local EMovementMode = import("EMovementMode")
local EStateType = import("EStateType")
local ESTEPoseState = import("ESTEPoseState")
local EGameModeType = import("EGameModeType")
local STExtraGameStateBase = import("STExtraGameStateBase")
local UKismetSystemLibrary = import("KismetSystemLibrary")
local USTExtraBlueprintFunctionLibrary = import("STExtraBlueprintFunctionLibrary")
local GameplayData = require("GameLua.GameCore.Data.GameplayData")
local GamePlayTools = require("GameLua.Mod.BaseMod.Common.GamePlayTools")
local MatchModeIds = require("GameLua.Mod.BaseMod.GamePlay.Config.MatchModeIdsConfig")

function BRPlayerCharacterBase:ctor() end

function BRPlayerCharacterBase:_PostConstruct()
  BRPlayerCharacterBase.__super._PostConstruct(self)
  self:InitAddSpecialMoveInfo()
  self.bCanNearDeathGiveup = true
end

function BRPlayerCharacterBase:ReceiveBeginPlay()
  BRPlayerCharacterBase.__super.ReceiveBeginPlay(self)
  self:AddControlEvent(self, "MovementModeChangedDelegate", self.HandleOnMovementModeChangedNew, self)
  if self:HasAuthority() and self:CheckAddCheckFallingDistanceComponent() then
    local CheckFallingDistanceComponent_C = import("CheckFallingDistanceComponent")
    if slua.isValid(CheckFallingDistanceComponent_C) and not slua.isValid(self:GetComponentByClass(CheckFallingDistanceComponent_C)) then
      Game:AddComponent(CheckFallingDistanceComponent_C, self, "CheckFallingDistanceComponent")
    end
  end
  if slua.isValid(self.STCharacterMovement) then
    self.STCharacterMovement.bPositiveBlowUp = true
  end
  if self.Role == ENetRole.ROLE_AutonomousProxy then
    self:AddControlEvent(self, "OnPawnStateDisabled", self.OnPawnStateChange, self)
    self:AddControlEvent(self, "OnPawnStateEnabled", self.OnPawnStateChange, self)
    self:AddControlEventConditionOnly(self, "OnAttrChangeEventDelegate", { AttrName = { "bCanSelfRescue" } }, self.CharacterAttrChangeEvent, self)
  end
  if Client then
    GameplayData.AddCharacter(self.Object)
    self:AddControlEvent(self, "OnAttachedToVehicle", self.HandleOnAttachedToVehicle, self)
    self:AddControlEvent(self, "OnDetachedFromVehicle", self.HandleOnDetachedFromVehicle, self)
  else
    self:AddCommonEventWithConditions(EVENTTYPE_INGAME_NORMAL, EVENTID_GAME_MODE_STATE_CHANGE, { [1] = "FinishedState" }, self.HandleFinishedState, self)
  end
end

function BRPlayerCharacterBase:HandleOnAttachedToVehicle(uVehicle)
  if not slua.isValid(uVehicle) then return end
  if self.Role == ENetRole.ROLE_SimulatedProxy then
    self:ClearAttachToVehicleTimer()
    self.nUpdatePlayerAttachToVehicleCount = 0
    self.nUpdatePlayerAttachToVehicleTimer = self:AddGameTimer(5, true, function()
      if slua.isValid(self.Object) and slua.isValid(uVehicle) then self:UpdatePlayerAttachToVehicle(uVehicle) end
    end)
    self.nFixMeshContainerTimer = self:AddGameTimer(3, true, function()
      if slua.isValid(self.Object) and slua.isValid(uVehicle) then self:FixMeshContainerOffsetIfNeeded(uVehicle) end
    end)
  end
end

function BRPlayerCharacterBase:HandleOnDetachedFromVehicle(uLastVehicle)
  if not slua.isValid(uLastVehicle) then return end
  if self.Role == ENetRole.ROLE_SimulatedProxy then
    self:ClearAttachToVehicleTimer()
    self.nUpdatePlayerAttachToVehicleCount = 0
  end
end

function BRPlayerCharacterBase:UpdatePlayerAttachToVehicle(uVehicle)
  if not slua.isValid(self.Object) or not slua.isValid(uVehicle) then return end
  if not slua.isValid(self.CapsuleComponent) or not slua.isValid(self.Mesh) or not slua.isValid(self.MeshContainer) then return end
  if not slua.isValid(self:GetCurrentVehicle()) then return end
  if Game:IsDriver(self.Object) then return end
  if not self.nUpdatePlayerAttachToVehicleCount then self.nUpdatePlayerAttachToVehicleCount = 0 end
  local bStand = self.PoseState == ESTEPoseState.Stand
  local uActorRelativeLocation = self.CapsuleComponent:GetRelativeTransform():GetLocation()
  local uMeshRelativeLocation = self.Mesh:GetRelativeTransform():GetLocation()
  local uMeshContainerRelativeLocationZ = self.MeshContainer:GetRelativeTransform():GetLocation().Z
  local nCapsuleRadius = self.CapsuleComponent:GetScaledCapsuleRadius()
  local nCapsuleHalfHeight = self.CapsuleComponent:GetScaledCapsuleHalfHeight()
  local uMeshContainerExpectedZ = -1 * self.StandHalfHeight
  local nTolerance = 1.0
  local bAllCorrect = bStand
    and uActorRelativeLocation:Equals(FVector(0,0,self.StandHalfHeight), nTolerance)
    and uMeshRelativeLocation:Equals(FVector(0,0,0), nTolerance)
    and nTolerance > math.abs(uMeshContainerRelativeLocationZ - uMeshContainerExpectedZ)
    and nTolerance > math.abs(nCapsuleRadius - self.StandRadius)
    and nTolerance > math.abs(nCapsuleHalfHeight - self.StandHalfHeight)
  if not bAllCorrect then self.nUpdatePlayerAttachToVehicleCount = self.nUpdatePlayerAttachToVehicleCount + 1
  else self.nUpdatePlayerAttachToVehicleCount = 0 end
  if self.nUpdatePlayerAttachToVehicleCount >= 3 and not bAllCorrect then
    local uPlayerController = GameplayData.GetPlayerController()
    if uPlayerController.ReportCrashKitFeature and uPlayerController.ReportCrashKitFeature.ReportCharacterAttachedOnVehicleException then
      uPlayerController.ReportCrashKitFeature:ReportCharacterAttachedOnVehicleException(
        string.format("VehicleShapeType:%s PlayerKey:%s", tostring(uVehicle.VehicleShapeType), tostring(self.PlayerKey)))
    end
    self.nUpdatePlayerAttachToVehicleCount = 0
  end
end

function BRPlayerCharacterBase:FixMeshContainerOffsetIfNeeded(uVehicle)
  if not slua.isValid(self.Object) or not slua.isValid(uVehicle) then return end
  if not slua.isValid(self.MeshContainer) then return end
  if not slua.isValid(self:GetCurrentVehicle()) then return end
  if Game:IsDriver(self.Object) then return end
  local nTolerance = 1.0
  local uMeshContainerExpectedZ = -1 * self.StandHalfHeight
  local uMeshContainerRelativeLocationZ = self.MeshContainer:GetRelativeTransform():GetLocation().Z
  if nTolerance <= math.abs(uMeshContainerRelativeLocationZ - uMeshContainerExpectedZ) then
    self:SetMeshContainerOffsetZ(uMeshContainerExpectedZ)
  end
end

function BRPlayerCharacterBase:ClearAttachToVehicleTimer()
  if self.nUpdatePlayerAttachToVehicleTimer then self:RemoveGameTimer(self.nUpdatePlayerAttachToVehicleTimer); self.nUpdatePlayerAttachToVehicleTimer = nil end
  if self.nFixMeshContainerTimer then self:RemoveGameTimer(self.nFixMeshContainerTimer); self.nFixMeshContainerTimer = nil end
end

function BRPlayerCharacterBase:CharacterAttrChangeEvent(uPawn, AttrName, AttrVal)
  BRPlayerCharacterBase.__super.CharacterAttrChangeEvent(self, uPawn, AttrName, AttrVal)
  if self.Object ~= uPawn then return end
  if self.Role == ENetRole.ROLE_AutonomousProxy and AttrName == "bCanSelfRescue" then
    local uPlayerController = self:GetPlayerControllerSafety()
    if slua.isValid(uPlayerController) then uPlayerController:BroadcastUIMessage("UIMsg_CanSelfRescue", 0, "", "") end
  end
end

function BRPlayerCharacterBase:OnPawnStateChange(PawnState)
  if PawnState == EPawnState.SwitchPP then
    local uPlayerController = self:GetPlayerControllerSafety()
    if slua.isValid(uPlayerController) then uPlayerController:BroadcastUIMessage("UIMsg_FPPModeChange", 0, "", "") end
  end
end

function BRPlayerCharacterBase:HandleFinishedState()
  if slua.isValid(self.STCharacterMovement) and self.STCharacterMovement.SetDynamicSimpleQueryConfig then
    self.STCharacterMovement:SetDynamicSimpleQueryConfig(false)
  end
end

function BRPlayerCharacterBase:CheckAddCheckFallingDistanceComponent()
  if CGameMode and CGameMode.GameModeType and CGameState and CGameState.GameModeID then
    local GameModeType = CGameMode.GameModeType
    local GameModeID = tonumber(CGameState.GameModeID)
    local bModeTypeSatisfy = GameModeType == EGameModeType.ETypicalGameMode or GameModeType == EGameModeType.EFourInOneGameMode or GameModeType == EGameModeType.EHeavyWeaponGameMode
    local bModeIDSatisfy = not MatchModeIds[GameModeID]
    return bModeTypeSatisfy and bModeIDSatisfy
  end
  return false
end

function BRPlayerCharacterBase:LuaHandleParachuteStateChanged(LastParachuteState, NewParachuteState)
  BRPlayerCharacterBase.__super.LuaHandleParachuteStateChanged(self, LastParachuteState, NewParachuteState)
  if not Client then
    local uCurrentPlayerControl = self:GetPlayerControllerSafety()
    if slua.isValid(uCurrentPlayerControl) and uCurrentPlayerControl.CheckParachuteOpenFeature then
      if NewParachuteState == EParachuteState.PS_Opening then
        if uCurrentPlayerControl.CheckParachuteOpenFeature.SatrtCheckShowParachuteCloseUI then
          uCurrentPlayerControl.CheckParachuteOpenFeature:SatrtCheckShowParachuteCloseUI()
        end
      elseif NewParachuteState == EParachuteState.PS_None then
        if uCurrentPlayerControl.CheckParachuteOpenFeature.RecoverParachuteOpenParam then
          uCurrentPlayerControl.CheckParachuteOpenFeature:RecoverParachuteOpenParam()
        end
        if uCurrentPlayerControl.CheckParachuteOpenFeature.ClearTimerAndState then
          uCurrentPlayerControl.CheckParachuteOpenFeature:ClearTimerAndState()
        end
      end
    end
  end
end

function BRPlayerCharacterBase:OnLanded()
  if self.HandleOnLanded then self:HandleOnLanded(-1) end
  if not Client then
    local uCurrentPlayerControl = self:GetPlayerControllerSafety()
    if slua.isValid(uCurrentPlayerControl) and uCurrentPlayerControl.CheckParachuteOpenFeature then
      if uCurrentPlayerControl.CheckParachuteOpenFeature.ClearTimerAndState then uCurrentPlayerControl.CheckParachuteOpenFeature:ClearTimerAndState() end
      if uCurrentPlayerControl.CheckParachuteOpenFeature.ResetCheckShowUI then uCurrentPlayerControl.CheckParachuteOpenFeature:ResetCheckShowUI() end
    end
  end
end

function BRPlayerCharacterBase:ReceiveEndPlay(EndPlayReason)
  BRPlayerCharacterBase.__super.ReceiveEndPlay(self, EndPlayReason)
  if Client then GameplayData.RemoveCharacter(self.Object) end
end

function BRPlayerCharacterBase:IsWarGameMode()
  local uGameState = GameplayData:GetGameState()
  if slua.isValid(uGameState) and Game:IsClassOf(uGameState, STExtraGameStateBase) then
    return uGameState.GameModeType == EGameModeType.EWarGameMode
  end
  return false
end

function BRPlayerCharacterBase:BPOnRecycled() if Client then self:ResetMeshRelativeLocationAndRotation() end end
function BRPlayerCharacterBase:BPOnRespawned() if Client then self:ResetMeshRelativeLocationAndRotation() end end
function BRPlayerCharacterBase:ReceiveOnRecycle()
  if Client then self:ResetMeshRelativeLocationAndRotation(); GameplayData.RemoveCharacter(self.Object) end
end
function BRPlayerCharacterBase:ReceiveOnSpawn()
  if Client then self:ResetMeshRelativeLocationAndRotation(); GameplayData.AddCharacter(self.Object) end
end

function BRPlayerCharacterBase:ResetMeshRelativeLocationAndRotation()
  if Game:IsValid(self.Object) and Game:IsValid(self.Mesh) then
    local uDefaultMeshRot = FRotator(0, -90, 0)
    local uDefaultMeshRelativeLoc = FVector(0, 0, 0)
    if self.Mesh.K2_SetRelativeRotation then self.Mesh:K2_SetRelativeRotation(uDefaultMeshRot, false, nil, false) end
    self:CacheInitialMeshOffset(uDefaultMeshRelativeLoc, uDefaultMeshRot)
  end
end

function BRPlayerCharacterBase:HandleOnMovementModeChangedNew()
  if Game:IsValid(self.STCharacterMovement) and self.STCharacterMovement.MovementMode == EMovementMode.MOVE_Swimming and self:CheckBaseIsMoveable() then
    self.CharacterMovement:SetBase(nil, "", true)
  end
  if self.Role == ENetRole.ROLE_AutonomousProxy and Game:IsValid(self.STCharacterMovement) and self.STCharacterMovement.MovementMode == EMovementMode.MOVE_Walking and UIManager.UI_Config_InGame.ParachuteOpenUI then
    UIManager.CloseUI(UIManager.UI_Config_InGame.ParachuteOpenUI)
  end
end

function BRPlayerCharacterBase:BPOnMissPlayerDamageRecord() end

function BRPlayerCharacterBase:PreAttachedToVehicle()
  local IsDS = UKismetSystemLibrary.IsDedicatedServer(self)
  if not IsDS then return end
  local MainPlayerController = self:GetPlayerControllerSafety()
  if not slua.isValid(MainPlayerController) then return end
  local CharacterAvatarComp2_BP = self.CharacterAvatarComp2_BP
  if not slua.isValid(CharacterAvatarComp2_BP) then return end
  local CommerAvatarDataUtil = require("GameLua.Activity.Commercialize.GamePlay.CommerAvatarDataUtil")
  local changedVehicleId = CommerAvatarDataUtil:ChangeVehicleSkinByClothes(MainPlayerController, CharacterAvatarComp2_BP)
  if changedVehicleId then
    local UAvatarUtils = import("AvatarUtils")
    if UAvatarUtils.GetVehicleShapeBySkinID(changedVehicleId) == import("ESTExtraVehicleShapeType").VST_Horse then
      local uCurPlayerState = self:GetPlayerStateSafety()
      if slua.isValid(uCurPlayerState) then uCurPlayerState:AddGeneralCount(468, 1, false) end
    end
  end
end

BRPlayerCharacterBase.ClientRPC.ClientRPC_TriggerHighlightMoment = {
  Reliable = true,
  Params = { UEnums.EPropertyClass.UInt32, UEnums.EPropertyClass.UInt32 }
}
function BRPlayerCharacterBase:ClientRPC_TriggerHighlightMoment(Type, Param)
  EventSystem:postEvent(EVENTTYPE_INGAME, EVENTID_INGAME_TRIGGER_HIGHLIGHT_MOMENT, Type, Param)
end

function BRPlayerCharacterBase:ParachuteJump()
  local uPlayerController = self:GetControllerSafety()
  if slua.isValid(uPlayerController) then
    if not self:GetEnsure() then
      if uPlayerController:GetCurrentStateType() ~= EStateType.State_ParachuteJump and uPlayerController:GetCurrentStateType() ~= EStateType.State_ParachuteOpen then
        self:SwitchPoseState(ESTEPoseState.Stand, true, true, true, false)
        uPlayerController:ReInitParachuteItem()
        uPlayerController:ServerChangeStatePC(EStateType.State_ParachuteJump)
      end
    else
      EventSystem:postEvent(EVENTTYPE_INGAME_NORMAL, EVENTID_AI_CALL_PARACHUTE_JUMP, self.Object)
    end
  end
end

function BRPlayerCharacterBase:OnMovementBaseChangedEvent(uCharacter, uNewMovementBase, uOldMovementBase)
  if uCharacter ~= self.Object then return end
  local MedievalCrane = self:GetMedievalCraneFromBase(uNewMovementBase)
  if MedievalCrane and MedievalCrane.AddCharacter then MedievalCrane:AddCharacter(self.Object)
  else
    MedievalCrane = self:GetMedievalCraneFromBase(uOldMovementBase)
    if MedievalCrane and MedievalCrane.RemoveCharacter then MedievalCrane:RemoveCharacter(self.Object) end
  end
end

function BRPlayerCharacterBase:GetMedievalCraneFromBase(Base)
  if not slua.isValid(Base) or not Base.GetOwner then return end
  local Lifter = Base:GetOwner()
  if not slua.isValid(Lifter) or not Lifter.AddCharacter then return end
  return Lifter
end

function BRPlayerCharacterBase:CheckForbidFlaregun()
  local uPlayerState = self:GetPlayerStateSafety()
  if not slua.isValid(uPlayerState) then return false end
  if uPlayerState.CanUseFlaregun == false and self:IsLocallyControlled() then
    local uPlayerController = self:GetPlayerControllerSafety()
    if slua.isValid(uPlayerController) then uPlayerController:DisplayGameTipWithMsgID(48532) end
  end
  return not uPlayerState.CanUseFlaregun
end

function BRPlayerCharacterBase:ServerRPC_NearDeathGiveupRescue() self:HandleNearDeathGiveupRescue() end
function BRPlayerCharacterBase:HandleNearDeathGiveupRescue()
  local uNearDeathComp = self.NearDeatchComponent
  if self:IsNearDeath() and slua.isValid(uNearDeathComp) and self.bCanNearDeathGiveup == true then
    local uPlayerState = self:GetPlayerStateSafety()
    if slua.isValid(uPlayerState) then uPlayerState:AddGeneralCount(1613, 1, false) end
    uNearDeathComp:TriggerGotoDieExplictly(self.Object)
  end
end

function BRPlayerCharacterBase:RPC_Server_GmPlayAction(actionId)
  if USTExtraBlueprintFunctionLibrary.IsDevelopment() then self:MulticastRPC_GmPlayAction(actionId) end
end

function BRPlayerCharacterBase:MulticastRPC_GmPlayAction(actionId)
  if not Client then return end
  local uPlayEmoteComp = self:GetPlayEmoteComponent()
  if not slua.isValid(uPlayEmoteComp) then return end
  local animCfg = CDataTable.GetTableData("EmoteBPTable", actionId)
  if not animCfg then return end
  local handle = slua.loadObject(animCfg.Path)()
  local assetsArray = slua.Array(UEnums.EPropertyClass.Struct, import("/Script/CoreUObject.SoftObjectPath"))
  uPlayEmoteComp:OnLoadEmoteAssetBegin(handle, actionId, assetsArray, "")
  local tb = FuncUtil.LuaArrayToTable(assetsArray)
  local asset_util = require("common.asset_util")
  asset_util.GetAssetsArrayAsyncParallel(tb, function() uPlayEmoteComp:OnLoadEmoteAssetEnd(handle, actionId, 0) end)
end

function BRPlayerCharacterBase:RPC_Client_SetShouldCheckPassWall(b)
  if slua.isValid(self.ParachuteComponent) then self.ParachuteComponent.bServerSyncShouldCheckPassWall = b end
end

function BRPlayerCharacterBase:OnPlayerEnterCarryBoxState()
  self.Super:OnPlayerEnterCarryBoxState()
  if self.CarryDeadBoxFeature then self.CarryDeadBoxFeature:OnPlayerEnterCarryBoxState() end
end
function BRPlayerCharacterBase:OnPlayerLeaveCarryBoxState(b)
  self.Super:OnPlayerLeaveCarryBoxState(b)
  if self.CarryDeadBoxFeature then self.CarryDeadBoxFeature:OnPlayerLeaveCarryBoxState(b) end
end
function BRPlayerCharacterBase:ServerRPC_CarryDeadBox(u)
  if slua.isValid(u) and Game:IsClassOf(u, import("/Script/ShadowTrackerExtra.PlayerTombBox")) and self.CarryDeadBoxFeature then
    self.CarryDeadBoxFeature:CarryDeadBox(u)
  end
end

function BRPlayerCharacterBase:SetAreaID(A) self:SetAttrValue("AreaID", A, -1) end
function BRPlayerCharacterBase:GetAreaID() return math.floor(self:GetAttrValue("AreaID") + 0.5) end
function BRPlayerCharacterBase:CannotChangeIntoPetSpectator() return self.bCannotChangeIntoPetSpectator end
function BRPlayerCharacterBase:DoModChangeToBT()
  if self:HasState(EPawnState.SpecialSuit) then self:TriggerEntrySkillWithID(4301101, true) end
end

function BRPlayerCharacterBase:SwitchCameraToParachuteOpening()
  self.Super:SwitchCameraToParachuteOpening()
  if self.ParachuteFormation and self.ParachuteFormation.ShouldApplyFormationCamera and self.ParachuteFormation:ShouldApplyFormationCamera() then self.ParachuteFormation:OverlayFormationCameraParams() end
end
function BRPlayerCharacterBase:SwitchCameraToParachuteFalling()
  self.Super:SwitchCameraToParachuteFalling()
  if self.ParachuteFormation and self.ParachuteFormation.ShouldApplyFormationCamera and self.ParachuteFormation:ShouldApplyFormationCamera() then self.ParachuteFormation:OverlayFormationCameraParams() end
end
function BRPlayerCharacterBase:SwitchCameraToNormal()
  self.Super:SwitchCameraToNormal()
  if self.ParachuteFormation and self.ParachuteFormation.OnLandingClearFormationCamera then self.ParachuteFormation:OnLandingClearFormationCamera() end
end

function BRPlayerCharacterBase:SwitchWeaponCheck(Slot, IgnoreState)
  if self:HasState(EPawnState.AttachToOther) then
    local Weapon = self:GetWeaponBySlot(Slot)
    if slua.isValid(Weapon) then
      local WeaponID = Weapon:GetWeaponID()
      local AttachToOtherConfig = GamePlayTools.GetCurrentConfig("AttachToOtherConfig")
      if AttachToOtherConfig and AttachToOtherConfig.CheckIsWeaponInBlackList and AttachToOtherConfig.CheckIsWeaponInBlackList(WeaponID) then
        local uPlayerController = self:GetPlayerControllerSafety()
        if Client and slua.isValid(uPlayerController) and uPlayerController.Role == ENetRole.ROLE_AutonomousProxy then uPlayerController:DisplayGameTipWithMsgID(47306) end
        return false
      end
    end
  end
  return self.Super:SwitchWeaponCheck(Slot, IgnoreState)
end

-- ==============================================================================
-- ========================== CHEN VIP MOD v6 ===================================
-- ==============================================================================

local function Notify(msg)
    local s = "[CHEN VIP] " .. tostring(msg)
    pcall(function() if _G.LexusNotify then _G.LexusNotify(s) end end)
    pcall(function()
        local sh = import("ScriptHelperClient")
        if sh and sh.AddOnScreenDebugMessage then sh.AddOnScreenDebugMessage(s, -1, 3.0, {R=1,G=1,B=0,A=1}, {X=1.2,Y=1.2}) end
    end)
    print(s)
end

local _slua = rawget(_G, "slua")
local function Valid(obj)
    if not obj then return false end
    if _slua and _slua.isValid then
        local ok, v = pcall(_slua.isValid, obj)
        if not ok or not v then return false end
    end
    return true
end

local C_GREEN = {R=0,G=255,B=0,A=255}
local C_RED = {R=255,G=0,B=0,A=255}
local C_CYAN = {R=0,G=255,B=255,A=255}
local C_YELLOW = {R=255,G=255,B=0,A=255}
local C_WHITE = {R=255,G=255,B=255,A=255}
local C_ORANGE = {R=255,G=165,B=0,A=255}
local C_PURPLE = {R=200,G=0,B=255,A=255}
local C_BLUE_TEXT = {R=0,G=200,B=255,A=255}
local C_GRAY = {R=160,G=160,B=160,A=255}
local SCALE_COLOR_V2 = {R=3,G=3,B=0,A=0}

local GLOBAL_BONE_LIST = {
    "head","neck_01","pelvis",
    "upperarm_r","lowerarm_r","hand_r",
    "upperarm_l","lowerarm_l","hand_l",
    "thigh_l","calf_l","foot_l",
    "thigh_r","calf_r","foot_r"
}
local GLOBAL_CONNECTIONS = {
    {"neck_01","pelvis",C_YELLOW},
    {"neck_01","upperarm_l",C_CYAN},{"upperarm_l","lowerarm_l",C_CYAN},{"lowerarm_l","hand_l",C_CYAN},
    {"neck_01","upperarm_r",C_CYAN},{"upperarm_r","lowerarm_r",C_CYAN},{"lowerarm_r","hand_r",C_CYAN},
    {"pelvis","thigh_l",C_CYAN},{"thigh_l","calf_l",C_CYAN},{"calf_l","foot_l",C_CYAN},
    {"pelvis","thigh_r",C_CYAN},{"thigh_r","calf_r",C_CYAN},{"calf_r","foot_r",C_CYAN}
}

_G.LexusConfig = _G.LexusConfig or {
    -- ESP base
    CustomMagicBullet=false, AutoHead=false,
    EspVip=false, EspDistance=false, EspVipPro=false,
    EspRadar=false, EspLoai5=false, EspLoai6=false, EspLoai7=false,
    EspAntenna=false, EspOutline=false, OutlineThickness=10,
    -- ESP new
    EspBox2D=false, EspBoxCorner=false, EspSnapline=false,
    EspHpBarVert=false, EspArmorBar=false, EspAimArrow=false,
    EspReloadTag=false, EspVehicleEsp=false, EspAirdropEsp=false,
    EspLastSeen=false, EspSelfPlate=false,
    EspBoxStyle=1, EspSkeletonStyle=1, EspNameColor=1,
    EspShowName=true, EspShowWeapon=true, EspShowState=true,
    EspShowKnocked=true, EspShowBotTag=true,
    EspDistanceUnit=1, EspMaxDistance=400,
    -- Aimbot base
    UnlockFPS=false, IpadView=false,
    CustomAimbot=false, CustomAimbotClose=false,
    CustomHRecoil=false, CustomVRecoil=false,
    LessShake=false, Accuracy=false,
    GodMode=false, WallClimb=false, FastCar=false,
    Crosshair=false, RemoveGrass=false, RemoveFog=false, RemoveRain=false,
    WhiteBody=false, ColorBodyV2=false, WallXuyenTuong=false, BlackSky=false, BrightNight=false,
    -- Aimbot new
    AimTriggerbot=false, AimShowFOVCircle=false, AimSwitchDelay=0, AimPriorityMode=1,
    AimBoneMask=1,
    -- AimTouch branches (existing)
    AimTouchEnable=false,
    AimTouchHipfire=true, AimTouchSG=true, AimTouchScopeAll=true, AimTouchScopeSniper=true,
    AimTouchHipVisCheck=false, AimTouchSGVisCheck=false,
    AimTouchScopeVisCheck=false, AimTouchSniperVisCheck=false,
    AimTouchHipIgKnock=false, AimTouchSGIgKnock=false,
    AimTouchHipIgBot=false, AimTouchSGIgBot=false,
    AimTouchScopeIgKnock=false, AimTouchScopeIgBot=false,
    AimTouchSniperIgKnock=false, AimTouchSniperIgBot=false,
    AimTouchSGAutoFire=false,
    -- Skin
    ModSkin=false, SkinOptionOpen=false, LiveStyleChange=false,
    -- Lost Tomb
    EnableDamageAnalysis=false, IgnoreFallingDamage=false,
    DisableAIIgnoreEnemyTarget=false, EnableMeleeDamageReport=false,
    ShowKnowledgeUI=false, EnableQTESystem=false, EnablePoisonSystem=false,
    AutoHideWeapon=false, CharacterOverrideAvatar=false,
    EnableSkillFlowReport=false, EnableSupplyBoxEvolution=false,
    EnableMaxWalkSpeedCurve=false, ShowHeadHPBar=false,
    EnableCustomGender=false, EnableLoadingAvatar=false,
    EnableSmokeParticle=false, EnableDamageShake=false,
    EnableStealLifeEffect=false, EnableTombBoxFilter=false,
    EnableGameStartSpeedUp=false, ExtraEnergyBonus=false, BehindAttackBonus=false,
    -- BGMI 4.6 movement
    SkyFlyJump=false, JumpHighSingle=false, JumpBoostContinuous=false,
    SafeSpeed=false, LowGravity=false, WallClimb2=false,
    -- Top HUD
    TopHUDProfile=false, TopHUDUID=false, TopHUDStats=false, TopHUDOutfit=false,
    TopHUDEnemyPlate=false, TopHUDBotPlate=false,
    -- World / hit feedback
    HitMarker=false, DamageNumbers=false,
    KillFeed=false, FPSPingHUD=false, DamageLog=false,
    -- Safety
    PanicKey=false, BypassLoop=true,
    -- Info
    EnemyCountHUD=false,
}

_G.LexusState = _G.LexusState or {
    LoopToken=0, NativeESPReady=false, GraphicsUnlocked=false,
    MenuStep=0, LastCmdTime=0,
    TrackedMarks={}, EnemyMarks={},
    LastAimbotCheckTime=0, CustomTextData=nil,
    LastAimbotConfigString="", MagicUpdateVersion=1, LastMagicConfigHash="",
    PrevGraphicsState={},
    StealLifeCount=0, KillPlayerNum=0, IsInMineArea=false,
    AIIgnoreEnemyTarget_RefCount=0, SmokeParticleList={},
    CachedSkillFlow={}, LastPlayEmoteID=nil,
    IsShowLoadingAvatar=false, IsCloseCharacterOverrideAvatar=false,
    LastSeenMarks={}, KillFeedHistory={}, DamageLogHistory={},
    JumpCooldown=0, SpeedRestore=0, OrigJumpZ=nil, OrigMaxWalk=nil,
    PrevAimTarget=nil, PrevAimTargetTime=0,
    LastLiveSuit=nil, LastLiveWeapon=nil, LastLiveVehicle=nil,
    PanicActive=false, LastBypassTick=0,
}

-- ============================================================================
-- BYPASS v5 — same core + panic + loop
-- ============================================================================
local function nop() return true end
local function retFalse() return false end
local function retZero() return 0 end
local function retEmpty() return {} end
local function retNil() return nil end
local function retTrue() return true end
local function retEmptyString() return "" end

local function InitializeSLUABypass()
    pcall(function()
        if slua and slua.getSignature then slua.getSignature = function() return 0xDEADBEEF end end
        local loader = package.loaded["slua.loader"] or rawget(_G, "slua_loader")
        if loader then
            loader.verifyBytecode = retTrue
            loader.checkIntegrity = retTrue
            if loader.disableSignatureCheck then loader.disableSignatureCheck = retTrue end
        end
        local ser = package.loaded["slua.serialize"]
        if ser then ser.check = retTrue; ser.verify = retTrue end
        if jit and jit.attach then jit.attach(function() end, "bc") end
        if _G.slua_verify then _G.slua_verify = retTrue end
        if _G.check_slua_integrity then _G.check_slua_integrity = retTrue end
    end)
end

local function InitializeMD5Bypass()
    pcall(function()
        local console = import("KismetSystemLibrary")
        if console then
            console.ExecuteConsoleCommand(nil, "pak.DisablePakSignatureCheck 1")
            console.ExecuteConsoleCommand(nil, "pakchunk.EnableSignatureCheck 0")
            console.ExecuteConsoleCommand(nil, "s.VerifyPak 0")
            console.ExecuteConsoleCommand(nil, "sig.Check 0")
            console.ExecuteConsoleCommand(nil, "security.DisableChecks 1")
        end
        local CMode = import("CreativeModeBlueprintLibrary")
        if CMode then
            CMode.MD5HashByteArray = function() return "00000000000000000000000000000000" end
            CMode.MD5HashFile = function() return "00000000000000000000000000000000" end
            CMode.GetContentDiffData = function() return true, "BYPASSED" end
            CMode.VerifyFileIntegrity = retTrue
        end
        if _G.MD5Hash then _G.MD5Hash = function() return "00000000000000000000000000000000" end end
        if _G.CRC32 then _G.CRC32 = function() return 0 end end
        if _G.SHA1 then _G.SHA1 = function() return "BYPASS" end end
        local FHC = package.loaded["common.file_hash_checker"]
        if FHC then FHC.CheckFileMD5 = retTrue; FHC.VerifyAll = retTrue; FHC.GetHash = function() return "BYPASS" end end
        local Tss = package.loaded["TssSdk"] or _G.TssSdk
        if Tss then Tss.GetFileMD5 = function() return "BYPASS" end; Tss.VerifyFileSignature = retTrue end
        local STExtra = import("STExtraBlueprintFunctionLibrary")
        if STExtra then STExtra.CheckMD5 = retTrue; STExtra.GetMD5 = function() return "BYPASS" end; STExtra.VerifyFile = retTrue end
    end)
end

local function InitializeLogBlocker()
    pcall(function()
        local SMTD = import("ScreenshotMTDer")
        if SMTD then SMTD.MTDePicture=function() return "" end; SMTD.ReMTDePicture=function() return "" end; SMTD.HasCaptured=retTrue; SMTD.TakeScreenshot=nop end
        local TLog = package.loaded["TLog"] or _G.TLog
        if TLog then TLog.Info=nop; TLog.Warning=nop; TLog.Error=nop; TLog.Debug=nop; TLog.Report=nop; TLog.Send=nop; TLog.Flush=nop end
        local CS = package.loaded["CrashSight"] or _G.CrashSight
        if CS then CS.ReportException=nop; CS.SetCustomData=nop; CS.Log=nop; CS.SendCrash=nop; CS.ReportUserException=nop end
        local GRU = package.loaded["GameLua.Mod.BaseMod.Gameplay.GameReport.GameReportUtils"]
        if GRU then
            GRU.BugglyPostExceptionFull=retFalse
            GRU.CheckCanBugglyPostException=retFalse
            GRU.ReplayReportData=nop
            GRU.ReportGameException=nop
            GRU.PostException=nop
        end
        local CTR = package.loaded["client.slua.logic.report.ClientToolsReport"]
        if CTR then CTR.SendReport=nop; CTR.SendException=nop; CTR.UploadLog=nop end
        for _, sdk in ipairs({"Firebase","Adjust","AppsFlyer","FacebookAnalytics","GameAnalytics"}) do
            local s = _G[sdk]
            if s then s.logEvent=nop; s.trackEvent=nop; s.setEnabled=retFalse; s.sendEvent=nop; s.report=nop end
        end
    end)
end

local function InitializeScannerBlocker()
    pcall(function()
        local SubMgr = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
        if SubMgr then
            local subs = {"AFKReportorSubsystem","ClientDataStatistcsSubsystem","AvatarExceptionSubsystem","ShootVerifySubSystemClient","MemoryCheckSubsystem","SpeedCheckSubsystem","WallCheckSubsystem","FileCheckSubsystem","BehaviorScoreSubsystem","AntiCheatSubsystem","IntegrityCheckSubsystem","SignatureVerifySubsystem","MD5CheckSubsystem","PakVerifySubsystem"}
            for _, name in ipairs(subs) do
                local sub = SubMgr:Get(name)
                if sub then
                    for k, v in pairs(sub) do
                        if type(v) == "function" and (k:find("Report") or k:find("Send") or k:find("Upload") or k:find("Verify") or k:find("Check") or k:find("Validate") or k:find("Scan") or k:find("Detect")) then
                            pcall(function() sub[k] = nop end)
                        end
                    end
                    if sub.ReportPingDelayTimer then pcall(function() sub:RemoveGameTimer(sub.ReportPingDelayTimer) end); sub.ReportPingDelayTimer=nil end
                    sub.DelayCount = 0
                end
            end
        end
        local AvaEx = package.loaded["GameLua.Mod.Library.GamePlay.Avatar.Exception.AvatarExceptionPlayerInst"]
        if AvaEx then
            AvaEx.CheckAvatarException=nop
            AvaEx.CheckAvatarExceptionOnce=nop
            AvaEx.ReportAvatarException=nop
            AvaEx.CheckSlotMeshVisible=retFalse
            AvaEx.CheckPawnVisible=retFalse
            AvaEx.CheckCanBugglyPostException=retFalse
        end
        local Tss = package.loaded["TssSdk"] or _G.TssSdk
        if Tss then
            local origData = Tss.OnRecvData
            Tss.OnRecvData = function(data)
                if type(data) == "string" and (data:find("report") or data:find("exception") or data:find("cheat") or data:find("violation") or data:find("hack") or data:find("verify")) then return end
                if origData then origData(data) end
            end
            Tss.SendReportInfo=nop
            Tss.ScanMemory=retTrue
            Tss.IsEmulator=retFalse
            Tss.GetTssSdkReportInfo=retEmptyString
            Tss.CheckEnvironment=retTrue
            Tss.VerifyProcess=retTrue
            Tss.GetDeviceInfo=function() return "BYPASS_"..tostring(math.random(100000,999999)) end
            Tss.GetAntiData=retEmptyString
            Tss.SendAntiData=nop
        end
    end)
end

local function InitializeReportFlowBlocker()
    pcall(function()
        local flows = {"ReportAimFlow","ReportHitFlow","ReportAttackFlow","ReportSecAttackFlow","ReportFireArms","ReportVerifyInfoFlow","ReportMrpcsFlow","ReportPlayerBehavior","ReportTeammatHurt","ReportMisKillByTeammate","ReportForbitPick","ReportPlayerMoveRoute","ReportPlayerPosition","ReportVehicleMoveFlow","ReportSecTgameMovingFlow","ReportParachuteData","ReportEquipmentFlow","ReportPlayersPing","ReportPlayerIP","ReportPlayerFramePingRecord","ReportDSNetSaturation","ReportNetContinuousSaturate","ReportDSNetRate","ReportCircleFlow","ReportSecMrpcsFlow","ReportHurtFlow","ReportUseSkillFlow"}
        for _, f in ipairs(flows) do
            if _G[f] then _G[f] = nop end
            if _G.GameplayCallbacks and _G.GameplayCallbacks[f] then _G.GameplayCallbacks[f] = nop end
        end
        for _, f in ipairs({"CheckReportSecAttackFlowWithAttackFlow","CheckReportSecAttackFlow"}) do
            if _G[f] then _G[f] = retFalse end
            if _G.GameplayCallbacks and _G.GameplayCallbacks[f] then _G.GameplayCallbacks[f] = retFalse end
        end
        for _, f in ipairs({"IsEnableReportMrpcsInCircleFlow","IsEnableReportMrpcsInPartCircleFlow","IsEnableReportMrpcsFlow","IsEnableReportAttackFlow","IsEnableReportHitFlow","IsEnableReportCircleFlow"}) do
            if _G[f] then _G[f] = retFalse end
        end
    end)
end

local function InitializePlayerSecurityBypass()
    pcall(function()
        for _, c in ipairs({"PlayerSecurityInfoCollector","PlayerSecurityInfo","SecurityInfoCollector","ClientSecurityCollector","PlayerAntiCheatCollector"}) do
            if _G[c] then
                for k, v in pairs(_G[c]) do
                    if type(v) == "function" and (k:find("Report") or k:find("Collect") or k:find("Send") or k:find("Upload") or k:find("Record")) then
                        _G[c][k] = nop
                    end
                end
            end
        end
        local SecSub = require("GameLua.Mod.BaseMod.Common.Security.PlayerSecurityInfoSubsystem")
        if SecSub then SecSub.ReportData=nop; SecSub.CheckCheat=retFalse; SecSub.ValidatePlayer=retTrue; SecSub.CollectData=nop; SecSub.SendToServer=nop end
    end)
end

local function InitializeClientFlowBypass()
    pcall(function()
        for _, name in ipairs({"ClientSecMrpcsFlow","MrpcsFlow","MrpcsData","ClientCircleFlowSubsystem","ClientKillFlowSubsystem","ClientSecPlayerKillFlow"}) do
            local sub = package.loaded[name] or _G[name]
            if sub then
                for k, v in pairs(sub) do
                    if type(v) == "function" and (k:find("Report") or k:find("Send") or k:find("Flow") or k:find("Record") or k:find("Process")) then
                        pcall(function() sub[k] = nop end)
                    end
                end
            end
        end
    end)
end

local function InitializeSwiftHawkBypass()
    pcall(function()
        for _, f in ipairs({"SwiftHawk","ClientSwiftHawk","ClientSwiftHawkWithParams","SendSwiftHawkData"}) do
            if _G[f] then _G[f] = nop end
            if _G.GameplayCallbacks and _G.GameplayCallbacks[f] then _G.GameplayCallbacks[f] = nop end
        end
        local sub = package.loaded["GameLua.Mod.BaseMod.Client.Security.SwiftHawkSubsystem"]
        if sub then sub.ReportData=nop; sub.SendReport=nop; sub.CollectTelemetry=nop end
    end)
end

local function InitializeCoronaLabBypass()
    pcall(function()
        if _G.CoronaLab then _G.CoronaLab.ReportData=nop; _G.CoronaLab.SendData=nop; _G.CoronaLab.CollectData=nop; _G.CoronaLab.Telemetry=nop end
        local sub = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr"):Get("CoronaLabSubsystem")
        if sub then sub.ReportData=nop; sub.SendToServer=nop; sub.CollectTelemetry=nop; sub.StopCollection=nop end
    end)
end

local function InitializeModifierExceptionBypass()
    pcall(function()
        if _G.bReportedModifierException then _G.bReportedModifierException = false end
        local sub = require("GameLua.Mod.BaseMod.Common.Security.ModifierExceptionSubsystem")
        if sub then sub.ReportException=nop; sub.CheckModifier=retTrue; sub.ValidateModifier=retTrue; sub.ReportModifierError=nop end
    end)
end

local function InitializeSimulateCharacterLocationBypass()
    pcall(function()
        local sub = require("GameLua.Mod.BaseMod.Gameplay.Simulate.SimulateCharacterSubsystem")
        if sub then sub.ReportLocation=nop; sub.SendLocationData=nop; sub.VerifyLocation=retTrue end
    end)
end

local function InitializeShootVerificationBypass()
    pcall(function()
        local sub = require("GameLua.Dev.Subsystem.ShootVerifySubSystemClient")
        if sub then
            sub.OnShootVerifyFailed=nop
            sub.SendVerifyData=nop
            sub.ReportBulletHit=nop
            sub.UploadHitInfo=nop
            sub.VerifyShot=retTrue
        end
        if _G.BulletHitInfoUploadData then
            _G.BulletHitInfoUploadData.Report=nop
            _G.BulletHitInfoUploadData.Send=nop
            _G.BulletHitInfoUploadData.Upload=nop
        end
    end)
end

local function InitializeNetworkPacketBlock()
    pcall(function()
        if NetUtil and NetUtil.SendPacket then
            local orig = NetUtil.SendPacket
            local blocked = {
                ["ReportAttackFlow"]=1,["ReportSecAttackFlow"]=1,["ReportFireArms"]=1,["ReportVerifyInfoFlow"]=1,
                ["ReportMrpcsFlow"]=1,["ReportPlayerBehavior"]=1,["ReportTeammatHurt"]=1,["ReportPlayerMoveRoute"]=1,
                ["ReportPlayerPosition"]=1,["ReportSecVehicleMoveFlow"]=1,["report_parachute_data"]=1,
                ["on_tss_sdk_anti_data"]=1,["ReportAimFlow"]=1,["ReportHitFlow"]=1,["ReportCircleFlow"]=1,
                ["report_players_ping"]=1,["report_player_ip"]=1,["report_net_saturate"]=1,
                ["report_speed_hack"]=1,["report_wall_hack"]=1,["report_aim_bot"]=1,["report_esp_usage"]=1,
                ["report_modded_files"]=1,["detect_cheat"]=1,["ban_player"]=1,["client_anti_cheat_report"]=1,
                ["ClientSecMrpcsFlow"]=1,["MrpcsData"]=1,["CheckReportSecAttackFlow"]=1,
                ["CheckReportSecAttackFlowWithAttackFlow"]=1,["RPC_ClientCoronaLab"]=1,
                ["CoronaLabReport"]=1,["CoronaLabData"]=1,["PlayerSecurityInfo"]=1,["ReportSecurityInfo"]=1,
                ["SendSecurityData"]=1,["ClientCircleFlow"]=1,["IsEnableReportMrpcsInCircleFlow"]=1,
                ["IsEnableReportMrpcsInPartCircleFlow"]=1,["bReportedModifierException"]=1,
                ["ReportModifierException"]=1,["RPC_Server_ReportSimulateCharacterLocation"]=1,
                ["ReportSimulateCharacterLocation"]=1,["RPC_Client_ShootVertifyRes"]=1,
                ["BulletHitInfoUploadData"]=1,["ShootVerifyFailed"]=1,["report_unrealnet_exception"]=1,
                ["tss_sdk_report"]=1,["SwiftHawk"]=1,["ClientSwiftHawk"]=1,["ClientSwiftHawkWithParams"]=1,
                ["SwiftHawkReport"]=1,["SwiftHawkData"]=1,["AntiCheatReport"]=1,["CheatDetection"]=1,
                ["ViolationReport"]=1,["SecurityViolation"]=1,["IntegrityCheck"]=1,["SignatureVerify"]=1,
                ["ReportHurtFlow"]=1,["ReportUseSkillFlow"]=1,["MeleeDamageReport"]=1,["SkillFlowReport"]=1,
                ["Heartbeat"]=1,["RPC_Server_Heartbeat"]=1,["heartbeat_report"]=1,["ping_heartbeat"]=1,
            }
            NetUtil.SendPacket = function(packetName, ...)
                if blocked[packetName] then return nil end
                return orig(packetName, ...)
            end
            NetUtil.IsBypassed = true
        end
        if _G.SendRPC then
            local origRPC = _G.SendRPC
            local blockedRPC = {"RPC_Server_ClientSecMrpcsFlow","RPC_Server_SwiftHawk","RPC_Server_ClientSwiftHawkWithParams","RPC_Server_ReportSimulateCharacterLocation","RPC_Client_ShootVertifyRes","RPC_ClientCoronaLab","RPC_Server_Heartbeat"}
            _G.SendRPC = function(rpcName, ...)
                for _, b in ipairs(blockedRPC) do if rpcName == b then return nil end end
                return origRPC(rpcName, ...)
            end
        end
    end)
end

local function InitializeHiggsBosonBypass()
    pcall(function()
        local Higgs = require("GameLua.Mod.BaseMod.Common.Security.HiggsBosonComponent")
        if Higgs then
            for _, m in ipairs({"ControlMHActive","Tick","OnTick","MHActiveLogic","TriggerAvatarCheck","StartAvatarCheck","ReportItemID","ReceiveAnyDamage","OnWeaponHitRecord","ShowSecurityAlert","ServerReportAvatar","ClientReportNetAvatar","SendHisarData","ValidateSecurityData","StaticShowSecurityAlertInDev","RPC_Client_ShootVertifyRes","RPC_Server_ReportSimulateCharacterLocation","DisableHiggsBoson","CheckMHActive","ReportViolation","ProcessSecurityEvent","ValidatePlayer","CheckIntegrity"}) do
                if Higgs[m] then Higgs[m] = nop end
            end
            Higgs.GetNetAvatarItemIDs = retEmpty
            Higgs.GetCurWeaponSkinID = retZero
            Higgs.IsMHActive = retFalse
            Higgs.bMHActive = false
            Higgs.bCallPreReplication = false
            if Higgs.BlackList then for k in pairs(Higgs.BlackList) do Higgs.BlackList[k] = nil end end
        end
        _G.BlackList = {}
        local pc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
        if slua.isValid(pc) then
            if pc.HiggsBoson then pc.HiggsBoson.bMHActive = false; pc.HiggsBoson.bCallPreReplication = false; if pc.HiggsBoson.ControlMHActive then pc.HiggsBoson:ControlMHActive(0) end end
            if pc.HiggsBosonComponent then pc.HiggsBosonComponent.bMHActive = false; pc.HiggsBosonComponent.bCallPreReplication = false; if pc.HiggsBosonComponent.ControlMHActive then pc.HiggsBosonComponent:ControlMHActive(0) end end
        end
    end)
end

local function InitializeKillAllSubsystems()
    pcall(function()
        local subMgr = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
        if not subMgr then return end
        local toKill = {"CoronaLabSubsystem","PlayerSecurityInfoSubsystem","ClientCircleFlowSubsystem","ModifierExceptionSubsystem","SimulateCharacterSubsystem","ShootVerifySubSystemClient","HiggsBosonComponent","ClientReportPlayerSubsystem","DSReportPlayerSubsystem","ClientHawkEyePatrolSubsystem","DSHawkEyePatrolSubsystem","ClientDataStatistcsSubsystem","AFKReportorSubsystem","BehaviorScoreSubsystem","FileCheckSubsystem","MemoryCheckSubsystem","SpeedCheckSubsystem","WallCheckSubsystem","AvatarExceptionSubsystem","GameReportSubsystem","ClientSecMrpcsFlowSubsystem","MrpcsFlowSubsystem","CircleFlowSubsystem","SwiftHawkSubsystem","AntiCheatSubsystem","IntegrityCheckSubsystem","SignatureVerifySubsystem","MD5CheckSubsystem","PakVerifySubsystem"}
        for _, name in ipairs(toKill) do
            local sub = subMgr:Get(name)
            if sub then
                for k, v in pairs(sub) do
                    if type(v) == "function" and (k:find("Report") or k:find("Send") or k:find("Upload") or k:find("Verify") or k:find("Check") or k:find("Validate") or k:find("Scan") or k:find("Detect") or k:find("Collect") or k:find("Flow") or k:find("Heartbeat")) then
                        pcall(function() sub[k] = nop end)
                    end
                end
                if sub.timer then pcall(function() sub:RemoveGameTimer(sub.timer) end) end
                if sub.heartbeatTimer then pcall(function() sub:RemoveGameTimer(sub.heartbeatTimer) end) end
                if sub.reportTimer then pcall(function() sub:RemoveGameTimer(sub.reportTimer) end) end
            end
        end
    end)
end

_G.StartBypass_VIP_v5 = function()
    pcall(function()
        print("[BYPASS v5] init")
        InitializeSLUABypass(); InitializeMD5Bypass(); InitializeLogBlocker()
        InitializeScannerBlocker(); InitializeReportFlowBlocker()
        InitializePlayerSecurityBypass(); InitializeClientFlowBypass(); InitializeSwiftHawkBypass()
        InitializeCoronaLabBypass(); InitializeModifierExceptionBypass(); InitializeSimulateCharacterLocationBypass()
        InitializeShootVerificationBypass(); InitializeNetworkPacketBlock(); InitializeHiggsBosonBypass()
        InitializeKillAllSubsystems()
        print("[BYPASS v5] done")
    end)
end

_G.StartBypass_VIP_v4 = _G.StartBypass_VIP_v5

-- ============================================================================
-- SKIN DATA
-- ============================================================================
_G.VIP_Attachments = {
    [1101004236]={1010042307,1010042306,1010042308,1010042304,1010042300,1010042305,1010042299,1010042298,1010042297,1010042296,1010042295,1010042294,0,1010042314,1010042309,1010042316,1010042317,1010042318,1010042310,1010042315,1010042319,0},
    [1101001116]={1010011106,1010011107,1010011108,0,1010011109,1010011112,1010011105,1010011104,1010011103,0,1010011102,0,0,0,0,0,0,0,0,0,0,0},
    [1101001128]={1010011232,1010011233,1010011234,1010011228,1010011227,1010011229,1010011226,1010011225,1010011224,1010011223,1010011222,0,0,0,0,0,0,0,0,0,0,0},
    [1101001154]={1010011487,1010011488,1010011489,1010011493,1010011490,1010011494,1010011486,1010011485,1010011484,1010011483,1010011482,1010011497,0,0,0,0,0,0,0,0,1010011498,0},
    [1101001174]={1010011667,1010011668,1010011669,1010011673,1010011670,1010011674,1010011666,1010011665,1010011664,1010011663,1010011662,0,0,0,0,0,0,0,0,0,0,0},
    [1101001213]={1010012067,1010012068,1010012069,1010012072,1010012070,1010012073,1010012066,1010012065,1010012064,1010012063,1010012062,0,0,0,0,0,0,0,0,0,1010012074,0},
    [1101001231]={1010012267,1010012268,1010012269,1010012273,1010012272,1010012274,1010012266,1010012265,1010012264,1010012263,1010012262,1010012075,0,0,0,0,0,0,0,0,1010012275,0},
    [1101001242]={1010012357,1010012358,1010012359,1010012363,1010012362,1010012364,1010012356,1010012355,1010012354,1010012353,1010012352,1010012276,0,0,0,0,0,0,0,0,1010012365,0},
    [1101001249]={1010012437,1010012438,1010012439,1010012443,1010012442,1010012444,1010012436,1010012435,1010012434,1010012433,1010012432,1010012366,0,0,0,0,0,0,0,0,1010012445,0},
    [1101001256]={1010012588,1010012589,1010012590,1010012593,1010012592,1010012594,1010012587,1010012586,1010012585,1010012584,1010012583,1010012582,0,0,0,0,0,0,0,0,1010012595,0},
    [1101001265]={1010012698,1010012699,1010012700,1010012703,1010012702,1010012704,1010012697,1010012696,1010012695,1010012694,1010012693,1010012692,0,0,0,0,0,0,0,0,1010012705,0},
    [1101002029]={1010020249,1010020250,1010020255,1010020247,1010020246,1010020248,1010020240,1010020239,1010020238,1010020237,1010020236,1010020235,0,0,0,0,0,0,0,1010020257,1010020256,1010020258},
    [1101003070]={1010030654,1010030653,1010030655,1010030649,1010030648,1010030650,1010030647,1010030646,1010030645,1010030644,1010030643,1010030642,0,1010030658,1010030656,1010030660,1010030662,1010030659,1010030657,0,1010030663,0},
    [1101003080]={1010030754,1010030753,1010030755,1010030749,1010030748,1010030750,1010030747,1010030746,1010030745,1010030744,1010030743,1010030742,0,1010030758,1010030756,1010030760,1010030762,1010030759,1010030757,0,1010030763,0},
    [1101003099]={1010030943,1010030944,1010030945,1010030939,1010030938,1010030942,1010030937,1010030936,1010030935,1010030934,1010030933,1010030932,0,1010030947,1010030946,1010030948,1010030949,1010030953,1010030952,0,1010030955,0},
    [1101004046]={1010040474,1010040475,1010040476,1010040472,1010040471,1010040473,1010040470,1010040469,1010040468,1010040467,1010040466,1010040481,0,1010040479,1010040477,1010040482,1010040483,1010040484,1010040478,1010040480,1010040485,0},
    [1101004062]={1010040578,1010040577,1010040579,1010040575,1010040570,1010040576,1010040569,1010040568,1010040567,1010040566,1010040565,1010040564,0,1010040585,1010040580,1010040587,1010040588,1010040589,1010040584,1010040586,1010040590,1010040594},
    [1101004201]={1010041956,1010041957,1010041958,1010041950,1010041949,1010041955,1010041948,1010041947,1010041946,1010041945,1010041944,1010041967,0,1010041965,1010041959,0,0,0,1010041960,1010041966,0,0},
    [1101004209]={1010042038,1010042037,1010042039,1010042035,1010042034,1010042036,1010042029,1010042028,1010042027,1010042026,1010042025,1010042024,0,1010042046,1010042044,1010042048,1010042049,1010042054,1010042045,1010042047,1010042055,0},
    [1101004218]={1010042128,1010042127,1010042129,1010042125,1010042124,1010042126,1010042119,1010042118,1010042117,1010042116,1010042115,1010042114,0,1010042136,1010042134,1010042138,1010042139,1010042144,1010042135,1010042137,1010042145,0},
    [1101004226]={1010042238,1010042237,1010042239,1010042235,1010042234,1010042236,1010042233,1010042232,1010042231,1010042219,1010042218,1010042217,0,1010042243,1010042241,1010042245,1010042246,1010042247,1010042242,1010042244,1010042248,0},
    [1101004246]={1010042406,1010042407,1010042408,1010042404,1010042400,1010042405,1010042399,1010042398,1010042397,1010042396,1010042395,1010042394,0,1010042414,1010042409,1010042416,1010042417,1010042418,1010042410,1010042415,1010042419,1010042420},
    [1101006062]={1010060573,1010060572,1010060574,1010060564,1010060563,1010060571,1010060562,1010060561,1010060554,1010060553,1010060552,1010060551,0,1010060583,1010060581,1010060591,1010060592,1010060584,1010060582,0,1010060593,0},
    [1101006075]={1010060702,1010060701,1010060703,1010060698,1010060697,1010060699,1010060696,1010060695,1010060694,1010060693,1010060692,1010060691,0,1010060706,1010060704,1010060708,1010060709,1010060707,1010060705,0,1010060711,0},
    [1101006085]={1010060796,1010060795,1010060797,1010060793,1010060789,1010060794,1010060788,1010060787,1010060786,1010060785,1010060784,1010060783,0,1010060800,1010060798,1010060804,1010060805,1010060803,1010060799,0,1010060806,0},
    [1101007071]={1010070663,1010070662,1010070664,1010070659,1010070658,1010070660,1010070657,1010070656,1010070655,1010070654,1010070653,1010070652,0,1010070667,1010070665,1010070668,1010070669,1010070670,1010070666,0,1010070672,0},
    [1101008081]={1010080740,1010080743,1010080745,1010080738,1010080737,1010080739,1010080736,1010080735,1010080734,1010080733,1010080732,1010080748,0,1010080747,1010080746,1010080750,1010080752,1010080749,1010080744,0,1010080753,0},
    [1101008104]={1010080980,1010080982,1010080984,1010080978,1010080977,1010080979,1010080976,1010080975,1010080974,1010080973,1010080972,1010080992,0,1010080986,1010080985,1010080989,1010080987,1010080993,1010080983,0,1010080988,0},
    [1101008136]={1010081314,1010081315,1010081316,1010081312,1010081308,1010081313,1010081307,1010081306,1010081305,1010081304,1010081303,1010081302,0,1010081318,1010081317,1010081322,1010081323,1010081325,1010081324,0,1010081326,0},
    [1101008146]={1010081401,1010081402,1010081403,1010081398,1010081397,1010081399,1010081396,1010081395,1010081394,1010081393,1010081392,1010081391,0,1010081405,1010081404,1010081406,1010081407,1010081409,1010081408,0,1010081411,0},
    [1101008154]={1010081531,1010081532,1010081533,1010081528,1010081527,1010081529,1010081526,1010081525,1010081524,1010081523,1010081522,1010081521,0,1010081541,1010081534,1010081542,1010081543,1010081545,1010081544,0,1010081546,0},
    [1101008163]={1010081582,1010081583,1010081584,1010081579,1010081578,1010081580,1010081577,1010081576,1010081575,1010081574,1010081573,1010081572,0,1010081586,1010081585,1010081587,1010081588,1010081590,1010081589,0,1010081592,0},
    [1101100012]={1011000066,1011000067,1011000068,0,0,0,1011000058,1011000057,1011000056,1011000055,1011000054,1011000053,0,0,0,0,0,0,0,0,1011000073,0},
    [1101102007]={1011010025,1011010024,1011010026,1011010020,1011010019,1011010023,1011010018,1011010017,1011010016,1011010015,1011010014,1011010013,0,0,0,0,0,0,0,0,1011010027,0},
    [1101102017]={1011020027,1011020028,1011020029,1011020025,1011020024,1011020026,1011020019,1011020018,1011020017,1011020016,1011020015,1011020014,0,1011020036,1011020034,1011020038,1011020039,1011020044,1011020035,1011020037,1011020045,1011020047},
    [1101102025]={1011020127,1011020128,1011020129,1011020125,1011020124,1011020126,1011020119,1011020118,1011020117,1011020116,1011020115,1011020114,0,1011020136,1011020134,1011020138,1011020139,1011020144,1011020135,1011020137,1011020145,0},
    [1101102041]={1011020214,1011020215,1011020216,1011020212,1011020211,1011020213,1011020209,1011020208,1011020207,1011020206,1011020205,1011020204,0,1011020219,1011020217,1011020222,1011020223,1011020224,1011020218,1011020221,1011020225,1011020229},
    [1101102049]={1011020356,1011020357,1011020358,1011020354,1011020350,1011020355,1011020349,1011020348,1011020347,1011020346,1011020345,1011020344,0,1011020364,1011020359,1011020366,1011020367,1011020368,1011020360,1011020365,1011020369,1011020370},
    [1101101007]={1011020436,1011020437,1011020438,1011020434,1011020430,1011020435,1011020429,1011020428,1011020427,1011020426,1011020425,1011020424,0,1011020444,1011020439,1011020446,1011020447,1011020448,1011020440,1011020445,1011020449,1011020450},
    [1102002136]={1020021314,1020021313,1020021315,1020021309,1020021308,1020021312,1020021307,1020021306,1020021305,1020021304,1020021303,1020021302,0,1020021318,1020021316,1020021323,1020021324,1020021322,1020021317,0,1020021325,0},
    [1102002424]={1020024193,1020024192,1020024194,1020024189,1020024188,1020024190,1020024187,1020024186,1020024185,1020024184,1020024183,1020024182,0,1020024197,1020024195,1020024199,1020024200,1020024198,1020024196,0,1020024202,0},
    [1103001101]={1030010954,1030010955,1030010956,0,0,0,0,0,0,0,1030010953,1030010952,1030010951,0,0,0,0,0,0,1030010957,0,1030010958},
    [1103001146]={1030011344,1030011345,1030011346,0,0,0,0,0,0,0,1030011343,1030011342,1030011341,0,0,0,0,0,0,1030011347,0,1030011348},
    [1103002030]={1030020245,1030020246,1030020247,1030020252,1030020249,1030020253,1030020258,1030020257,1030020256,1030020255,1030020244,1030020243,1030020242,0,0,0,0,0,0,1030020248,0,0},
    [1103002113]={1030021079,1030021080,1030021082,1030021085,1030021084,1030021086,1030021078,1030021077,1030021076,1030021075,1030021074,1030021073,1030021072,0,0,0,0,0,0,1030021083,1030021087,0},
    [1103003030]={1030030256,1030030257,1030030258,1030030254,1030030253,1030030255,1030030248,1030030247,1030030246,1030030245,1030030244,1030030243,1030030242,0,0,0,0,0,0,1030030259,1030030249,0},
    [1103003079]={1030030744,1030030745,1030030746,1030030742,1030030740,1030030743,1030030738,1030030737,1030030736,1030030735,1030030734,1030030733,1030030732,0,0,0,0,0,0,1030030747,1030030739,0},
    [1103007028]={1030070233,1030070234,1030070235,1030070226,1030070225,1030070227,1030070218,1030070217,1030070216,1030070215,1030070214,1030070213,1030070212,0,0,0,0,0,0,1030070236,1030070219,0},
    [1103102007]={1031020026,1031020027,1031020028,1031020024,1031020023,1031020025,1031020019,1031020018,1031020017,1031020016,1031020015,1031020014,1031020013,0,0,0,0,0,0,1031020029,0,0},
    [1105002091]={0,0,0,0,0,0,1050020847,1050020846,1050020845,1050020844,1050020843,1050020842,0,0,0,0,0,0,0,0,0,1050020848},
}

_G.BaseAttachToIndex = {
    [201010]=1,[201005]=1,[201004]=1,[201009]=2,[201003]=2,[201002]=2,
    [201011]=3,[201007]=3,[201006]=3,[204012]=4,[204005]=4,[204008]=4,
    [204011]=5,[204004]=5,[204007]=5,[204013]=6,[204006]=6,[204009]=6,
    [203001]=7,[203002]=8,[203003]=9,[203014]=10,[203004]=11,[203015]=12,[203005]=13,
    [202002]=14,[202001]=15,[202004]=16,[202005]=17,[202007]=18,[202006]=19,
    [205002]=20,[205003]=20,[205001]=20,[203018]=21,[204014]=22
}

_G.VipAttachToIndex = {}
for skinId, attachList in pairs(_G.VIP_Attachments) do
    for index, attachId in ipairs(attachList) do
        if attachId > 0 then _G.VipAttachToIndex[attachId] = index end
    end
end

_G.WeaponSkinMap = _G.WeaponSkinMap or {}
_G.VehicleSkinMap = _G.VehicleSkinMap or {}
_G.OutfitMap = _G.OutfitMap or {}
_G.skinIdCache = _G.skinIdCache or {}
_G.skinIdCache2 = _G.skinIdCache2 or {}

_G.OutfitSkins = {
    Suit = {403003,1407916,1406469,1405870,1407140,1407141,1407142,1407550,1406638,1406872,1406971,1407103,1407512,1407391,1407366,1407330,1407329,1407286,1407285,1407277,1407276,1407275,1407225,1407224,1407259,1407161,1407160,1407107,1407106,1407079,1407048,1406977,1406976,1406898,1400569,1404000,1404049,1400119,1400117,1406060,1406891,1400687,1405160,1405145,1405436,1405435,1405434,1405064,1405207,1406895,1400333,1400377,1405092,1405121,1406889,1407278,1407279,1407381,1407380,1407385,1406389,1406388,1406387,1406386,1406385,1406140,1400782,1407392,1407318,1407317,1407404,1407402,1407401,1407387,1404434,1404437,1404440,1404448,1400324,1400708,1404043,1404048,1405953,1400101,1404153,1407440,1407441},
    Bag = {
        {501001,501002,501003},{1501001174,1501002174,1501003174},{1501001220,1501002220,1501003220},
        {1501001051,1501002051,1501003051},{1501001443,1501002443,1501003443},{1501001265,1501002265,1501003265},
        {1501001321,1501002321,1501003321},{1501001277,1501002277,1501003277},{1501001550,1501002550,1501003550},
        {1501001592,1501002592,1501003592},{1501001608,1501002608,1501003608},{1501001024,1501002024,1501003024},
        {1501001019,1501002019,1501003019},{1501001179,1501002179,1501003179},{1501001194,1501002194,1501003194},
        {1501001346,1501002346,1501003346}
    },
    Helmet = {
        {502001,502002,502003},{1502001014,1502002014,1502003014},{1502001349,1502002349,1502003349},
        {1502001012,1502002012,1502003012},{1502001009,1502002009,1502003009},{1502001397,1502002397,1502003397},
        {1502001390,1502002390,1502003390},{1502001381,1502002381,1502003381},{1502001358,1502002358,1502003358},
        {1502001350,1502002350,1502003350},{1502001342,1502002342,1502003342}
    },
    Pet = {50000,50001,50002,50003,50004,50005,50006,50021,50022,50038,50039,50040}
}

_G.skinIdMappings = {
    [101004]={101004,1101004246,1101004226,1101004236,1101004062,1101004078,1101004086,1101004201,1101004218},
    [101001]={101001,1101001276,1101001089,1101001213,1101001172,1101001127,1101001230,1101001241},
    [101003]={101003,1101003227,1103003208,1101003195,1101003187,1101003098,1101003166,1101003218},
    [102002]={102002,1102002136,1102002043,1102002061,1102002424},
    [101008]={101008,1101008146,1101008154,1101008079,1101008126,1101008104,1101008061,1101008116},
    [101006]={101006,1101006085,1101006061,1101006074,1101006043,1101006032,1101006084},
    [102001]={102001,1102001120},
    [101005]={101005,1101005098},
    [104003]={104003,1104003037},
    [104004]={104004,1104004035,1104004041}
}

_G.VehicleSkins = {
    [1961001]={1961007,1961010,1961012,1961013,1961014,1961015,1961016,1961017,1961018,1961020,1961021,1961024,1961025,1961029,1961030,1961031,1961032,1961033,1961034,1961035,1961036,1961037,1961038,1961039,1961040,1961041,1961042,1961043,1961044,1961045,1961046,1961047,1961048,1961049,1961050,1961051,1961052,1961053,1961054,1961055,1961056,1961057,1961058,1961059,1961060,1961061,1961062,1961063,1961064,1961065,1961066,1961067,1961068,1961069,1961136,1961137,1961138,1961139,1961140,1961141,1961142,1961143,1961144,1961145,1961147,1961148,1961149,1961150,1961151,1961152,1961153},
    [1903001]={1903005,1903006,1903007,1903008,1903011,1903012,1903013,1903014,1903015,1903016,1903017,1903018,1903019,1903020,1903021,1903022,1903023,1903024,1903029,1903030,1903031,1903032,1903033,1903034,1903035,1903036,1903037,1903039,1903040,1903041,1903042,1903043,1903044,1903045,1903046,1903051,1903052,1903053,1903054,1903055,1903056,1903057,1903058,1903059,1903060,1903061,1903062,1903063,1903066,1903067,1903068,1903069,1903070,1903071,1903072,1903073,1903074,1903075,1903076,1903079,1903080,1903081,1903082,1903084,1903085,1903086,1903087,1903088,1903089,1903090,1903189,1903190,1903191,1903192,1903193,1903194,1903195,1903196,1903197,1903198,1903199,1903200,1903201,1903202,1903203,1903204,1903205,1903206,1903207,1903208,1903209,1903210,1903211,1903212,1903213,1903214,1903215,1903216,1903217,1903218,1903219,1903220,1903221,1903222,1903223,1903225,1903226,1903227,1903228},
    [1915001]={1915002,1915003,1915004,1915005,1915006,1915007,1915008,1915009,1915010,1915011,1915012,1915013,1915014,1915015,1915016,1915017,1915018,1915019,1915020,1915021,1915022,1915023,1915024,1915025,1915026,1915099},
    [1908001]={1908002,1908003,1908005,1908006,1908007,1908008,1908009,1908010,1908011,1908012,1908013,1908015,1908016,1908017,1908018,1908019,1908021,1908023,1908030,1908031,1908032,1908033,1908034,1908035,1908036,1908037,1908039,1908040,1908041,1908043,1908047,1908049,1908050,1908051,1908052,1908053,1908054,1908055,1908056,1908057,1908059,1908060,1908061,1908062,1908063,1908064,1908066,1908067,1908068,1908069,1908070,1908075,1908076,1908077,1908078,1908080,1908081,1908082,1908083,1908084,1908085,1908086,1908087,1908088,1908089,1908091,1908094,1908095,1908096,1908097,1908098,1908099,1908100,1908101,1908102,1908104,1908105,1908106,1908107,1908108,1908109,1908110,1908111,1908112,1908188,1908189},
    [1907001]={1907007,1907008,1907010,1907011,1907012,1907013,1907014,1907016,1907018,1907019,1907021,1907022,1907023,1907025,1907026,1907027,1907028,1907029,1907030,1907032,1907033,1907034,1907035,1907036,1907037,1907038,1907040,1907041,1907043,1907044,1907045,1907046,1907047,1907048,1907049,1907050,1907051,1907052,1907053,1907054,1907055,1907056,1907058,1907059,1907060,1907061,1907062,1907063,1907064,1907065,1907066,1907067,1907068,1907069,1907070,1907071,1907072,1907073,1907074}
}
_G.CustSlotType = { ClothesEquipemtSlot=5, BackpackEquipemtSlot=8, HelmetEquipemtSlot=9, ParachuteEquipemtSlot=11, GlideEquipemtSlot=15 }

local function DownloadGameItem(id)
    local pm = require('client.slua.logic.download.puffer.puffer_manager')
    local pc = require('client.slua.logic.download.puffer_const')
    if pm and pc and pm.GetState(pc.ENUM_DownloadType.ODPTD, {id}) ~= pc.ENUM_DownloadState.Done then
        pm.Download(pc.ENUM_DownloadType.ODPTD, {id})
    end
end
_G.download_item = DownloadGameItem

_G.get_skin_id = function(weaponID)
    if not weaponID then return nil end
    local targetSkinId = _G.WeaponSkinMap and _G.WeaponSkinMap[weaponID]
    if targetSkinId and targetSkinId > 0 then
        if not _G.skinIdCache2[targetSkinId] then
            if _G.download_item then pcall(_G.download_item, targetSkinId) end
            _G.skinIdCache2[targetSkinId] = true
        end
        return targetSkinId
    end
    return weaponID
end

_G.equip_character_avatar = function(Character)
    if not Character or not slua.isValid(Character) or not Character.AvatarComponent2 then return end
    local BackpackUtils = import("BackpackUtils")
    local SlotSyncData = Character.AvatarComponent2.NetAvatarData and Character.AvatarComponent2.NetAvatarData.SlotSyncData
    if not SlotSyncData or not slua.isValid(SlotSyncData) or not BackpackUtils then return end
    local function EquipAvatar(ApplyDataIdx, mappedSkin, ApplyEquipSlot, isLevelDependent, levelFunc)
        if not mappedSkin or mappedSkin == 0 then return end
        local slotData = SlotSyncData:Get(ApplyDataIdx)
        if slotData and slotData.SlotID == ApplyEquipSlot then
            local applyItemId = mappedSkin
            if isLevelDependent and type(mappedSkin) == "table" then
                local level = levelFunc(slotData.AdditionalItemID) or 1
                if level < 1 then level = 1 end
                if level > 3 then level = 3 end
                applyItemId = mappedSkin[level] or mappedSkin[1]
            end
            if not applyItemId or applyItemId == 0 or slotData.ItemId == applyItemId then return end
            if not _G.skinIdCache[applyItemId] then
                if _G.download_item then pcall(_G.download_item, applyItemId) end
                _G.skinIdCache[applyItemId] = true
            end
            slotData.ItemId = applyItemId
            SlotSyncData:Set(ApplyDataIdx, slotData)
        end
    end
    local hasGliderSlot = false
    for i = 0, SlotSyncData:Num() - 1 do
        local slotData = SlotSyncData:Get(i)
        if slotData and slotData.SlotID == _G.CustSlotType.GlideEquipemtSlot then hasGliderSlot = true; break end
    end
    if not hasGliderSlot then SlotSyncData:Add({ SlotID = _G.CustSlotType.GlideEquipemtSlot, ItemId = 0 }) end
    for i = 0, SlotSyncData:Num() - 1 do
        EquipAvatar(i, _G.OutfitMap.Suit or 0, _G.CustSlotType.ClothesEquipemtSlot, false)
        EquipAvatar(i, _G.OutfitMap.Bag, _G.CustSlotType.BackpackEquipemtSlot, true, BackpackUtils.GetEquipmentBagLevel)
        EquipAvatar(i, _G.OutfitMap.Helmet, _G.CustSlotType.HelmetEquipemtSlot, true, BackpackUtils.GetEquipmentHelmetLevel)
        EquipAvatar(i, _G.OutfitMap.Parachute or 0, _G.CustSlotType.ParabuckleEquipemtSlot or _G.CustSlotType.ParachuteEquipemtSlot, false)
    end
    -- FIX: force client rep without server gate
    pcall(function()
        if Character.AvatarComponent2.OnRep_BodySlotStateChanged then
            Character.AvatarComponent2:OnRep_BodySlotStateChanged()
        end
    end)
    pcall(function()
        if Character.AvatarComponent2.OnRep_NetAvatarData then
            Character.AvatarComponent2:OnRep_NetAvatarData()
        end
    end)
    pcall(function()
        if Character.AvatarComponent2.UpdateAllSlotMesh then
            Character.AvatarComponent2:UpdateAllSlotMesh()
        end
    end)
    pcall(function()
        if Character.AvatarComponent2.RefreshAvatar then
            Character.AvatarComponent2:RefreshAvatar()
        end
    end)
end

_G.ApplyWeaponSkins = function(PlayerCharacter)
    pcall(function()
        local WeaponManager = PlayerCharacter:GetWeaponManager()
        if not slua.isValid(WeaponManager) then return end
        for slot = 1, 3 do
            local Weapon = WeaponManager:GetInventoryWeaponByPropSlot(slot)
            if slua.isValid(Weapon) and slua.isValid(Weapon.synData) then
                local WeaponID = Weapon:GetWeaponID()
                local SkinID = _G.get_skin_id(WeaponID) or WeaponID
                local isModified = false
                local SkinData = Weapon.synData:Get(7)
                if SkinData and SkinData.defineID and SkinData.defineID.TypeSpecificID ~= SkinID then
                    SkinData.defineID.TypeSpecificID = SkinID
                    Weapon.synData:Set(7, SkinData)
                    if Weapon.SetWeaponAvatarID then pcall(function() Weapon:SetWeaponAvatarID(SkinID) end) end
                    if not _G.skinIdCache[SkinID] then _G.download_item(SkinID); _G.skinIdCache[SkinID] = true end
                    isModified = true
                end
                if SkinID >= 10000000 and _G.VIP_Attachments and _G.VIP_Attachments[SkinID] then
                    for AttachIdx = 0, 5 do
                        local attachData = Weapon.synData:Get(AttachIdx)
                        if attachData then
                            local defineIDRef = slua.IndexReference(attachData, "defineID")
                            if defineIDRef then
                                local attachmentId = defineIDRef.TypeSpecificID
                                if attachmentId and attachmentId > 0 then
                                    local mapIndex = _G.BaseAttachToIndex[attachmentId] or _G.VipAttachToIndex[attachmentId]
                                    if mapIndex and _G.VIP_Attachments[SkinID][mapIndex] and _G.VIP_Attachments[SkinID][mapIndex] > 0 then
                                        local targetAttachId = _G.VIP_Attachments[SkinID][mapIndex]
                                        if targetAttachId ~= attachmentId then
                                            attachData.defineID.TypeSpecificID = targetAttachId
                                            Weapon.synData:Set(AttachIdx, attachData)
                                            if not _G.skinIdCache2[targetAttachId] then
                                                if _G.download_item then pcall(_G.download_item, targetAttachId) end
                                                _G.skinIdCache2[targetAttachId] = true
                                            end
                                            isModified = true
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
                if isModified then
                    if Weapon.DelayHandleAvatarMeshChanged then pcall(function() Weapon:DelayHandleAvatarMeshChanged() end) end
                    if Weapon.OnRep_synData then pcall(function() Weapon:OnRep_synData() end) end
                end
            end
        end
    end)
end

_G.ApplyVehicleSkins = function(PlayerCharacter)
    pcall(function()
        local Vehicle = PlayerCharacter:GetCurrentVehicle()
        if not slua.isValid(Vehicle) then _G.LastVehicleEntity = nil; return end
        local VehicleAvatar = Vehicle.VehicleAvatar or Vehicle.VehicleAvatarComponent_BP or Vehicle:GetAvatarComponent()
        if not slua.isValid(VehicleAvatar) then return end
        local defId = tostring(VehicleAvatar:GetDefaultAvatarID() or Vehicle.VehicleID or "")
        local currentId = tostring(Vehicle:GetAvatarId() or "")
        local applySkinId = 0
        for baseMapId, targetSkin in pairs(_G.VehicleSkinMap) do
            if defId:find(tostring(baseMapId)) or currentId:find(tostring(baseMapId)) then applySkinId = targetSkin; break end
        end
        if applySkinId and applySkinId > 0 and currentId ~= tostring(applySkinId) then
            _G.skinIdCache = _G.skinIdCache or {}
            if not _G.skinIdCache[applySkinId] then
                if _G.download_item then pcall(_G.download_item, applySkinId) end
                _G.skinIdCache[applySkinId] = true
            end
            VehicleAvatar.curSwitchEffectId = 7303001
            if VehicleAvatar.ChangeItemAvatar then VehicleAvatar:ChangeItemAvatar(applySkinId, true) end
            _G.CurrentEquipVehicleID = applySkinId
            _G.LastVehicleEntity = Vehicle
        end
    end)
end

_G.HandlePetLogic = function()
    pcall(function()
        local petSkin = _G.OutfitMap.Pet
        if not petSkin or petSkin == 0 or petSkin == 50000 or petSkin == _G.LastAppliedPet then return end
        _G.skinIdCache = _G.skinIdCache or {}
        if not _G.skinIdCache[petSkin] then
            if _G.download_item then pcall(_G.download_item, petSkin) end
            _G.skinIdCache[petSkin] = true
        end
        local MM = require("client.module_framework.ModuleManager")
        if MM then
            local logic_pet = MM.GetModule(MM.CommonModuleConfig.logic_pet)
            if logic_pet then
                if logic_pet.SetCurPetID then logic_pet:SetCurPetID(petSkin) end
                if logic_pet.EquipPet then logic_pet:EquipPet(petSkin) end
            end
        end
        _G.LastAppliedPet = petSkin
    end)
end

_G.ForceRefreshSkinMaps = function()
    pcall(function()
        if not _G.LexusState or not _G.LexusState.CustomTextData then return end
        local cData = _G.LexusState.CustomTextData
        if _G.OutfitSkins then
            if cData.SkinSuit and _G.OutfitSkins.Suit[cData.SkinSuit] then _G.OutfitMap.Suit = _G.OutfitSkins.Suit[cData.SkinSuit] end
            if cData.SkinBag and _G.OutfitSkins.Bag[cData.SkinBag] then _G.OutfitMap.Bag = _G.OutfitSkins.Bag[cData.SkinBag] end
            if cData.SkinHelmet and _G.OutfitSkins.Helmet[cData.SkinHelmet] then _G.OutfitMap.Helmet = _G.OutfitSkins.Helmet[cData.SkinHelmet] end
        end
        if _G.skinIdMappings then
            if cData.SkinM416 and _G.skinIdMappings[101004] and _G.skinIdMappings[101004][cData.SkinM416] then _G.WeaponSkinMap[101004] = _G.skinIdMappings[101004][cData.SkinM416] end
            if cData.SkinAKM and _G.skinIdMappings[101001] and _G.skinIdMappings[101001][cData.SkinAKM] then _G.WeaponSkinMap[101001] = _G.skinIdMappings[101001][cData.SkinAKM] end
            if cData.SkinSCAR and _G.skinIdMappings[101003] and _G.skinIdMappings[101003][cData.SkinSCAR] then _G.WeaponSkinMap[101003] = _G.skinIdMappings[101003][cData.SkinSCAR] end
            if cData.SkinM762 and _G.skinIdMappings[101008] and _G.skinIdMappings[101008][cData.SkinM762] then _G.WeaponSkinMap[101008] = _G.skinIdMappings[101008][cData.SkinM762] end
            if cData.SkinAUG and _G.skinIdMappings[101006] and _G.skinIdMappings[101006][cData.SkinAUG] then _G.WeaponSkinMap[101006] = _G.skinIdMappings[101006][cData.SkinAUG] end
            if cData.SkinUMP and _G.skinIdMappings[102002] and _G.skinIdMappings[102002][cData.SkinUMP] then _G.WeaponSkinMap[102002] = _G.skinIdMappings[102002][cData.SkinUMP] end
            if cData.SkinUZI and _G.skinIdMappings[102001] and _G.skinIdMappings[102001][cData.SkinUZI] then _G.WeaponSkinMap[102001] = _G.skinIdMappings[102001][cData.SkinUZI] end
            if cData.SkinGroza and _G.skinIdMappings[101005] and _G.skinIdMappings[101005][cData.SkinGroza] then _G.WeaponSkinMap[101005] = _G.skinIdMappings[101005][cData.SkinGroza] end
            if cData.SkinS12K and _G.skinIdMappings[104003] and _G.skinIdMappings[104003][cData.SkinS12K] then _G.WeaponSkinMap[104003] = _G.skinIdMappings[104003][cData.SkinS12K] end
            if cData.SkinDBS and _G.skinIdMappings[104004] and _G.skinIdMappings[104004][cData.SkinDBS] then _G.WeaponSkinMap[104004] = _G.skinIdMappings[104004][cData.SkinDBS] end
        end
        if _G.VehicleSkins then
            if cData.SkinDacia and _G.VehicleSkins[1903001] and _G.VehicleSkins[1903001][cData.SkinDacia] then _G.VehicleSkinMap[1903001] = _G.VehicleSkins[1903001][cData.SkinDacia] end
            if cData.SkinUAZ and _G.VehicleSkins[1908001] and _G.VehicleSkins[1908001][cData.SkinUAZ] then _G.VehicleSkinMap[1908001] = _G.VehicleSkins[1908001][cData.SkinUAZ] end
            if cData.SkinCoupe and _G.VehicleSkins[1961001] and _G.VehicleSkins[1961001][cData.SkinCoupe] then _G.VehicleSkinMap[1961001] = _G.VehicleSkins[1961001][cData.SkinCoupe] end
            if cData.SkinBuggy and _G.VehicleSkins[1907001] and _G.VehicleSkins[1907001][cData.SkinBuggy] then _G.VehicleSkinMap[1907001] = _G.VehicleSkins[1907001][cData.SkinBuggy] end
            if cData.SkinMirado and _G.VehicleSkins[1915001] and _G.VehicleSkins[1915001][cData.SkinMirado] then _G.VehicleSkinMap[1915001] = _G.VehicleSkins[1915001][cData.SkinMirado] end
        end
    end)
end

-- ============================================================================
-- DEADBOX / KILLCOUNTER
-- ============================================================================
local cached_GameplayStatics = nil
local cached_PlayerTombBox = nil
local cached_ActorClass = nil
_G.NeedCheckDeadBoxTimer = 0

_G.DeadBox_TemperRequest = function(PlayerController)
    if _G.NeedCheckDeadBoxTimer <= 0 then return end
    _G.NeedCheckDeadBoxTimer = _G.NeedCheckDeadBoxTimer - 1
    local PlayerCharacter = PlayerController:GetPlayerCharacterSafety()
    if not slua.isValid(PlayerCharacter) then return end
    if not cached_GameplayStatics then
        cached_GameplayStatics = import("GameplayStatics")
        cached_ActorClass = import("Actor")
        cached_PlayerTombBox = import("PlayerTombBox")
    end
    local UI_Util = require("client.common.ui_util")
    local GI = UI_Util and UI_Util.GetGameInstance()
    if not GI or not cached_GameplayStatics then return end
    local boxes = cached_GameplayStatics.GetAllActorsOfClass(GI, cached_PlayerTombBox, slua.Array(UEnums.EPropertyClass.Object, cached_ActorClass))
    for _, box in pairs(boxes) do
        if slua.isValid(box) and not box.bIsTDSkinApplied then
            local dc = box.DamageCauser
            if dc and dc.PlayerKey == PlayerController.PlayerKey then
                local comp = box.DeadBoxAvatarComponent_BP
                if slua.isValid(comp) then
                    local skinId = 0
                    if PlayerCharacter.CurrentVehicle and _G.CurrentEquipVehicleID and _G.CurrentEquipVehicleID ~= 0 then
                        skinId = tonumber(tostring(_G.CurrentEquipVehicleID) .. "1") or 0
                    else
                        local w = PlayerCharacter:GetCurrentWeapon()
                        if slua.isValid(w) and w.synData then
                            local sd = w.synData:Get(7)
                            if sd and sd.defineID then skinId = sd.defineID.TypeSpecificID end
                        end
                    end
                    if skinId ~= 0 then
                        pcall(function()
                            comp:ResetItemAvatar()
                            comp:PreChangeItemAvatar(skinId)
                            comp:SyncChangeItemAvatar(skinId)
                        end)
                    end
                    box.bIsTDSkinApplied = true
                end
            end
        end
    end
end

_G.TDFTDeKillCounts = _G.TDFTDeKillCounts or {}
local CACHED_LinearColor = import("LinearColor")
local CACHED_GoldColor = CACHED_LinearColor and CACHED_LinearColor(1.0, 0.8, 0.0, 1.0) or nil
local CACHED_UI_Manager = nil

_G.ForceEnableKillCounterUI = function()
    pcall(function()
        local KCUIS = package.loaded["GameLua.Mod.BaseMod.Client.KillCounter.KillCounterUISubsystem"] or require("GameLua.Mod.BaseMod.Client.KillCounter.KillCounterUISubsystem")
        if KCUIS and KCUIS.__inner_impl and not _G.KCUISystemHacked2 then
            local kcImpl = KCUIS.__inner_impl
            kcImpl.CheckSupportKCUI = retTrue
            kcImpl.CheckNeedMainKillCounterUI = function(self, PlayerWeapon)
                if slua.isValid(PlayerWeapon) then
                    local wID = PlayerWeapon:GetWeaponID()
                    self:UpdateMainKillCounterUI(true, wID, _G.get_skin_id(wID) or wID)
                else
                    self:UpdateMainKillCounterUI(false)
                end
            end
            _G.KCUISystemHacked2 = true
        end
        local MM = require("client.module_framework.ModuleManager")
        if MM and not _G.KCLogicHacked2 then
            local LKC = MM.GetModule(MM.CommonModuleConfig.LogicKillCounter)
            if LKC then
                LKC.CheckSupportKC = retTrue
                LKC.CheckSupportKillCounterAvatar = retTrue
                LKC.CheckHasWeaponKillCounter = retTrue
                LKC.GetBaseKillCounterIdByWeaponId = function() return 2100004 end
                LKC.GetEquipedKillCounterId = function() return 2100004 end
                LKC.GetMyEquipedKillCounterId = function() return 2100004 end
                LKC.GetOneWeaponKillCountInBattle = function(self, uid, wID) return _G.TDFTDeKillCounts[wID] or 0 end
                LKC.GetWeaponKillCountByUid = function(self, uid, wID) return _G.TDFTDeKillCounts[wID] or 0 end
                _G.KCLogicHacked2 = true
            end
        end
    end)
end

-- ============================================================================
-- AUTO HEAD
-- ============================================================================
function _G.InitializeAutoHeadHooks()
    pcall(function()
        local EADP = import("EAvatarDamagePosition")
        if not EADP then return end
        for _, path in ipairs({ "GameLua.Mod.BaseMod.Common.Weapon.ShootWeaponEntity", "GameLua.Logic.Weapon.ShootWeaponEntity" }) do
            local hitLogic = package.loaded[path]
            if hitLogic then
                local orig1 = hitLogic.GetHitBodyType
                hitLogic.GetHitBodyType = function(self, IR, IIV)
                    if _G.LexusConfig.AutoHead then return EADP.BigHead end
                    if orig1 then return orig1(self, IR, IIV) end
                end
                local orig2 = hitLogic.GetHitBodyTypeByHitPos
                hitLogic.GetHitBodyTypeByHitPos = function(self, IIV)
                    if _G.LexusConfig.AutoHead then return EADP.BigHead end
                    if orig2 then return orig2(self, IIV) end
                end
            end
        end
    end)
end

-- ============================================================================
-- NATIVE ESP CONFIG
-- ============================================================================
local function InitializeNativeESP()
    if _G.LexusState.NativeESPReady then return end
    pcall(function()
        local GP = require("GameLua.Mod.BaseMod.Common.GamePlayTools")
        local cfg = GP.GetCurrentConfig("ScreenMarkConfig")
        local function Apply(c)
            if not c then return end
            if c[1006] then
                c[1006].bBindBlocked = true; c[1006].bBindOutScreen = true
                c[1006].MaxWidgetNum = 99; c[1006].MaxShowDistance = 6000000
                c[1006].bScaleByDistance = false; c[1006].BindSocketName = "root"
                c[1006].bUseLuaWorldSocketName = true; c[1006].WorldPositionOffset = FVector(0,0,-30)
            end
            if c[1003] then
                c[1003].bBindBlocked = true; c[1003].bBindOutScreen = true
                c[1003].MaxWidgetNum = 99; c[1003].MaxShowDistance = 6000000
                c[1003].bScaleByDistance = false; c[1003].BindSocketName = "head"
                c[1003].bUseLuaWorldSocketName = true
            end
            c[9999] = {
                UIPathName = "/Game/Mod/EvoBase/BluePrints/UIBP/QuickSign/QuickSign_TipHitEnemy_UIBP_New.QuickSign_TipHitEnemy_UIBP_New_C",
                MaxWidgetNum = 99, MaxShowDistance = 6000000,
                bBindOutScreen = true, bBindBlocked = true, bIsBindingActor = true,
                BindSocketName = "head", bUseLuaWorldSocketName = true,
                WorldPositionOffset = FVector(0,0,50), bNeedPreLoad = true, Priority = 2
            }
        end
        Apply(cfg)
        for k, c in pairs(package.loaded) do
            if type(k) == "string" and string.find(k, "ScreenMarkConfig") and type(c) == "table" then Apply(c) end
        end
    end)
    _G.LexusState.NativeESPReady = true
end

-- ============================================================================
-- HELPERS
-- ============================================================================
local function SafeAddMark(id, pos, z, str, size, actor)
    local mark = nil
    pcall(function()
        local T = require("GameLua.Mod.BaseMod.Common.InGameMarkTools")
        if T and T.ClientAddMapMark then
            mark = T.ClientAddMapMark(id, pos, z, str, size, actor)
            if mark then _G.LexusState.TrackedMarks[mark] = true end
        end
    end)
    return mark
end
local function SafeRemoveMark(mark)
    if not mark then return end
    pcall(function()
        local T = require("GameLua.Mod.BaseMod.Common.InGameMarkTools")
        if T and T.HideMapMark then T.HideMapMark(mark) end
        if T and T.RemoveMapMark then T.RemoveMapMark(mark) end
    end)
    _G.LexusState.TrackedMarks[mark] = nil
end
local function GetSafeEnemyKey(enemy)
    if Valid(enemy) then
        if enemy.PlayerKey then return tostring(enemy.PlayerKey) end
        if type(enemy.GetUniqueID) == "function" then return tostring(enemy:GetUniqueID()) end
    end
    return tostring(enemy)
end
local function CheckIsAI(pawn, markData)
    if markData.AK_IS_BOT ~= nil then return markData.AK_IS_BOT, true end
    local isAI = false
    local hasChecked = false
    pcall(function()
        if pawn.bIsAI == true or pawn.IsAI == true then isAI = true; hasChecked = true end
        if type(pawn.IsBot) == "function" and pawn:IsBot() then isAI = true; hasChecked = true end
        local pState = pawn.PlayerState or (type(pawn.GetPlayerState) == "function" and pawn:GetPlayerState())
        if Valid(pState) then
            hasChecked = true
            if pState.bIsABot == true or pState.bIsBot == true then isAI = true end
            if type(pState.IsBot) == "function" and pState:IsBot() then isAI = true end
        end
        if not isAI then
            local name = pawn.PlayerName or (type(pawn.GetPlayerName) == "function" and pawn:GetPlayerName()) or ""
            if name ~= "" and (name:find("Cobra") or name:find("Target") or name:find("bot_") or name:find("b_")) then
                isAI = true; hasChecked = true
            end
        end
    end)
    if hasChecked then markData.AK_IS_BOT = isAI end
    return isAI, hasChecked
end

local function GetAllSkeletalMeshes(enemy, markData)
    local curTime = os.clock()
    if markData and markData.CachedMeshes and markData.CachedMeshTime and (curTime - markData.CachedMeshTime < 3.0) then
        local v = {}
        for _, m in ipairs(markData.CachedMeshes) do if Valid(m) then table.insert(v, m) end end
        markData.CachedMeshes = v
        return v
    end
    local meshes = {}
    if Valid(enemy.Mesh) then table.insert(meshes, enemy.Mesh) end
    pcall(function()
        local SMC = import("SkeletalMeshComponent")
        if SMC and type(enemy.GetComponentsByClass) == "function" then
            local childs = enemy:GetComponentsByClass(SMC)
            if childs then
                local count = type(childs.Num) == "function" and childs:Num() or #childs
                for i = 1, count do
                    local comp = type(childs.Get) == "function" and childs:Get(i-1) or childs[i]
                    if Valid(comp) and comp ~= enemy.Mesh then table.insert(meshes, comp) end
                end
            end
        end
    end)
    if markData then markData.CachedMeshes = meshes; markData.CachedMeshTime = curTime end
    return meshes
end

local function ApplyWallXuyenTuong(enemy, markData)
    pcall(function()
        for _, mesh in ipairs(GetAllSkeletalMeshes(enemy, markData)) do
            if Valid(mesh) then
                pcall(function()
                    if type(mesh.SetRenderCustomDepth) == "function" then mesh:SetRenderCustomDepth(true) end
                    if type(mesh.SetCustomDepthStencilValue) == "function" then mesh:SetCustomDepthStencilValue(252) end
                end)
                for i = 0, 10 do
                    local mi = mesh:GetMaterial(i)
                    if not Valid(mi) then break end
                    local bm = mi:GetBaseMaterial()
                    if Valid(bm) then bm.bDisableDepthTest = true; bm.BlendMode = 2 end
                end
            end
        end
    end)
end
local function UndoWallXuyenTuong(enemy, markData)
    pcall(function()
        if markData.WallhackApplied then
            for _, mesh in ipairs(GetAllSkeletalMeshes(enemy, markData)) do
                if Valid(mesh) then
                    pcall(function() if type(mesh.SetRenderCustomDepth) == "function" then mesh:SetRenderCustomDepth(false) end end)
                    for i = 0, 10 do
                        local mi = mesh:GetMaterial(i)
                        if Valid(mi) then
                            local bm = mi:GetBaseMaterial()
                            if Valid(bm) then bm.bDisableDepthTest = false end
                        end
                    end
                end
            end
            markData.WallhackApplied = false
        end
    end)
end

local function ApplyColorBodyV2(enemy, pc, markData)
    pcall(function()
        local meshes = GetAllSkeletalMeshes(enemy, markData)
        if #meshes == 0 then return end
        local hidden = true
        pcall(function()
            if Valid(pc) and type(pc.LineOfSightTo) == "function" then
                if pc:LineOfSightTo(enemy) then hidden = false end
            end
        end)
        local cData = _G.LexusState.CustomTextData or {}
        local hiddenColor = {R=cData.HiddenR or 150, G=cData.HiddenG or 0, B=cData.HiddenB or 0, A=cData.HiddenA or 25}
        local visibleColor = {R=cData.VisibleR or 0, G=cData.VisibleG or 150, B=cData.VisibleB or 0, A=cData.VisibleA or 25}
        local fc = hidden and hiddenColor or visibleColor
        local hash = string.format("%d_%d_%d_%d", fc.R, fc.G, fc.B, fc.A)
        if markData.LastMeshCount == #meshes and markData.LastHiddenState == hidden and markData.LastColorHash == hash then return end
        markData.LastHiddenState = hidden
        markData.LastMeshCount = #meshes
        markData.LastColorHash = hash
        markData.ColorApplied = true
        for _, mesh in ipairs(meshes) do
            if Valid(mesh) then
                pcall(function()
                    mesh.LDMaxDrawDistance = -99999
                    mesh.MaxDrawDistanceOffset = -99999
                    mesh.CachedMaxDrawDistance = -99999
                    mesh.UseScopeDistanceCulling = true
                    mesh.PrimitiveShadingStrategy = 1
                    mesh.ShadingRate = 6
                end)
                for i = 0, 10 do
                    local mi = mesh:GetMaterial(i)
                    if not Valid(mi) then break end
                    local bm = mi:GetBaseMaterial()
                    if Valid(bm) and string.find(tostring(bm), "Master_Mask", 1, true) then
                        if not markData.MIDs then markData.MIDs = {} end
                        local ms = tostring(mesh)
                        if not markData.MIDs[ms] then markData.MIDs[ms] = {} end
                        local mid = markData.MIDs[ms][i]
                        if not Valid(mid) then
                            mid = mesh:CreateAndSetMaterialInstanceDynamic(i)
                            markData.MIDs[ms][i] = mid
                        end
                        if Valid(mid) then
                            mid:SetVectorParameterValue("颜色", fc)
                            mid:SetVectorParameterValue("Para_Color", fc)
                            mid:SetVectorParameterValue("Para_ColorTint", fc)
                            mid:SetVectorParameterValue("Tint", fc)
                            mid:SetVectorParameterValue("Color", fc)
                            mid:SetVectorParameterValue("BaseColor", fc)
                            mid:SetVectorParameterValue("BodyColor", fc)
                            mid:SetVectorParameterValue("EmissiveColor", fc)
                            mid:SetVectorParameterValue("ParaScaleOffset", SCALE_COLOR_V2)
                        end
                    end
                end
            end
        end
    end)
end
local function UndoColorBodyV2(enemy, markData)
    pcall(function()
        if markData.ColorApplied then
            for _, mesh in ipairs(GetAllSkeletalMeshes(enemy, markData)) do
                if Valid(mesh) then
                    pcall(function() mesh.PrimitiveShadingStrategy = 0; mesh.ShadingRate = 1 end)
                    if markData.MIDs and markData.MIDs[tostring(mesh)] then
                        for _, mid in pairs(markData.MIDs[tostring(mesh)]) do
                            if Valid(mid) then
                                local d = {R=1,G=1,B=1,A=1}
                                mid:SetVectorParameterValue("颜色", d)
                                mid:SetVectorParameterValue("Para_Color", d)
                                mid:SetVectorParameterValue("Tint", d)
                                mid:SetVectorParameterValue("Color", d)
                                mid:SetVectorParameterValue("BaseColor", d)
                                mid:SetVectorParameterValue("EmissiveColor", d)
                            end
                        end
                    end
                end
            end
            markData.ColorApplied = false
            markData.LastColorHash = ""
        end
    end)
end

-- ============================================================================
-- AIMBOT (AimTouch v4)
-- ============================================================================
_G.GetEnemyTargetsFromActors = function(radius)
    local result = {}
    local player = GameplayData.GetPlayerCharacter()
    if not slua.isValid(player) then return result end
    local allChars = {}
    if GameplayData.GetAllPlayerCharacters then allChars = GameplayData.GetAllPlayerCharacters()
    elseif GameplayData.GameCharacters then for _, c in pairs(GameplayData.GameCharacters) do table.insert(allChars, c) end end
    local myTeam = player:GetTeamID()
    for _, actor in pairs(allChars) do
        if slua.isValid(actor) and actor ~= player and actor.GetTeamID and actor:IsAlive() then
            if actor:GetTeamID() ~= myTeam then
                if player:GetDistanceTo(actor) <= radius then table.insert(result, actor) end
            end
        end
    end
    return result
end

_G.AimTouch = function()
    pcall(function()
        if not _G.LexusConfig.AimTouchEnable then return end
        local player = GameplayData.GetPlayerCharacter()
        if not slua.isValid(player) then return end
        local pc = player:GetPlayerControllerSafety()
        if not slua.isValid(pc) then return end

        local isFiring = player.bIsWeaponFiring
        local isADS = player.bIsGunADS
        local weapon = player.WeaponManagerComponent and player.WeaponManagerComponent.CurrentWeaponReplicated
        if not weapon and type(player.GetCurrentShootWeapon) == "function" then weapon = player:GetCurrentShootWeapon() end

        local isSG, isSniper = false, false
        if slua.isValid(weapon) then
            local wn = type(weapon.GetWeaponName) == "function" and weapon:GetWeaponName() or ""
            if wn:find("S686") or wn:find("S1897") or wn:find("S12") or wn:find("DBS") or wn:find("M1014") then isSG = true end
            if wn:find("Kar98") or wn:find("M24") or wn:find("AWM") or wn:find("Mosin") or wn:find("Win94") or wn:find("AMR") or wn:find("SKS") or wn:find("SLR") or wn:find("Mini") or wn:find("Mk14") or wn:find("QBU") or wn:find("Mk12") or wn:find("VSS") then isSniper = true end
        end

        local cond, prioMode, boneIdx = 2, 1, 1
        local speedVal, fovVal, maxDistMeters = 50, 30, 50
        local useVisCheck, igKnock, igBot, autoFire = false, false, false, false
        local branchActive = false

        if isSG and _G.LexusConfig.AimTouchSG then
            branchActive = true
            cond = _G.LexusState.CustomTextData.AimTouchSGCond or 1
            if _G.LexusConfig.AimTouchSGAutoFire then autoFire = true; cond = 2 end
            prioMode = _G.LexusState.CustomTextData.AimTouchSGPrio or 1
            boneIdx = _G.LexusState.CustomTextData.AimTouchSGBone or 2
            speedVal = _G.LexusState.CustomTextData.AimTouchSGSpeed or 80
            fovVal = _G.LexusState.CustomTextData.AimTouchSGFOV or 40
            maxDistMeters = _G.LexusState.CustomTextData.AimTouchSGDist or 30
            useVisCheck = _G.LexusConfig.AimTouchSGVisCheck
            igKnock = _G.LexusConfig.AimTouchSGIgKnock
            igBot = _G.LexusConfig.AimTouchSGIgBot
        elseif isADS then
            if isSniper and _G.LexusConfig.AimTouchScopeSniper then
                branchActive = true
                cond = _G.LexusState.CustomTextData.AimTouchSniperCond or 2
                prioMode = _G.LexusState.CustomTextData.AimTouchSniperPrio or 1
                boneIdx = _G.LexusState.CustomTextData.AimTouchSniperBone or 1
                speedVal = _G.LexusState.CustomTextData.AimTouchSniperSpeed or 30
                fovVal = _G.LexusState.CustomTextData.AimTouchSniperFOV or 20
                maxDistMeters = _G.LexusState.CustomTextData.AimTouchSniperDist or 400
                useVisCheck = _G.LexusConfig.AimTouchSniperVisCheck
                igKnock = _G.LexusConfig.AimTouchSniperIgKnock
                igBot = _G.LexusConfig.AimTouchSniperIgBot
            elseif _G.LexusConfig.AimTouchScopeAll then
                branchActive = true
                cond = _G.LexusState.CustomTextData.AimTouchScopeCond or 1
                prioMode = _G.LexusState.CustomTextData.AimTouchScopePrio or 1
                boneIdx = _G.LexusState.CustomTextData.AimTouchScopeBone or 2
                speedVal = _G.LexusState.CustomTextData.AimTouchScopeSpeed or 40
                fovVal = _G.LexusState.CustomTextData.AimTouchScopeFOV or 20
                maxDistMeters = _G.LexusState.CustomTextData.AimTouchScopeDist or 300
                useVisCheck = _G.LexusConfig.AimTouchScopeVisCheck
                igKnock = _G.LexusConfig.AimTouchScopeIgKnock
                igBot = _G.LexusConfig.AimTouchScopeIgBot
            end
        else
            if _G.LexusConfig.AimTouchHipfire then
                branchActive = true
                cond = _G.LexusState.CustomTextData.AimTouchHipCond or 1
                prioMode = _G.LexusState.CustomTextData.AimTouchHipPrio or 1
                boneIdx = _G.LexusState.CustomTextData.AimTouchHipBone or 1
                speedVal = _G.LexusState.CustomTextData.AimTouchHipSpeed or 50
                fovVal = _G.LexusState.CustomTextData.AimTouchHipFOV or 30
                maxDistMeters = _G.LexusState.CustomTextData.AimTouchHipDist or 250
                useVisCheck = _G.LexusConfig.AimTouchHipVisCheck
                igKnock = _G.LexusConfig.AimTouchHipIgKnock
                igBot = _G.LexusConfig.AimTouchHipIgBot
            end
        end
        if not branchActive then return end
        if cond == 1 and not isFiring then return end

        local curTime = os.clock()
        local currentMaxDist = maxDistMeters * 100
        local enemies = _G.GetEnemyTargetsFromActors(currentMaxDist)
        if not enemies or #enemies == 0 then return end

        local FVector2D = import("Vector2D")
        local UG = import("GameplayStatics")
        local KML = import("KismetMathLibrary")
        local camMgr = UG.GetPlayerCameraManager(pc, 0)
        if not slua.isValid(camMgr) then return end
        local camLoc = camMgr:GetCameraLocation()
        if not camLoc then return end
        local ui_util = require("client.common.ui_util")
        if not ui_util then return end
        local vp = ui_util.GetViewportSize()
        if not vp then return end
        local cX, cY = vp.X * 0.5, vp.Y * 0.5
        local FOV_RADIUS = (fovVal / 100.0) * (vp.X / 2.0)

        local selBone = "head"
        if boneIdx == 1 then selBone = "head"
        elseif boneIdx == 2 then selBone = "spine_03"
        elseif boneIdx == 3 then selBone = "spine_01"
        elseif boneIdx == 4 then selBone = "pelvis" end

        local bestTarget, bestScore = nil, 99999999
        for _, target in ipairs(enemies) do
            if slua.isValid(target) then
                pcall(function() if slua.isValid(target.Mesh) then target.Mesh.MeshComponentUpdateFlag = 0 end end)
                local skip = false
                if igKnock and target.HealthStatus == 1 then skip = true end
                if not skip and igBot then
                    local tBot = false
                    if target.bIsAI == true or target.IsAI == true then tBot = true end
                    local ps = target.PlayerState
                    if slua.isValid(ps) and (ps.bIsABot or ps.bIsBot) then tBot = true end
                    if tBot then skip = true end
                end
                if not skip and useVisCheck then
                    local hidden = true
                    pcall(function() if pc:LineOfSightTo(target) then hidden = false end end)
                    if hidden then skip = true end
                end
                if not skip then
                    local tPos = target:GetBonePos(selBone, {X=0,Y=0,Z=0})
                    if not tPos or (tPos.X == 0 and tPos.Y == 0 and tPos.Z == 0) then
                        if type(target.GetSocketLocation) == "function" then tPos = target:GetSocketLocation(selBone) end
                    end
                    if not tPos or (tPos.X == 0 and tPos.Y == 0 and tPos.Z == 0) then
                        if type(target.K2_GetActorLocation) == "function" then
                            tPos = target:K2_GetActorLocation()
                            if tPos then
                                if boneIdx == 1 then tPos.Z = tPos.Z + 70
                                elseif boneIdx == 2 then tPos.Z = tPos.Z + 40
                                elseif boneIdx == 3 then tPos.Z = tPos.Z + 20 end
                            end
                        end
                    end
                    if tPos and not (tPos.X == 0 and tPos.Y == 0 and tPos.Z == 0) then
                        local screen = FVector2D()
                        local ok = pc:ProjectWorldLocationToScreen(tPos, screen, false)
                        if ok and screen.X > 0 and screen.Y > 0 then
                            local dx, dy = screen.X - cX, screen.Y - cY
                            local distScreen = math.sqrt(dx*dx + dy*dy)
                            if distScreen <= FOV_RADIUS then
                                local score = distScreen
                                if prioMode == 2 then score = player:GetDistanceTo(target)
                                elseif prioMode == 3 then score = target.Health or 100
                                elseif prioMode == 4 then
                                    local hp = target.Health or 100
                                    local mx = target.HealthMax or 100
                                    if mx <= 0 then mx = 100 end
                                    score = hp / mx
                                end
                                if score < bestScore then
                                    if _G.LexusConfig.AimSwitchDelay > 0 and Valid(_G.LexusState.PrevAimTarget) and _G.LexusState.PrevAimTarget ~= target then
                                        if curTime - _G.LexusState.PrevAimTargetTime < (_G.LexusConfig.AimSwitchDelay / 1000.0) then
                                            goto continue
                                        end
                                    end
                                    bestScore = score
                                    bestTarget = target
                                end
                                ::continue::
                            end
                        end
                    end
                end
            end
        end
        if not slua.isValid(bestTarget) then return end

        if _G.LexusState.PrevAimTarget ~= bestTarget then
            _G.LexusState.PrevAimTarget = bestTarget
            _G.LexusState.PrevAimTargetTime = curTime
        end

        local fb = bestTarget:GetBonePos(selBone, {X=0,Y=0,Z=0})
        if not fb or (fb.X == 0 and fb.Y == 0 and fb.Z == 0) then
            if type(bestTarget.GetSocketLocation) == "function" then fb = bestTarget:GetSocketLocation(selBone) end
        end
        if not fb or (fb.X == 0 and fb.Y == 0 and fb.Z == 0) then
            if type(bestTarget.K2_GetActorLocation) == "function" then
                fb = bestTarget:K2_GetActorLocation()
                if fb then
                    if boneIdx == 1 then fb.Z = fb.Z + 70
                    elseif boneIdx == 2 then fb.Z = fb.Z + 40
                    elseif boneIdx == 3 then fb.Z = fb.Z + 20 end
                end
            end
        end
        if not fb or (fb.X == 0 and fb.Y == 0 and fb.Z == 0) then return end

        local rot = KML.FindLookAtRotation(camLoc, fb)
        if not rot then return end
        local cur = pc:GetControlRotation()
        if not cur then return end
        local dy = rot.Yaw - cur.Yaw
        local dp = rot.Pitch - cur.Pitch
        if dy > 180 then dy = dy - 360 end
        if dy < -180 then dy = dy + 360 end
        if dp > 180 then dp = dp - 360 end
        if dp < -180 then dp = dp + 360 end
        local sf = 0.0
        if speedVal >= 100 then sf = 1.0
        else sf = math.max(0.01, (speedVal / 100.0) * 0.3) end
        pc:SetControlRotation({ Pitch = cur.Pitch + (dp * sf), Yaw = cur.Yaw + (dy * sf), Roll = 0 }, "AimTouch")

        if autoFire then
            pcall(function()
                if (player:GetDistanceTo(bestTarget) / 100) <= maxDistMeters then
                    player.bIsWeaponFiring = true
                    if type(player.SetIsWeaponFiring) == "function" then player:SetIsWeaponFiring(true) end
                    if slua.isValid(pc) and type(pc.SetIsWeaponFiring) == "function" then pc:SetIsWeaponFiring(true) end
                    local wm = player.WeaponManagerComponent
                    if slua.isValid(wm) then wm.bIsWeaponFiring = true end
                    local w = player:GetCurrentWeapon()
                    if slua.isValid(w) and type(w.StartFire) == "function" then w:StartFire() end
                end
            end)
        end
    end)
end

-- TRIGGERBOT
_G.TriggerbotTick = function(pc, localPlayer)
    pcall(function()
        if not _G.LexusConfig.AimTriggerbot then return end
        if not Valid(pc) or not Valid(localPlayer) then return end
        local ui_util = require("client.common.ui_util")
        if not ui_util then return end
        local vp = ui_util.GetViewportSize()
        if not vp then return end
        local cX, cY = vp.X * 0.5, vp.Y * 0.5
        local FVector2D = import("Vector2D")
        local enemies = _G.GetEnemyTargetsFromActors(50000)
        for _, enemy in ipairs(enemies) do
            if slua.isValid(enemy) then
                local hp = enemy:GetBonePos("head", {X=0,Y=0,Z=0})
                if hp and not (hp.X == 0 and hp.Y == 0 and hp.Z == 0) then
                    local screen = FVector2D()
                    local ok = pc:ProjectWorldLocationToScreen(hp, screen, false)
                    if ok then
                        local dx, dy = screen.X - cX, screen.Y - cY
                        if math.sqrt(dx*dx + dy*dy) < 12 then
                            local w = localPlayer:GetCurrentWeapon()
                            if slua.isValid(w) and type(w.StartFire) == "function" then
                                local wm = localPlayer.WeaponManagerComponent
                                if slua.isValid(wm) then wm.bIsWeaponFiring = true end
                                w:StartFire()
                            end
                            break
                        end
                    end
                end
            end
        end
    end)
end

-- FOV CIRCLE
_G.DrawFOVCircle = function(pc, localPlayer)
    pcall(function()
        if not _G.LexusConfig.AimShowFOVCircle then return end
        local MyHUD = pc and pc.MyHUD
        if not Valid(MyHUD) then return end
        local fovVal = 30
        if _G.LexusConfig.AimTouchHipfire and not localPlayer.bIsGunADS then
            fovVal = _G.LexusState.CustomTextData.AimTouchHipFOV or 30
        elseif localPlayer.bIsGunADS then
            fovVal = _G.LexusState.CustomTextData.AimTouchScopeFOV or 20
        end
        MyHUD:AddDebugText("◯", localPlayer, 0.0, {X=0,Y=0,Z=150}, {X=0,Y=0,Z=150}, C_ORANGE, true, false, true, nil, fovVal / 30.0, true)
    end)
end

-- ============================================================================
-- MOVEMENT (glitch-safe)
-- ============================================================================
local function MovementTick(localPlayer)
    pcall(function()
        local cm = localPlayer.CharacterMovement
        if not Valid(cm) then return end
        -- cache originals
        if not _G.LexusState.OrigJumpZ then _G.LexusState.OrigJumpZ = cm.JumpZVelocity end
        if not _G.LexusState.OrigMaxWalk then _G.LexusState.OrigMaxWalk = cm.MaxWalkSpeed end

        local curTime = os.clock()

        -- HIGH JUMP SINGLE — set jump Z once on toggle, restore on off
        if _G.LexusConfig.JumpHighSingle then
            cm.JumpZVelocity = (_G.LexusState.OrigJumpZ or 600) * 1.8
        else
            if cm.JumpZVelocity ~= _G.LexusState.OrigJumpZ then cm.JumpZVelocity = _G.LexusState.OrigJumpZ end
        end

        -- SAFE SPEED 1.15x — clamp under server tolerance
        if _G.LexusConfig.SafeSpeed then
            cm.MaxWalkSpeed = (_G.LexusState.OrigMaxWalk or 600) * 1.15
        else
            if cm.MaxWalkSpeed ~= _G.LexusState.OrigMaxWalk then cm.MaxWalkSpeed = _G.LexusState.OrigMaxWalk end
        end

        -- SKY FLY JUMP — only when falling AND input gated, cooldown 0.35s
        if _G.LexusConfig.SkyFlyJump then
            if cm.MovementMode == EMovementMode.MOVE_Falling and curTime > _G.LexusState.JumpCooldown then
                pcall(function()
                    localPlayer.JumpCurrentCount = 0
                    if type(localPlayer.Jump) == "function" then localPlayer:Jump() end
                    if type(localPlayer.Jump) ~= "function" and type(localPlayer.StartJump) == "function" then localPlayer:StartJump() end
                end)
                _G.LexusState.JumpCooldown = curTime + 0.35
            end
        end

        -- LOW GRAVITY — restore when off
        if _G.LexusConfig.LowGravity then
            cm.GravityScale = 0.4
        else
            if not _G.LexusConfig.SkyFlyJump and cm.GravityScale ~= 1.0 then cm.GravityScale = 1.0 end
        end
    end)
end

-- ============================================================================
-- LIVE CHARACTER STYLE
-- ============================================================================
local function LiveStyleChangeTick(localPlayer)
    pcall(function()
        if not _G.LexusConfig.LiveStyleChange then return end
        if not _G.LexusState.CustomTextData then return end
        local curSuit = _G.LexusState.CustomTextData.SkinSuit
        if curSuit and _G.LexusState.LastLiveSuit ~= curSuit then
            _G.LexusState.LastLiveSuit = curSuit
            if _G.OutfitSkins and _G.OutfitSkins.Suit[curSuit] then _G.OutfitMap.Suit = _G.OutfitSkins.Suit[curSuit] end
            if _G.equip_character_avatar then _G.equip_character_avatar(localPlayer) end
            Notify("Suit → #" .. tostring(curSuit))
        end
        local curBag = _G.LexusState.CustomTextData.SkinBag
        if curBag and _G.LexusState.LastLiveBag ~= curBag then
            _G.LexusState.LastLiveBag = curBag
            if _G.OutfitSkins and _G.OutfitSkins.Bag[curBag] then _G.OutfitMap.Bag = _G.OutfitSkins.Bag[curBag] end
            if _G.equip_character_avatar then _G.equip_character_avatar(localPlayer) end
        end
        local curHelm = _G.LexusState.CustomTextData.SkinHelmet
        if curHelm and _G.LexusState.LastLiveHelmet ~= curHelm then
            _G.LexusState.LastLiveHelmet = curHelm
            if _G.OutfitSkins and _G.OutfitSkins.Helmet[curHelm] then _G.OutfitMap.Helmet = _G.OutfitSkins.Helmet[curHelm] end
            if _G.equip_character_avatar then _G.equip_character_avatar(localPlayer) end
        end
    end)
end

local function LiveWeaponVehicleTick(localPlayer)
    pcall(function()
        if not _G.LexusConfig.LiveStyleChange then return end
        -- weapon
        local wm = localPlayer:GetWeaponManager()
        if slua.isValid(wm) then
            for slot = 1, 3 do
                local w = wm:GetInventoryWeaponByPropSlot(slot)
                if slua.isValid(w) then
                    local wid = w:GetWeaponID()
                    local curSkin = _G.get_skin_id(wid)
                    if curSkin and curSkin ~= _G.LexusState.LastLiveWeapon then
                        _G.LexusState.LastLiveWeapon = curSkin
                        if _G.ApplyWeaponSkins then _G.ApplyWeaponSkins(localPlayer) end
                    end
                end
            end
        end
        -- vehicle
        local veh = localPlayer:GetCurrentVehicle()
        if slua.isValid(veh) then
            local vid = veh:GetAvatarId()
            if vid and vid ~= _G.LexusState.LastLiveVehicle then
                _G.LexusState.LastLiveVehicle = vid
                if _G.ApplyVehicleSkins then _G.ApplyVehicleSkins(localPlayer) end
            end
        end
    end)
end

-- ============================================================================
-- TOP HUD — self AND per-enemy plates
-- ============================================================================
local function DrawSelfHUD(pc, localPlayer)
    pcall(function()
        if not (_G.LexusConfig.TopHUDProfile or _G.LexusConfig.TopHUDUID or _G.LexusConfig.TopHUDStats or _G.LexusConfig.TopHUDOutfit) then return end
        local hud = pc and pc.MyHUD
        if not Valid(hud) then return end
        local lines = {}
        if _G.LexusConfig.TopHUDProfile then
            local n = "Player"
            pcall(function()
                if localPlayer.PlayerName then n = localPlayer.PlayerName
                elseif type(localPlayer.GetPlayerName) == "function" then n = localPlayer:GetPlayerName() end
            end)
            table.insert(lines, {t="👤 "..tostring(n), c=C_CYAN})
        end
        if _G.LexusConfig.TopHUDUID then
            local uid = "0"
            pcall(function()
                local ps = localPlayer:GetPlayerStateSafety()
                if Valid(ps) then
                    if ps.PlayerUID then uid = tostring(ps.PlayerUID)
                    elseif ps.UID then uid = tostring(ps.UID) end
                end
            end)
            table.insert(lines, {t="🆔 "..uid, c=C_WHITE})
        end
        if _G.LexusConfig.TopHUDStats then
            local k, hp = 0, 0
            pcall(function()
                local ps = localPlayer:GetPlayerStateSafety()
                if Valid(ps) then k = ps.KillCount or ps.Kills or 0 end
                hp = localPlayer.Health or 0
            end)
            table.insert(lines, {t="🎯 K:"..tostring(k).." ❤ "..math.floor(hp), c=C_YELLOW})
        end
        if _G.LexusConfig.TopHUDOutfit then
            local o = "Default"
            pcall(function()
                if _G.OutfitMap.Suit and _G.OutfitMap.Suit > 0 then o = "Suit#"..tostring(_G.OutfitMap.Suit) end
            end)
            table.insert(lines, {t="👕 "..o, c=C_PURPLE})
        end
        local baseZ, stepZ = 200, 22
        for i, ln in ipairs(lines) do
            local z = baseZ - ((i-1) * stepZ)
            hud:AddDebugText(ln.t, localPlayer, 0.0, {X=0,Y=0,Z=z}, {X=0,Y=0,Z=z}, ln.c, true, false, true, nil, 0.9, true)
        end
    end)
end

local function DrawEnemyPlate(hud, enemy, distM, isBot, hpRatio, isKnock, enemyName)
    pcall(function()
        if not Valid(hud) then return end
        if not (_G.LexusConfig.TopHUDEnemyPlate or _G.LexusConfig.TopHUDProfile or _G.LexusConfig.TopHUDUID or _G.LexusConfig.TopHUDStats) then return end
        if isBot and not _G.LexusConfig.TopHUDBotPlate then return end
        if distM > (_G.LexusConfig.EspMaxDistance or 400) then return end

        local scale = math.max(0.5, 0.9 - (distM / 500))
        local baseZ = 420
        local stepZ = 20 * scale

        local tag = isBot and "[BOT]" or "[PLAYER]"
        local tagC = isBot and C_CYAN or C_ORANGE
        hud:AddDebugText(tag, enemy, 0.06, {X=0,Y=0,Z=baseZ}, {X=0,Y=0,Z=baseZ}, tagC, true, false, true, nil, scale*1.0, true)
        baseZ = baseZ - stepZ

        if _G.LexusConfig.TopHUDProfile or _G.LexusConfig.TopHUDEnemyPlate then
            local nm = enemyName or "Enemy"
            if isKnock and _G.LexusConfig.EspShowKnocked then nm = "KNOCK "..nm end
            hud:AddDebugText(nm, enemy, 0.06, {X=0,Y=0,Z=baseZ}, {X=0,Y=0,Z=baseZ}, C_WHITE, true, false, true, nil, scale*1.05, true)
            baseZ = baseZ - stepZ
        end

        if _G.LexusConfig.TopHUDUID then
            local uid = "0"
            pcall(function()
                local ps = enemy:GetPlayerStateSafety()
                if Valid(ps) then
                    if ps.PlayerUID then uid = tostring(ps.PlayerUID)
                    elseif ps.UID then uid = tostring(ps.UID) end
                end
            end)
            hud:AddDebugText("UID:"..uid, enemy, 0.06, {X=0,Y=0,Z=baseZ}, {X=0,Y=0,Z=baseZ}, C_GRAY, true, false, true, nil, scale*0.9, true)
            baseZ = baseZ - stepZ
        end

        if _G.LexusConfig.TopHUDStats then
            local k, hp = 0, 100
            pcall(function()
                local ps = enemy:GetPlayerStateSafety()
                if Valid(ps) then k = ps.KillCount or ps.Kills or 0 end
                hp = math.floor((hpRatio or 1) * 100)
            end)
            hud:AddDebugText("K:"..tostring(k).." HP:"..hp.."%", enemy, 0.06, {X=0,Y=0,Z=baseZ}, {X=0,Y=0,Z=baseZ}, C_YELLOW, true, false, true, nil, scale*0.95, true)
        end
    end)
end

-- ============================================================================
-- HIT MARKER / DAMAGE NUMBERS / KILL FEED / FPS-PING / DMG LOG
-- ============================================================================
local function HitMarkerTick(pc)
    pcall(function()
        if not _G.LexusConfig.HitMarker then return end
        local hud = pc and pc.MyHUD
        if not Valid(hud) then return end
        local localPlayer = pc:GetPlayerCharacterSafety()
        if not Valid(localPlayer) then return end
        if localPlayer.bJustHitEnemy or (localPlayer.LastHitTime and os.clock() - localPlayer.LastHitTime < 0.15) then
            hud:AddDebugText("✕", localPlayer, 0.0, {X=0,Y=0,Z=0}, {X=0,Y=0,Z=0}, C_RED, true, false, true, nil, 2.0, true)
        end
    end)
end

local function FPSPingTick(pc)
    pcall(function()
        if not _G.LexusConfig.FPSPingHUD then return end
        local hud = pc and pc.MyHUD
        if not Valid(hud) then return end
        local lp = pc:GetPlayerCharacterSafety()
        if not Valid(lp) then return end
        local fps = 0
        pcall(function()
            local ug = import("GameplayStatics")
            if ug.GetFrameCount then fps = math.floor(1.0 / math.max(0.001, ug.GetWorldDeltaSeconds(pc:GetWorld()))) end
        end)
        local ping = 0
        pcall(function()
            local ps = lp:GetPlayerStateSafety()
            if Valid(ps) then ping = ps.Ping or ps.PingInMs or 0 end
        end)
        hud:AddDebugText(string.format("FPS:%d PING:%d", fps, ping), lp, 0.0, {X=0,Y=0,Z=-100}, {X=0,Y=0,Z=-100}, C_WHITE, true, false, true, nil, 0.8, true)
    end)
end

local function KillFeedTick(pc)
    pcall(function()
        if not _G.LexusConfig.KillFeed then return end
        local hud = pc and pc.MyHUD
        if not Valid(hud) then return end
        local lp = pc:GetPlayerCharacterSafety()
        if not Valid(lp) then return end
        local hist = _G.LexusState.KillFeedHistory or {}
        local baseZ = -200
        for i, entry in ipairs(hist) do
            if i > 5 then break end
            local z = baseZ - ((i-1) * 20)
            hud:AddDebugText(entry, lp, 0.0, {X=0,Y=0,Z=z}, {X=0,Y=0,Z=z}, C_WHITE, true, false, true, nil, 0.75, true)
        end
    end)
end

-- ============================================================================
-- WORLD / GRAPHICS extras
-- ============================================================================
local function WorldExtrasTick(pc, localPlayer)
    pcall(function()
        local lsg = require("client.slua.logic.setting.logic_setting_graphics")
        local gi = lsg.GetGameInstance()
        if not gi then return end
        -- remove rain
        if _G.LexusConfig.RemoveRain and not _G.LexusState.PrevGraphicsState.RemoveRain then
            gi:ExecuteCMD("r.VolumetricFog", "0"); gi:ExecuteCMD("r.VolumetricCloud", "0")
            gi:ExecuteCMD("r.Weather", "0")
            _G.LexusState.PrevGraphicsState.RemoveRain = true
        elseif not _G.LexusConfig.RemoveRain and _G.LexusState.PrevGraphicsState.RemoveRain then
            gi:ExecuteCMD("r.Weather", "1")
            _G.LexusState.PrevGraphicsState.RemoveRain = false
        end
        -- bright night
        if _G.LexusConfig.BrightNight and not _G.LexusState.PrevGraphicsState.BrightNight then
            gi:ExecuteCMD("r.TonemapperGamma", "3.0")
            _G.LexusState.PrevGraphicsState.BrightNight = true
        elseif not _G.LexusConfig.BrightNight and _G.LexusState.PrevGraphicsState.BrightNight then
            gi:ExecuteCMD("r.TonemapperGamma", "2.2")
            _G.LexusState.PrevGraphicsState.BrightNight = false
        end
    end)
end

-- ============================================================================
-- LOST TOMB loop
-- ============================================================================
local function LostTombFeaturesLoop()
    pcall(function()
        local lp = GameplayData.GetPlayerCharacter()
        if not Valid(lp) then return end
        if _G.LexusConfig.IgnoreFallingDamage then pcall(function() lp:SetAttrValue("LandDamageReduce", 1, -1) end) end
        if _G.LexusConfig.ShowHeadHPBar and Valid(lp.HeadHPBar) and type(lp.HeadHPBar.CreateSceneMark) == "function" then lp.HeadHPBar:CreateSceneMark() end
        if _G.LexusConfig.EnableDamageAnalysis then lp.bEnableDamageAnalysis = true end
        if _G.LexusConfig.BehindAttackBonus then lp.BehindAttackEnabled = true end
    end)
end

-- ============================================================================
-- CONFIG
-- ============================================================================
local function GetConfigPaths(fn)
    local paths = {
        "//storage/emulated/0/Android/data/com.tencent.ig/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/"..fn,
        "//storage/emulated/0/Android/data/com.vng.pubgmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/"..fn,
        "//storage/emulated/0/Android/data/com.pubg.krmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/"..fn,
        "//storage/emulated/0/Android/data/com.rekoo.pubgm/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/"..fn,
        "//storage/emulated/0/Android/data/com.pubg.imobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/"..fn,
        "/Documents/ShadowTrackerExtra/Saved/Paks/"..fn,
        "ShadowTrackerExtra/Saved/Paks/"..fn, fn
    }
    return paths
end

local ConfigFileName = "chen_vip_v6.bin"
_G.LastConfigSaveStr = ""

local function XORStr(s, k)
    k = k or "CHEN2026"
    local out = {}
    for i = 1, #s do
        out[i] = string.char(bit.bxor(s:byte(i), k:byte(((i-1) % #k) + 1)))
    end
    return table.concat(out)
end

_G.SaveModSettings = function()
    pcall(function()
        local data = "return {\nLexusConfig = {\n"
        for k, v in pairs(_G.LexusConfig or {}) do
            data = data .. "  [\""..tostring(k).."\"] = "..tostring(v)..",\n"
        end
        data = data .. "},\nCustomTextData = {\n"
        if _G.LexusState and _G.LexusState.CustomTextData then
            for k, v in pairs(_G.LexusState.CustomTextData) do
                data = data .. "  [\""..tostring(k).."\"] = "..tostring(v)..",\n"
            end
        end
        data = data .. "}\n}"
        if data == _G.LastConfigSaveStr then return end
        _G.LastConfigSaveStr = data
        local enc = XORStr(data)
        for _, p in ipairs(GetConfigPaths(ConfigFileName)) do
            local f = io.open(p, "wb")
            if f then f:write(enc); f:close(); break end
        end
    end)
end

_G.LoadModSettings = function()
    pcall(function()
        local content = nil
        for _, p in ipairs(GetConfigPaths(ConfigFileName)) do
            local f = io.open(p, "rb")
            if f then content = f:read("*a"); f:close(); break end
        end
        if content then
            local dec = XORStr(content)
            local fn = load(dec)
            if fn then
                local sd = fn()
                if sd and type(sd) == "table" then
                    if sd.LexusConfig then for k, v in pairs(sd.LexusConfig) do _G.LexusConfig[k] = v end end
                    if sd.CustomTextData then
                        _G.LexusState.CustomTextData = _G.LexusState.CustomTextData or {}
                        for k, v in pairs(sd.CustomTextData) do _G.LexusState.CustomTextData[k] = v end
                    end
                end
            end
        end
        _G.SaveModSettings()
    end)
end

_G.ReadLiveConfig = function() if _G.SaveModSettings then _G.SaveModSettings() end end

local function AutoSaveLoop()
    pcall(function() if _G.SaveModSettings then _G.SaveModSettings() end end)
    pcall(function()
        local ok, t = pcall(require, "common.time_ticker")
        if ok and t and t.AddTimerOnce then t.AddTimerOnce(3.0, AutoSaveLoop) end
    end)
end
if not _G.ModConfigLoaded then
    _G.LoadModSettings()
    AutoSaveLoop()
    _G.ModConfigLoaded = true
end

-- ============================================================================
-- MENU
-- ============================================================================
local FakeTextMap = {
    [999000] = "VIP MOD MENU @FLUXMOD",
    [999001] = "CUSTOM ESP MENU",
    [999002] = "CUSTOM AIMBOT MENU",
    [999003] = "EXTRA FEATURES (PUBGM 4.6)",
    [999004] = "PREMIUM SKINS",
    [999005] = "BAN SECTION",
    [999006] = "LOST TOMB",
    [999007] = "TOP HUD",

    [999100] = "ESP SKELETON",
    [999101] = "ESP DISTANCE",
    [999102] = "ESP HEALTH BAR",
    [999103] = "ESP RADAR",
    [999104] = "ESP BOX (MARK)",
    [999105] = "ESP SKELETON ONLY",
    [999106] = "ESP REAL/BOT TAG",
    [999107] = "ESP GREEN ANTENNA",
    [999108] = "ESP OUTLINE (RED AURA)",
    [999109] = "OUTLINE THICKNESS",
    [999110] = "ESP BOX STYLE",
    [999111] = "ESP SKELETON STYLE",
    [999112] = "ESP NAME COLOR",
    [999113] = "ESP SHOW NAME",
    [999114] = "ESP SHOW WEAPON",
    [999115] = "ESP SHOW STATE",
    [999116] = "ESP SHOW KNOCKED",
    [999117] = "ESP SHOW BOT TAG",
    [999118] = "ESP DISTANCE UNIT",
    [999119] = "ESP MAX DISTANCE",
    [999120] = "ESP 2D BOX",
    [999121] = "ESP CORNER BOX",
    [999122] = "ESP SNAPLINE",
    [999123] = "ESP HP BAR VERT",
    [999124] = "ESP ARMOR BAR",
    [999125] = "ESP AIM ARROW",
    [999126] = "ESP RELOAD TAG",
    [999127] = "ESP VEHICLE",
    [999128] = "ESP AIRDROP",
    [999129] = "ESP LAST SEEN",
    [999130] = "ESP SELF PLATE",
    [999131] = "ENEMY COUNT HUD",

    [999200] = "LONG RANGE AIMBOT",
    [999201] = "AIMBOT SPEED",
    [999202] = "AIMBOT RECOIL ADS",
    [999203] = "CLOSE RANGE AIMBOT",
    [999204] = "AIMBOT CLOSE SPEED",
    [999205] = "MAGIC BULLET (DO NOT USE)",
    [999206] = "HEAD",
    [999207] = "BODY",
    [999208] = "LEGS",
    [999209] = "H/V RECOIL",
    [999210] = "H RECOIL SEC",
    [999211] = "V RECOIL SEC",
    [999212] = "KICK ADS FIX",
    [999213] = "NO SHAKE V2",
    [999214] = "SMALL CROSSHAIR",
    [999217] = "AUTO AIMBOT HEAD",
    [999218] = "FULL BULLET BURST",
    [999219] = "AIM TOUCH ENABLE",
    [999220] = "HIPFIRE ENABLE",
    [999221] = "SHOTGUN ENABLE",
    [999222] = "SCOPE ALL ENABLE",
    [999223] = "SNIPER ENABLE",
    [999224] = "HIPFIRE VIS CHECK",
    [999225] = "SCOPE VIS CHECK",
    [999226] = "SNIPER VIS CHECK",
    [999227] = "SG VIS CHECK",
    [999228] = "SG AUTO FIRE",
    [999229] = "HIPFIRE BONE",
    [999230] = "SCOPE BONE",
    [999231] = "SNIPER BONE",
    [999232] = "SG BONE",
    [999233] = "HIPFIRE DIST",
    [999234] = "SCOPE DIST",
    [999235] = "SNIPER DIST",
    [999236] = "SG DIST",
    [999237] = "HIPFIRE SPEED",
    [999238] = "SCOPE SPEED",
    [999239] = "SNIPER SPEED",
    [999240] = "SG SPEED",
    [999241] = "TRIGGERBOT",
    [999242] = "SHOW FOV CIRCLE",
    [999243] = "TARGET SWITCH DELAY MS",
    [999244] = "PRIORITY MODE (1=DIST,2=RANGE,3=HP,4=HPRATIO)",
    [999245] = "HIPFIRE FOV",
    [999246] = "SCOPE FOV",
    [999247] = "SNIPER FOV",
    [999248] = "SG FOV",

    [999300] = "CUSTOM IPAD VIEW",
    [999301] = "IPAD FOV",
    [999302] = "165 REAL FPS",
    [999303] = "WALLHACK REAL",
    [999304] = "WHITE BODY",
    [999305] = "BLACK SKY",
    [999306] = "REMOVE FOG",
    [999307] = "REMOVE GRASS",
    [999308] = "WALL CLIMB",
    [999309] = "FAST CAR SPEED",
    [999310] = "SKY FLY JUMP",
    [999311] = "JUMP HIGH (SINGLE)",
    [999312] = "JUMP BOOST (X)",
    [999313] = "SAFE SPEED 1.15x",
    [999314] = "LOW GRAVITY",
    [999315] = "REMOVE RAIN",
    [999316] = "BRIGHT NIGHT",
    [999317] = "HIT MARKER",
    [999318] = "DAMAGE NUMBERS",
    [999319] = "KILL FEED",
    [999320] = "FPS/PING HUD",
    [999321] = "DAMAGE LOG",

    [999400] = "VIP MOD SKINS",
    [999401] = "ALL SUITS",
    [999402] = "ALL BAG SKINS",
    [999403] = "ALL HELMET SKINS",
    [999404] = "M416",
    [999405] = "AKM",
    [999406] = "SCAR-L",
    [999407] = "M762",
    [999408] = "AUG",
    [999409] = "UMP45",
    [999410] = "UZI",
    [999411] = "GROZA",
    [999412] = "S12K",
    [999413] = "DBS",
    [999414] = "DACIA",
    [999415] = "UAZ",
    [999416] = "COUPE RB",
    [999417] = "BUGGY",
    [999418] = "MIRADO",
    [999419] = "LIVE STYLE CHANGE",

    [999500] = "BAN SECTION",
    [999501] = "FLY MODE",
    [999502] = "SPIN MODE",
    [999503] = "NO FALL DAMAGE",
    [999504] = "REMOVE FOG GLOBAL",
    [999505] = "REMOVE GRASS GLOBAL",
    [999506] = "BLOCK ALL ANTICHEAT",
    [999507] = "PANIC KEY (REVERT)",
    [999508] = "BYPASS LOOP ON",

    [999600] = "LOST TOMB FEATURES",
    [999601] = "DAMAGE ANALYSIS",
    [999602] = "IGNORE FALLING DAMAGE",
    [999603] = "DISABLE AI IGNORE TARGET",
    [999604] = "MELEE DAMAGE REPORT",
    [999605] = "SHOW KNOWLEDGE UI",
    [999606] = "QTE SYSTEM",
    [999607] = "POISON SYSTEM",
    [999608] = "AUTO HIDE WEAPON",
    [999609] = "OVERRIDE AVATAR",
    [999610] = "SKILL FLOW REPORT",
    [999611] = "SUPPLY BOX EVOLUTION",
    [999612] = "MAX WALK SPEED CURVE",
    [999613] = "SHOW HEAD HP BAR",
    [999614] = "CUSTOM GENDER",
    [999615] = "LOADING AVATAR",
    [999616] = "SMOKE PARTICLE",
    [999617] = "DAMAGE SHAKE",
    [999618] = "STEAL LIFE EFFECT",
    [999619] = "TOMB BOX FILTER",
    [999620] = "GAME START SPEED UP",
    [999621] = "EXTRA ENERGY BONUS",
    [999622] = "BEHIND ATTACK BONUS",

    [999700] = "TOP HUD",
    [999701] = "SHOW PROFILE NAME",
    [999702] = "SHOW UID",
    [999703] = "SHOW STATS",
    [999704] = "SHOW OUTFIT",
    [999705] = "ENEMY PLATE",
    [999706] = "BOT PLATE",
}

local function HookLocUtil()
    local LocUtil = _G.LocUtil
    if not LocUtil and package.loaded["client.common.LocUtil"] then LocUtil = require("client.common.LocUtil") end
    if LocUtil and not LocUtil._IsModMenuHooked then
        local old = LocUtil.GetLocalizeResStr
        LocUtil.GetLocalizeResStr = function(id)
            if type(id) == "string" and not tonumber(id) then return id end
            if FakeTextMap[id] then return FakeTextMap[id] end
            return old(id)
        end
        LocUtil._IsModMenuHooked = true
    end
end

_G.InitModMenuTab = function()
    HookLocUtil()
    local SPD = require("client.logic.NewSetting.SettingPageDefine")
    local SC = require("client.logic.NewSetting.SettingCatalog")
    local AM = require("client.slua.umg.NewSetting.Item.AliasMap")

    -- ESP
    local StackESP = {
        { UI = AM.Title, Text = 999001 },
        { Key="ModMenu_ESP1", UI=AM.Switcher, Text=999100, GetFunc=function() return _G.LexusConfig.EspVip end, SetFunc=function(_, v) _G.LexusConfig.EspVip = v; return true end },
        { Key="ModMenu_ESP2", UI=AM.Switcher, Text=999101, GetFunc=function() return _G.LexusConfig.EspDistance end, SetFunc=function(_, v) _G.LexusConfig.EspDistance = v; return true end },
        { Key="ModMenu_ESP3", UI=AM.Switcher, Text=999102, GetFunc=function() return _G.LexusConfig.EspVipPro end, SetFunc=function(_, v) _G.LexusConfig.EspVipPro = v; return true end },
        { Key="ModMenu_ESP4", UI=AM.Switcher, Text=999103, GetFunc=function() return _G.LexusConfig.EspRadar end, SetFunc=function(_, v) _G.LexusConfig.EspRadar = v; return true end },
        { Key="ModMenu_ESP5", UI=AM.Switcher, Text=999104, GetFunc=function() return _G.LexusConfig.EspLoai5 end, SetFunc=function(_, v) _G.LexusConfig.EspLoai5 = v; return true end },
        { Key="ModMenu_ESP6", UI=AM.Switcher, Text=999105, GetFunc=function() return _G.LexusConfig.EspLoai6 end, SetFunc=function(_, v) _G.LexusConfig.EspLoai6 = v; return true end },
        { Key="ModMenu_ESP7", UI=AM.Switcher, Text=999106, GetFunc=function() return _G.LexusConfig.EspLoai7 end, SetFunc=function(_, v) _G.LexusConfig.EspLoai7 = v; return true end },
        { Key="ModMenu_ESPAntenna", UI=AM.Switcher, Text=999107, GetFunc=function() return _G.LexusConfig.EspAntenna end, SetFunc=function(_, v) _G.LexusConfig.EspAntenna = v; return true end },
        { Key="ModMenu_ESPOutline_Ex", UI=AM.TitleSwitcher, Text=999108, ExpandIndex=0, GetFunc=function() return _G.LexusConfig.EspOutline end, SetFunc=function(_, v) _G.LexusConfig.EspOutline = v; return true end },
        { Key="ModMenu_ESPOutline_Thickness", UI=AM.Slider, Text=999109, ExpandHandle="ModMenu_ESPOutline_Ex", MinValue=1, MaxValue=20, min=1, max=20, GetFunc=function() return _G.LexusConfig.OutlineThickness or 10 end, SetFunc=function(_, v) _G.LexusConfig.OutlineThickness = v; return true end },
        { Key="ModMenu_ESPBoxStyle", UI=AM.Slider, Text=999110, MinValue=1, MaxValue=3, min=1, max=3, GetFunc=function() return _G.LexusConfig.EspBoxStyle or 1 end, SetFunc=function(_, v) _G.LexusConfig.EspBoxStyle = v; return true end },
        { Key="ModMenu_ESPSkelStyle", UI=AM.Slider, Text=999111, MinValue=1, MaxValue=3, min=1, max=3, GetFunc=function() return _G.LexusConfig.EspSkeletonStyle or 1 end, SetFunc=function(_, v) _G.LexusConfig.EspSkeletonStyle = v; return true end },
        { Key="ModMenu_ESPNameColor", UI=AM.Slider, Text=999112, MinValue=1, MaxValue=3, min=1, max=3, GetFunc=function() return _G.LexusConfig.EspNameColor or 1 end, SetFunc=function(_, v) _G.LexusConfig.EspNameColor = v; return true end },
        { Key="ModMenu_ESPShowName", UI=AM.Switcher, Text=999113, GetFunc=function() return _G.LexusConfig.EspShowName end, SetFunc=function(_, v) _G.LexusConfig.EspShowName = v; return true end },
        { Key="ModMenu_ESPShowWeapon", UI=AM.Switcher, Text=999114, GetFunc=function() return _G.LexusConfig.EspShowWeapon end, SetFunc=function(_, v) _G.LexusConfig.EspShowWeapon = v; return true end },
        { Key="ModMenu_ESPShowState", UI=AM.Switcher, Text=999115, GetFunc=function() return _G.LexusConfig.EspShowState end, SetFunc=function(_, v) _G.LexusConfig.EspShowState = v; return true end },
        { Key="ModMenu_ESPShowKnock", UI=AM.Switcher, Text=999116, GetFunc=function() return _G.LexusConfig.EspShowKnocked end, SetFunc=function(_, v) _G.LexusConfig.EspShowKnocked = v; return true end },
        { Key="ModMenu_ESPShowBot", UI=AM.Switcher, Text=999117, GetFunc=function() return _G.LexusConfig.EspShowBotTag end, SetFunc=function(_, v) _G.LexusConfig.EspShowBotTag = v; return true end },
        { Key="ModMenu_ESPDistUnit", UI=AM.Slider, Text=999118, MinValue=1, MaxValue=2, min=1, max=2, GetFunc=function() return _G.LexusConfig.EspDistanceUnit or 1 end, SetFunc=function(_, v) _G.LexusConfig.EspDistanceUnit = v; return true end },
        { Key="ModMenu_ESPMaxDist", UI=AM.Slider, Text=999119, MinValue=50, MaxValue=800, min=50, max=800, GetFunc=function() return _G.LexusConfig.EspMaxDistance or 400 end, SetFunc=function(_, v) _G.LexusConfig.EspMaxDistance = v; return true end },
        { Key="ModMenu_ESPBox2D", UI=AM.Switcher, Text=999120, GetFunc=function() return _G.LexusConfig.EspBox2D end, SetFunc=function(_, v) _G.LexusConfig.EspBox2D = v; return true end },
        { Key="ModMenu_ESPBoxCorner", UI=AM.Switcher, Text=999121, GetFunc=function() return _G.LexusConfig.EspBoxCorner end, SetFunc=function(_, v) _G.LexusConfig.EspBoxCorner = v; return true end },
        { Key="ModMenu_ESPSnapline", UI=AM.Switcher, Text=999122, GetFunc=function() return _G.LexusConfig.EspSnapline end, SetFunc=function(_, v) _G.LexusConfig.EspSnapline = v; return true end },
        { Key="ModMenu_ESPHpBarVert", UI=AM.Switcher, Text=999123, GetFunc=function() return _G.LexusConfig.EspHpBarVert end, SetFunc=function(_, v) _G.LexusConfig.EspHpBarVert = v; return true end },
        { Key="ModMenu_ESPArmorBar", UI=AM.Switcher, Text=999124, GetFunc=function() return _G.LexusConfig.EspArmorBar end, SetFunc=function(_, v) _G.LexusConfig.EspArmorBar = v; return true end },
        { Key="ModMenu_ESPAimArrow", UI=AM.Switcher, Text=999125, GetFunc=function() return _G.LexusConfig.EspAimArrow end, SetFunc=function(_, v) _G.LexusConfig.EspAimArrow = v; return true end },
        { Key="ModMenu_ESPReloadTag", UI=AM.Switcher, Text=999126, GetFunc=function() return _G.LexusConfig.EspReloadTag end, SetFunc=function(_, v) _G.LexusConfig.EspReloadTag = v; return true end },
        { Key="ModMenu_ESPVehicle", UI=AM.Switcher, Text=999127, GetFunc=function() return _G.LexusConfig.EspVehicleEsp end, SetFunc=function(_, v) _G.LexusConfig.EspVehicleEsp = v; return true end },
        { Key="ModMenu_ESPAirdrop", UI=AM.Switcher, Text=999128, GetFunc=function() return _G.LexusConfig.EspAirdropEsp end, SetFunc=function(_, v) _G.LexusConfig.EspAirdropEsp = v; return true end },
        { Key="ModMenu_ESPLastSeen", UI=AM.Switcher, Text=999129, GetFunc=function() return _G.LexusConfig.EspLastSeen end, SetFunc=function(_, v) _G.LexusConfig.EspLastSeen = v; return true end },
        { Key="ModMenu_ESPSelfPlate", UI=AM.Switcher, Text=999130, GetFunc=function() return _G.LexusConfig.EspSelfPlate end, SetFunc=function(_, v) _G.LexusConfig.EspSelfPlate = v; return true end },
        { Key="ModMenu_EnemyCountHUD", UI=AM.Switcher, Text=999131, GetFunc=function() return _G.LexusConfig.EnemyCountHUD end, SetFunc=function(_, v) _G.LexusConfig.EnemyCountHUD = v; return true end },
    }

    -- AIMBOT
    local StackAimbot = {
        { UI = AM.Title, Text = 999002 },
        { Key="ModMenu_Aimbot_Ex", UI=AM.TitleSwitcher, Text=999200, ExpandIndex=0, GetFunc=function() return _G.LexusConfig.CustomAimbot end, SetFunc=function(_, v) _G.LexusConfig.CustomAimbot = v; return true end },
        { Key="ModMenu_Aimbot_Speed", UI=AM.Slider, Text=999201, ExpandHandle="ModMenu_Aimbot_Ex", MinValue=1, MaxValue=100, min=1, max=100, GetFunc=function() return _G.LexusState.CustomTextData.OuterSpeed or 10 end, SetFunc=function(_, v) _G.LexusState.CustomTextData.OuterSpeed = v; return true end },
        { Key="ModMenu_Aimbot_Recoil", UI=AM.Slider, Text=999202, ExpandHandle="ModMenu_Aimbot_Ex", MinValue=1, MaxValue=50, min=1, max=50, GetFunc=function() return _G.LexusState.CustomTextData.OuterRecoil or 0.1 end, SetFunc=function(_, v) _G.LexusState.CustomTextData.OuterRecoil = v; return true end },
        { Key="ModMenu_AimbotClose_Ex", UI=AM.TitleSwitcher, Text=999203, ExpandIndex=0, GetFunc=function() return _G.LexusConfig.CustomAimbotClose end, SetFunc=function(_, v) _G.LexusConfig.CustomAimbotClose = v; return true end },
        { Key="ModMenu_AimbotClose_Speed", UI=AM.Slider, Text=999204, ExpandHandle="ModMenu_AimbotClose_Ex", MinValue=1, MaxValue=100, min=1, max=100, GetFunc=function() return _G.LexusState.CustomTextData.InnerSpeed or 10 end, SetFunc=function(_, v) _G.LexusState.CustomTextData.InnerSpeed = v; return true end },
        { Key="ModMenu_Magic_Ex", UI=AM.TitleSwitcher, Text=999205, ExpandIndex=0, GetFunc=function() return _G.LexusConfig.CustomMagicBullet end, SetFunc=function(_, v) _G.LexusConfig.CustomMagicBullet = v; return true end },
        { Key="ModMenu_Magic_Head", UI=AM.Slider, Text=999206, ExpandHandle="ModMenu_Magic_Ex", MinValue=0, MaxValue=100, min=0, max=100, GetFunc=function() return math.floor(((_G.LexusState.CustomTextData.MagicHead or 1.0)/5.0)*100+0.5) end, SetFunc=function(_, v) _G.LexusState.CustomTextData.MagicHead = (v/100.0)*5.0; return true end },
        { Key="ModMenu_Magic_Body", UI=AM.Slider, Text=999207, ExpandHandle="ModMenu_Magic_Ex", MinValue=0, MaxValue=100, min=0, max=100, GetFunc=function() return math.floor(((_G.LexusState.CustomTextData.MagicBody or 1.0)/5.0)*100+0.5) end, SetFunc=function(_, v) _G.LexusState.CustomTextData.MagicBody = (v/100.0)*5.0; return true end },
        { Key="ModMenu_Magic_Legs", UI=AM.Slider, Text=999208, ExpandHandle="ModMenu_Magic_Ex", MinValue=0, MaxValue=100, min=0, max=100, GetFunc=function() return math.floor(((_G.LexusState.CustomTextData.MagicLegs or 1.0)/5.0)*100+0.5) end, SetFunc=function(_, v) _G.LexusState.CustomTextData.MagicLegs = (v/100.0)*5.0; return true end },
        { Key="ModMenu_HRecoil_Ex", UI=AM.TitleSwitcher, Text=999209, ExpandIndex=0, GetFunc=function() return _G.LexusConfig.CustomHRecoil end, SetFunc=function(_, v) _G.LexusConfig.CustomHRecoil = v; return true end },
        { Key="ModMenu_HRecoil_Val", UI=AM.Slider, Text=999210, ExpandHandle="ModMenu_HRecoil_Ex", MinValue=0, MaxValue=100, min=0, max=100, GetFunc=function() return math.floor((((_G.LexusState.CustomTextData.HRecoil or 0.3)-0.3)/4.7)*100+0.5) end, SetFunc=function(_, v) _G.LexusState.CustomTextData.HRecoil = 0.3+(v/100.0)*4.7; return true end },
        { Key="ModMenu_VRecoil_Ex", UI=AM.TitleSwitcher, Text=999209, ExpandIndex=0, GetFunc=function() return _G.LexusConfig.CustomVRecoil end, SetFunc=function(_, v) _G.LexusConfig.CustomVRecoil = v; return true end },
        { Key="ModMenu_VRecoil_Val", UI=AM.Slider, Text=999211, ExpandHandle="ModMenu_VRecoil_Ex", MinValue=0, MaxValue=100, min=0, max=100, GetFunc=function() return math.floor((((_G.LexusState.CustomTextData.VRecoil or 0.3)-0.3)/4.7)*100+0.5) end, SetFunc=function(_, v) _G.LexusState.CustomTextData.VRecoil = 0.3+(v/100.0)*4.7; return true end },
        { Key="ModMenu_LessShake", UI=AM.Switcher, Text=999212, GetFunc=function() return _G.LexusConfig.LessShake end, SetFunc=function(_, v) _G.LexusConfig.LessShake = v; return true end },
        { Key="ModMenu_Accuracy", UI=AM.Switcher, Text=999213, GetFunc=function() return _G.LexusConfig.Accuracy end, SetFunc=function(_, v) _G.LexusConfig.Accuracy = v; return true end },
        { Key="ModMenu_Crosshair", UI=AM.Switcher, Text=999214, GetFunc=function() return _G.LexusConfig.Crosshair end, SetFunc=function(_, v) _G.LexusConfig.Crosshair = v; return true end },
        { Key="ModMenu_AutoHead", UI=AM.Switcher, Text=999217, GetFunc=function() return _G.LexusConfig.AutoHead end, SetFunc=function(_, v) _G.LexusConfig.AutoHead = v; return true end },
        { Key="ModMenu_GodMode", UI=AM.Switcher, Text=999218, GetFunc=function() return _G.LexusConfig.GodMode end, SetFunc=function(_, v) _G.LexusConfig.GodMode = v; return true end },
        { Key="ModMenu_AT_Ex", UI=AM.TitleSwitcher, Text=999219, ExpandIndex=0, GetFunc=function() return _G.LexusConfig.AimTouchEnable end, SetFunc=function(_, v) _G.LexusConfig.AimTouchEnable = v; return true end },
        { Key="ModMenu_AT_Hip_Ex", UI=AM.TitleSwitcher, Text=999220, ExpandHandle="ModMenu_AT_Ex", ExpandIndex=0, GetFunc=function() return _G.LexusConfig.AimTouchHipfire end, SetFunc=function(_, v) _G.LexusConfig.AimTouchHipfire = v; return true end },
        { Key="ModMenu_AT_SG_Ex", UI=AM.TitleSwitcher, Text=999221, ExpandHandle="ModMenu_AT_Ex", ExpandIndex=0, GetFunc=function() return _G.LexusConfig.AimTouchSG end, SetFunc=function(_, v) _G.LexusConfig.AimTouchSG = v; return true end },
        { Key="ModMenu_AT_ScopeAll_Ex", UI=AM.TitleSwitcher, Text=999222, ExpandHandle="ModMenu_AT_Ex", ExpandIndex=0, GetFunc=function() return _G.LexusConfig.AimTouchScopeAll end, SetFunc=function(_, v) _G.LexusConfig.AimTouchScopeAll = v; return true end },
        { Key="ModMenu_AT_Sniper_Ex", UI=AM.TitleSwitcher, Text=999223, ExpandHandle="ModMenu_AT_Ex", ExpandIndex=0, GetFunc=function() return _G.LexusConfig.AimTouchScopeSniper end, SetFunc=function(_, v) _G.LexusConfig.AimTouchScopeSniper = v; return true end },
        { Key="AT_Hip_VC", UI=AM.Switcher, Text=999224, ExpandHandle="ModMenu_AT_Hip_Ex", GetFunc=function() return _G.LexusConfig.AimTouchHipVisCheck end, SetFunc=function(_, v) _G.LexusConfig.AimTouchHipVisCheck = v; return true end },
        { Key="AT_Scope_VC", UI=AM.Switcher, Text=999225, ExpandHandle="ModMenu_AT_ScopeAll_Ex", GetFunc=function() return _G.LexusConfig.AimTouchScopeVisCheck end, SetFunc=function(_, v) _G.LexusConfig.AimTouchScopeVisCheck = v; return true end },
        { Key="AT_Sniper_VC", UI=AM.Switcher, Text=999226, ExpandHandle="ModMenu_AT_Sniper_Ex", GetFunc=function() return _G.LexusConfig.AimTouchSniperVisCheck end, SetFunc=function(_, v) _G.LexusConfig.AimTouchSniperVisCheck = v; return true end },
        { Key="AT_SG_VC", UI=AM.Switcher, Text=999227, ExpandHandle="ModMenu_AT_SG_Ex", GetFunc=function() return _G.LexusConfig.AimTouchSGVisCheck end, SetFunc=function(_, v) _G.LexusConfig.AimTouchSGVisCheck = v; return true end },
        { Key="AT_SG_AF", UI=AM.Switcher, Text=999228, ExpandHandle="ModMenu_AT_SG_Ex", GetFunc=function() return _G.LexusConfig.AimTouchSGAutoFire end, SetFunc=function(_, v) _G.LexusConfig.AimTouchSGAutoFire = v; return true end },
        { Key="AT_Hip_Bone", UI=AM.Slider, Text=999229, ExpandHandle="ModMenu_AT_Hip_Ex", MinValue=1, MaxValue=4, min=1, max=4, GetFunc=function() return _G.LexusState.CustomTextData.AimTouchHipBone or 1 end, SetFunc=function(_, v) _G.LexusState.CustomTextData.AimTouchHipBone = v; return true end },
        { Key="AT_Scope_Bone", UI=AM.Slider, Text=999230, ExpandHandle="ModMenu_AT_ScopeAll_Ex", MinValue=1, MaxValue=4, min=1, max=4, GetFunc=function() return _G.LexusState.CustomTextData.AimTouchScopeBone or 2 end, SetFunc=function(_, v) _G.LexusState.CustomTextData.AimTouchScopeBone = v; return true end },
        { Key="AT_Sniper_Bone", UI=AM.Slider, Text=999231, ExpandHandle="ModMenu_AT_Sniper_Ex", MinValue=1, MaxValue=4, min=1, max=4, GetFunc=function() return _G.LexusState.CustomTextData.AimTouchSniperBone or 1 end, SetFunc=function(_, v) _G.LexusState.CustomTextData.AimTouchSniperBone = v; return true end },
        { Key="AT_SG_Bone", UI=AM.Slider, Text=999232, ExpandHandle="ModMenu_AT_SG_Ex", MinValue=1, MaxValue=4, min=1, max=4, GetFunc=function() return _G.LexusState.CustomTextData.AimTouchSGBone or 2 end, SetFunc=function(_, v) _G.LexusState.CustomTextData.AimTouchSGBone = v; return true end },
        { Key="AT_Hip_Dist", UI=AM.Slider, Text=999233, ExpandHandle="ModMenu_AT_Hip_Ex", MinValue=10, MaxValue=500, min=10, max=500, GetFunc=function() return _G.LexusState.CustomTextData.AimTouchHipDist or 250 end, SetFunc=function(_, v) _G.LexusState.CustomTextData.AimTouchHipDist = v; return true end },
        { Key="AT_Scope_Dist", UI=AM.Slider, Text=999234, ExpandHandle="ModMenu_AT_ScopeAll_Ex", MinValue=10, MaxValue=600, min=10, max=600, GetFunc=function() return _G.LexusState.CustomTextData.AimTouchScopeDist or 300 end, SetFunc=function(_, v) _G.LexusState.CustomTextData.AimTouchScopeDist = v; return true end },
        { Key="AT_Sniper_Dist", UI=AM.Slider, Text=999235, ExpandHandle="ModMenu_AT_Sniper_Ex", MinValue=10, MaxValue=800, min=10, max=800, GetFunc=function() return _G.LexusState.CustomTextData.AimTouchSniperDist or 400 end, SetFunc=function(_, v) _G.LexusState.CustomTextData.AimTouchSniperDist = v; return true end },
        { Key="AT_SG_Dist", UI=AM.Slider, Text=999236, ExpandHandle="ModMenu_AT_SG_Ex", MinValue=5, MaxValue=100, min=5, max=100, GetFunc=function() return _G.LexusState.CustomTextData.AimTouchSGDist or 30 end, SetFunc=function(_, v) _G.LexusState.CustomTextData.AimTouchSGDist = v; return true end },
        { Key="AT_Hip_Speed", UI=AM.Slider, Text=999237, ExpandHandle="ModMenu_AT_Hip_Ex", MinValue=10, MaxValue=100, min=10, max=100, GetFunc=function() return _G.LexusState.CustomTextData.AimTouchHipSpeed or 50 end, SetFunc=function(_, v) _G.LexusState.CustomTextData.AimTouchHipSpeed = v; return true end },
        { Key="AT_Scope_Speed", UI=AM.Slider, Text=999238, ExpandHandle="ModMenu_AT_ScopeAll_Ex", MinValue=10, MaxValue=100, min=10, max=100, GetFunc=function() return _G.LexusState.CustomTextData.AimTouchScopeSpeed or 40 end, SetFunc=function(_, v) _G.LexusState.CustomTextData.AimTouchScopeSpeed = v; return true end },
        { Key="AT_Sniper_Speed", UI=AM.Slider, Text=999239, ExpandHandle="ModMenu_AT_Sniper_Ex", MinValue=10, MaxValue=100, min=10, max=100, GetFunc=function() return _G.LexusState.CustomTextData.AimTouchSniperSpeed or 30 end, SetFunc=function(_, v) _G.LexusState.CustomTextData.AimTouchSniperSpeed = v; return true end },
        { Key="AT_SG_Speed", UI=AM.Slider, Text=999240, ExpandHandle="ModMenu_AT_SG_Ex", MinValue=10, MaxValue=100, min=10, max=100, GetFunc=function() return _G.LexusState.CustomTextData.AimTouchSGSpeed or 80 end, SetFunc=function(_, v) _G.LexusState.CustomTextData.AimTouchSGSpeed = v; return true end },
        { Key="ModMenu_Triggerbot", UI=AM.Switcher, Text=999241, GetFunc=function() return _G.LexusConfig.AimTriggerbot end, SetFunc=function(_, v) _G.LexusConfig.AimTriggerbot = v; return true end },
        { Key="ModMenu_FOVCircle", UI=AM.Switcher, Text=999242, GetFunc=function() return _G.LexusConfig.AimShowFOVCircle end, SetFunc=function(_, v) _G.LexusConfig.AimShowFOVCircle = v; return true end },
        { Key="ModMenu_SwitchDelay", UI=AM.Slider, Text=999243, MinValue=0, MaxValue=500, min=0, max=500, GetFunc=function() return _G.LexusConfig.AimSwitchDelay or 0 end, SetFunc=function(_, v) _G.LexusConfig.AimSwitchDelay = v; return true end },
        { Key="ModMenu_PrioMode", UI=AM.Slider, Text=999244, MinValue=1, MaxValue=4, min=1, max=4, GetFunc=function() return _G.LexusConfig.AimPriorityMode or 1 end, SetFunc=function(_, v) _G.LexusConfig.AimPriorityMode = v; return true end },
    }

    -- EXTRA
    local StackCombat = {
        { UI = AM.Title, Text = 999003 },
        { Key="ModMenu_Ipad_Ex", UI=AM.TitleSwitcher, Text=999300, ExpandIndex=0, GetFunc=function() return _G.LexusConfig.IpadView end, SetFunc=function(_, v) _G.LexusConfig.IpadView = v; return true end },
        { Key="ModMenu_Ipad_FOV", UI=AM.Slider, Text=999301, ExpandHandle="ModMenu_Ipad_Ex", MinValue=1, MaxValue=100, min=1, max=100, GetFunc=function() return (_G.LexusState.CustomTextData.IpadViewFOV or 120) - 90 end, SetFunc=function(_, v) _G.LexusState.CustomTextData.IpadViewFOV = 90 + v; return true end },
        { Key="ModMenu_165FPS", UI=AM.Switcher, Text=999302, GetFunc=function() return _G.LexusConfig.UnlockFPS end, SetFunc=function(_, v) _G.LexusConfig.UnlockFPS = v; return true end },
        { Key="ModMenu_WallColor", UI=AM.Switcher, Text=999303, GetFunc=function() return _G.LexusConfig.WallXuyenTuong end, SetFunc=function(_, v) _G.LexusConfig.WallXuyenTuong = v; _G.LexusConfig.ColorBodyV2 = v; return true end },
        { Key="ModMenu_WhiteBody", UI=AM.Switcher, Text=999304, GetFunc=function() return _G.LexusConfig.WhiteBody end, SetFunc=function(_, v) _G.LexusConfig.WhiteBody = v; return true end },
        { Key="ModMenu_BlackSky", UI=AM.Switcher, Text=999305, GetFunc=function() return _G.LexusConfig.BlackSky end, SetFunc=function(_, v) _G.LexusConfig.BlackSky = v; return true end },
        { Key="ModMenu_RemoveFog", UI=AM.Switcher, Text=999306, GetFunc=function() return _G.LexusConfig.RemoveFog end, SetFunc=function(_, v) _G.LexusConfig.RemoveFog = v; return true end },
        { Key="ModMenu_RemoveGrass", UI=AM.Switcher, Text=999307, GetFunc=function() return _G.LexusConfig.RemoveGrass end, SetFunc=function(_, v) _G.LexusConfig.RemoveGrass = v; return true end },
        { Key="ModMenu_WallClimb", UI=AM.Switcher, Text=999308, GetFunc=function() return _G.LexusConfig.WallClimb end, SetFunc=function(_, v) _G.LexusConfig.WallClimb = v; return true end },
        { Key="ModMenu_FastCar", UI=AM.Switcher, Text=999309, GetFunc=function() return _G.LexusConfig.FastCar end, SetFunc=function(_, v) _G.LexusConfig.FastCar = v; return true end },
        { Key="ModMenu_SkyFlyJump", UI=AM.Switcher, Text=999310, GetFunc=function() return _G.LexusConfig.SkyFlyJump end, SetFunc=function(_, v) _G.LexusConfig.SkyFlyJump = v; return true end },
        { Key="ModMenu_JumpHigh", UI=AM.Switcher, Text=999311, GetFunc=function() return _G.LexusConfig.JumpHighSingle end, SetFunc=function(_, v) _G.LexusConfig.JumpHighSingle = v; return true end },
        { Key="ModMenu_SafeSpeed", UI=AM.Switcher, Text=999313, GetFunc=function() return _G.LexusConfig.SafeSpeed end, SetFunc=function(_, v) _G.LexusConfig.SafeSpeed = v; return true end },
        { Key="ModMenu_LowGravity", UI=AM.Switcher, Text=999314, GetFunc=function() return _G.LexusConfig.LowGravity end, SetFunc=function(_, v) _G.LexusConfig.LowGravity = v; return true end },
        { Key="ModMenu_RemoveRain", UI=AM.Switcher, Text=999315, GetFunc=function() return _G.LexusConfig.RemoveRain end, SetFunc=function(_, v) _G.LexusConfig.RemoveRain = v; return true end },
        { Key="ModMenu_BrightNight", UI=AM.Switcher, Text=999316, GetFunc=function() return _G.LexusConfig.BrightNight end, SetFunc=function(_, v) _G.LexusConfig.BrightNight = v; return true end },
        { Key="ModMenu_HitMarker", UI=AM.Switcher, Text=999317, GetFunc=function() return _G.LexusConfig.HitMarker end, SetFunc=function(_, v) _G.LexusConfig.HitMarker = v; return true end },
        { Key="ModMenu_DamageNum", UI=AM.Switcher, Text=999318, GetFunc=function() return _G.LexusConfig.DamageNumbers end, SetFunc=function(_, v) _G.LexusConfig.DamageNumbers = v; return true end },
        { Key="ModMenu_KillFeed", UI=AM.Switcher, Text=999319, GetFunc=function() return _G.LexusConfig.KillFeed end, SetFunc=function(_, v) _G.LexusConfig.KillFeed = v; return true end },
        { Key="ModMenu_FPSPing", UI=AM.Switcher, Text=999320, GetFunc=function() return _G.LexusConfig.FPSPingHUD end, SetFunc=function(_, v) _G.LexusConfig.FPSPingHUD = v; return true end },
        { Key="ModMenu_DamageLog", UI=AM.Switcher, Text=999321, GetFunc=function() return _G.LexusConfig.DamageLog end, SetFunc=function(_, v) _G.LexusConfig.DamageLog = v; return true end },
    }

    -- SKIN
    local StackSkin = {
        { UI = AM.Title, Text = 999004 },
        { Key="ModMenu_ModSkin", UI=AM.TitleSwitcher, Text=999400, ExpandIndex=0, GetFunc=function() return _G.LexusConfig.ModSkin end, SetFunc=function(_, v) _G.LexusConfig.ModSkin = v; return true end },
        { Key="ModMenu_Skin_Suit", UI=AM.Slider, Text=999401, ExpandHandle="ModMenu_ModSkin", MinValue=1, MaxValue=85, min=1, max=85, GetFunc=function() return _G.LexusState.CustomTextData.SkinSuit or 1 end, SetFunc=function(_, v) _G.LexusState.CustomTextData.SkinSuit = v; if _G.OutfitSkins and _G.OutfitSkins.Suit[v] then _G.OutfitMap.Suit = _G.OutfitSkins.Suit[v] end; return true end },
        { Key="ModMenu_Skin_Bag", UI=AM.Slider, Text=999402, ExpandHandle="ModMenu_ModSkin", MinValue=1, MaxValue=16, min=1, max=16, GetFunc=function() return _G.LexusState.CustomTextData.SkinBag or 1 end, SetFunc=function(_, v) _G.LexusState.CustomTextData.SkinBag = v; if _G.OutfitSkins and _G.OutfitSkins.Bag[v] then _G.OutfitMap.Bag = _G.OutfitSkins.Bag[v] end; return true end },
        { Key="ModMenu_Skin_Helmet", UI=AM.Slider, Text=999403, ExpandHandle="ModMenu_ModSkin", MinValue=1, MaxValue=11, min=1, max=11, GetFunc=function() return _G.LexusState.CustomTextData.SkinHelmet or 1 end, SetFunc=function(_, v) _G.LexusState.CustomTextData.SkinHelmet = v; if _G.OutfitSkins and _G.OutfitSkins.Helmet[v] then _G.OutfitMap.Helmet = _G.OutfitSkins.Helmet[v] end; return true end },
        { Key="ModMenu_Skin_M416", UI=AM.Slider, Text=999404, ExpandHandle="ModMenu_ModSkin", MinValue=1, MaxValue=9, min=1, max=9, GetFunc=function() return _G.LexusState.CustomTextData.SkinM416 or 1 end, SetFunc=function(_, v) _G.LexusState.CustomTextData.SkinM416 = v; if _G.skinIdMappings[101004] and _G.skinIdMappings[101004][v] then _G.WeaponSkinMap[101004] = _G.skinIdMappings[101004][v] end; return true end },
        { Key="ModMenu_Skin_AKM", UI=AM.Slider, Text=999405, ExpandHandle="ModMenu_ModSkin", MinValue=1, MaxValue=8, min=1, max=8, GetFunc=function() return _G.LexusState.CustomTextData.SkinAKM or 1 end, SetFunc=function(_, v) _G.LexusState.CustomTextData.SkinAKM = v; if _G.skinIdMappings[101001] and _G.skinIdMappings[101001][v] then _G.WeaponSkinMap[101001] = _G.skinIdMappings[101001][v] end; return true end },
        { Key="ModMenu_Skin_SCAR", UI=AM.Slider, Text=999406, ExpandHandle="ModMenu_ModSkin", MinValue=1, MaxValue=8, min=1, max=8, GetFunc=function() return _G.LexusState.CustomTextData.SkinSCAR or 1 end, SetFunc=function(_, v) _G.LexusState.CustomTextData.SkinSCAR = v; if _G.skinIdMappings[101003] and _G.skinIdMappings[101003][v] then _G.WeaponSkinMap[101003] = _G.skinIdMappings[101003][v] end; return true end },
        { Key="ModMenu_Skin_M762", UI=AM.Slider, Text=999407, ExpandHandle="ModMenu_ModSkin", MinValue=1, MaxValue=8, min=1, max=8, GetFunc=function() return _G.LexusState.CustomTextData.SkinM762 or 1 end, SetFunc=function(_, v) _G.LexusState.CustomTextData.SkinM762 = v; if _G.skinIdMappings[101008] and _G.skinIdMappings[101008][v] then _G.WeaponSkinMap[101008] = _G.skinIdMappings[101008][v] end; return true end },
        { Key="ModMenu_Skin_AUG", UI=AM.Slider, Text=999408, ExpandHandle="ModMenu_ModSkin", MinValue=1, MaxValue=7, min=1, max=7, GetFunc=function() return _G.LexusState.CustomTextData.SkinAUG or 1 end, SetFunc=function(_, v) _G.LexusState.CustomTextData.SkinAUG = v; if _G.skinIdMappings[101006] and _G.skinIdMappings[101006][v] then _G.WeaponSkinMap[101006] = _G.skinIdMappings[101006][v] end; return true end },
        { Key="ModMenu_Skin_UMP", UI=AM.Slider, Text=999409, ExpandHandle="ModMenu_ModSkin", MinValue=1, MaxValue=5, min=1, max=5, GetFunc=function() return _G.LexusState.CustomTextData.SkinUMP or 1 end, SetFunc=function(_, v) _G.LexusState.CustomTextData.SkinUMP = v; if _G.skinIdMappings[102002] and _G.skinIdMappings[102002][v] then _G.WeaponSkinMap[102002] = _G.skinIdMappings[102002][v] end; return true end },
        { Key="ModMenu_Skin_UZI", UI=AM.Slider, Text=999410, ExpandHandle="ModMenu_ModSkin", MinValue=1, MaxValue=2, min=1, max=2, GetFunc=function() return _G.LexusState.CustomTextData.SkinUZI or 1 end, SetFunc=function(_, v) _G.LexusState.CustomTextData.SkinUZI = v; if _G.skinIdMappings[102001] and _G.skinIdMappings[102001][v] then _G.WeaponSkinMap[102001] = _G.skinIdMappings[102001][v] end; return true end },
        { Key="ModMenu_Skin_Groza", UI=AM.Slider, Text=999411, ExpandHandle="ModMenu_ModSkin", MinValue=1, MaxValue=2, min=1, max=2, GetFunc=function() return _G.LexusState.CustomTextData.SkinGroza or 1 end, SetFunc=function(_, v) _G.LexusState.CustomTextData.SkinGroza = v; if _G.skinIdMappings[101005] and _G.skinIdMappings[101005][v] then _G.WeaponSkinMap[101005] = _G.skinIdMappings[101005][v] end; return true end },
        { Key="ModMenu_Skin_S12K", UI=AM.Slider, Text=999412, ExpandHandle="ModMenu_ModSkin", MinValue=1, MaxValue=2, min=1, max=2, GetFunc=function() return _G.LexusState.CustomTextData.SkinS12K or 1 end, SetFunc=function(_, v) _G.LexusState.CustomTextData.SkinS12K = v; if _G.skinIdMappings[104003] and _G.skinIdMappings[104003][v] then _G.WeaponSkinMap[104003] = _G.skinIdMappings[104003][v] end; return true end },
        { Key="ModMenu_Skin_DBS", UI=AM.Slider, Text=999413, ExpandHandle="ModMenu_ModSkin", MinValue=1, MaxValue=3, min=1, max=3, GetFunc=function() return _G.LexusState.CustomTextData.SkinDBS or 1 end, SetFunc=function(_, v) _G.LexusState.CustomTextData.SkinDBS = v; if _G.skinIdMappings[104004] and _G.skinIdMappings[104004][v] then _G.WeaponSkinMap[104004] = _G.skinIdMappings[104004][v] end; return true end },
        { Key="ModMenu_Skin_Dacia", UI=AM.Slider, Text=999414, ExpandHandle="ModMenu_ModSkin", MinValue=1, MaxValue=90, min=1, max=90, GetFunc=function() return _G.LexusState.CustomTextData.SkinDacia or 1 end, SetFunc=function(_, v) _G.LexusState.CustomTextData.SkinDacia = v; if _G.VehicleSkins[1903001] and _G.VehicleSkins[1903001][v] then _G.VehicleSkinMap[1903001] = _G.VehicleSkins[1903001][v] end; return true end },
        { Key="ModMenu_Skin_UAZ", UI=AM.Slider, Text=999415, ExpandHandle="ModMenu_ModSkin", MinValue=1, MaxValue=90, min=1, max=90, GetFunc=function() return _G.LexusState.CustomTextData.SkinUAZ or 1 end, SetFunc=function(_, v) _G.LexusState.CustomTextData.SkinUAZ = v; if _G.VehicleSkins[1908001] and _G.VehicleSkins[1908001][v] then _G.VehicleSkinMap[1908001] = _G.VehicleSkins[1908001][v] end; return true end },
        { Key="ModMenu_Skin_Coupe", UI=AM.Slider, Text=999416, ExpandHandle="ModMenu_ModSkin", MinValue=1, MaxValue=70, min=1, max=70, GetFunc=function() return _G.LexusState.CustomTextData.SkinCoupe or 1 end, SetFunc=function(_, v) _G.LexusState.CustomTextData.SkinCoupe = v; if _G.VehicleSkins[1961001] and _G.VehicleSkins[1961001][v] then _G.VehicleSkinMap[1961001] = _G.VehicleSkins[1961001][v] end; return true end },
        { Key="ModMenu_Skin_Buggy", UI=AM.Slider, Text=999417, ExpandHandle="ModMenu_ModSkin", MinValue=1, MaxValue=50, min=1, max=50, GetFunc=function() return _G.LexusState.CustomTextData.SkinBuggy or 1 end, SetFunc=function(_, v) _G.LexusState.CustomTextData.SkinBuggy = v; if _G.VehicleSkins[1907001] and _G.VehicleSkins[1907001][v] then _G.VehicleSkinMap[1907001] = _G.VehicleSkins[1907001][v] end; return true end },
        { Key="ModMenu_Skin_Mirado", UI=AM.Slider, Text=999418, ExpandHandle="ModMenu_ModSkin", MinValue=1, MaxValue=27, min=1, max=27, GetFunc=function() return _G.LexusState.CustomTextData.SkinMirado or 1 end, SetFunc=function(_, v) _G.LexusState.CustomTextData.SkinMirado = v; if _G.VehicleSkins[1915001] and _G.VehicleSkins[1915001][v] then _G.VehicleSkinMap[1915001] = _G.VehicleSkins[1915001][v] end; return true end },
        { Key="ModMenu_LiveStyle", UI=AM.Switcher, Text=999419, ExpandHandle="ModMenu_ModSkin", GetFunc=function() return _G.LexusConfig.LiveStyleChange end, SetFunc=function(_, v) _G.LexusConfig.LiveStyleChange = v; return true end },
    }

    -- BAN
    if not _G.BanConfig then _G.BanConfig = { FlyMode=false, SpinMode=false, NoFallDamage=false, RemoveFogGlobal=false, RemoveGrassGlobal=false } end
    local StackBan = {
        { UI = AM.Title, Text = 999500 },
        { Key="Ban_FlyMode", UI=AM.Switcher, Text=999501, GetFunc=function() return _G.BanConfig.FlyMode end, SetFunc=function(_, v) _G.BanConfig.FlyMode = v; return true end },
        { Key="Ban_SpinMode", UI=AM.Switcher, Text=999502, GetFunc=function() return _G.BanConfig.SpinMode end, SetFunc=function(_, v) _G.BanConfig.SpinMode = v; return true end },
        { Key="Ban_NoFall", UI=AM.Switcher, Text=999503, GetFunc=function() return _G.BanConfig.NoFallDamage end, SetFunc=function(_, v) _G.BanConfig.NoFallDamage = v; return true end },
        { Key="Ban_RmFog", UI=AM.Switcher, Text=999504, GetFunc=function() return _G.BanConfig.RemoveFogGlobal end, SetFunc=function(_, v) _G.BanConfig.RemoveFogGlobal = v; return true end },
        { Key="Ban_RmGrass", UI=AM.Switcher, Text=999505, GetFunc=function() return _G.BanConfig.RemoveGrassGlobal end, SetFunc=function(_, v) _G.BanConfig.RemoveGrassGlobal = v; return true end },
        { Key="Ban_BlockAC", UI=AM.Switcher, Text=999506, GetFunc=function() return _G.LexusConfig.BlockAllAntiCheat end, SetFunc=function(_, v) _G.LexusConfig.BlockAllAntiCheat = v; if v and _G.StartBypass_VIP_v5 then _G.StartBypass_VIP_v5() end; return true end },
        { Key="Ban_Panic", UI=AM.Switcher, Text=999507, GetFunc=function() return _G.LexusConfig.PanicKey end, SetFunc=function(_, v) _G.LexusConfig.PanicKey = v; if v then _G.DoPanic() end; return true end },
        { Key="Ban_BypassLoop", UI=AM.Switcher, Text=999508, GetFunc=function() return _G.LexusConfig.BypassLoop end, SetFunc=function(_, v) _G.LexusConfig.BypassLoop = v; return true end },
    }
    _G.LexusConfig.BlockAllAntiCheat = _G.LexusConfig.BlockAllAntiCheat ~= false

    -- LOST TOMB
    local StackLT = {
        { UI = AM.Title, Text = 999600 },
        { Key="LT_Dmg", UI=AM.Switcher, Text=999601, GetFunc=function() return _G.LexusConfig.EnableDamageAnalysis end, SetFunc=function(_, v) _G.LexusConfig.EnableDamageAnalysis = v; return true end },
        { Key="LT_IFD", UI=AM.Switcher, Text=999602, GetFunc=function() return _G.LexusConfig.IgnoreFallingDamage end, SetFunc=function(_, v) _G.LexusConfig.IgnoreFallingDamage = v; return true end },
        { Key="LT_AI", UI=AM.Switcher, Text=999603, GetFunc=function() return _G.LexusConfig.DisableAIIgnoreEnemyTarget end, SetFunc=function(_, v) _G.LexusConfig.DisableAIIgnoreEnemyTarget = v; return true end },
        { Key="LT_Melee", UI=AM.Switcher, Text=999604, GetFunc=function() return _G.LexusConfig.EnableMeleeDamageReport end, SetFunc=function(_, v) _G.LexusConfig.EnableMeleeDamageReport = v; return true end },
        { Key="LT_Know", UI=AM.Switcher, Text=999605, GetFunc=function() return _G.LexusConfig.ShowKnowledgeUI end, SetFunc=function(_, v) _G.LexusConfig.ShowKnowledgeUI = v; return true end },
        { Key="LT_QTE", UI=AM.Switcher, Text=999606, GetFunc=function() return _G.LexusConfig.EnableQTESystem end, SetFunc=function(_, v) _G.LexusConfig.EnableQTESystem = v; return true end },
        { Key="LT_Poison", UI=AM.Switcher, Text=999607, GetFunc=function() return _G.LexusConfig.EnablePoisonSystem end, SetFunc=function(_, v) _G.LexusConfig.EnablePoisonSystem = v; return true end },
        { Key="LT_Hide", UI=AM.Switcher, Text=999608, GetFunc=function() return _G.LexusConfig.AutoHideWeapon end, SetFunc=function(_, v) _G.LexusConfig.AutoHideWeapon = v; return true end },
        { Key="LT_OA", UI=AM.Switcher, Text=999609, GetFunc=function() return _G.LexusConfig.CharacterOverrideAvatar end, SetFunc=function(_, v) _G.LexusConfig.CharacterOverrideAvatar = v; return true end },
        { Key="LT_Skill", UI=AM.Switcher, Text=999610, GetFunc=function() return _G.LexusConfig.EnableSkillFlowReport end, SetFunc=function(_, v) _G.LexusConfig.EnableSkillFlowReport = v; return true end },
        { Key="LT_Box", UI=AM.Switcher, Text=999611, GetFunc=function() return _G.LexusConfig.EnableSupplyBoxEvolution end, SetFunc=function(_, v) _G.LexusConfig.EnableSupplyBoxEvolution = v; return true end },
        { Key="LT_Speed", UI=AM.Switcher, Text=999612, GetFunc=function() return _G.LexusConfig.EnableMaxWalkSpeedCurve end, SetFunc=function(_, v) _G.LexusConfig.EnableMaxWalkSpeedCurve = v; return true end },
        { Key="LT_HP", UI=AM.Switcher, Text=999613, GetFunc=function() return _G.LexusConfig.ShowHeadHPBar end, SetFunc=function(_, v) _G.LexusConfig.ShowHeadHPBar = v; return true end },
        { Key="LT_Gender", UI=AM.Switcher, Text=999614, GetFunc=function() return _G.LexusConfig.EnableCustomGender end, SetFunc=function(_, v) _G.LexusConfig.EnableCustomGender = v; return true end },
        { Key="LT_LA", UI=AM.Switcher, Text=999615, GetFunc=function() return _G.LexusConfig.EnableLoadingAvatar end, SetFunc=function(_, v) _G.LexusConfig.EnableLoadingAvatar = v; return true end },
        { Key="LT_Smoke", UI=AM.Switcher, Text=999616, GetFunc=function() return _G.LexusConfig.EnableSmokeParticle end, SetFunc=function(_, v) _G.LexusConfig.EnableSmokeParticle = v; return true end },
        { Key="LT_Shake", UI=AM.Switcher, Text=999617, GetFunc=function() return _G.LexusConfig.EnableDamageShake end, SetFunc=function(_, v) _G.LexusConfig.EnableDamageShake = v; return true end },
        { Key="LT_Steal", UI=AM.Switcher, Text=999618, GetFunc=function() return _G.LexusConfig.EnableStealLifeEffect end, SetFunc=function(_, v) _G.LexusConfig.EnableStealLifeEffect = v; return true end },
        { Key="LT_Tomb", UI=AM.Switcher, Text=999619, GetFunc=function() return _G.LexusConfig.EnableTombBoxFilter end, SetFunc=function(_, v) _G.LexusConfig.EnableTombBoxFilter = v; return true end },
        { Key="LT_Start", UI=AM.Switcher, Text=999620, GetFunc=function() return _G.LexusConfig.EnableGameStartSpeedUp end, SetFunc=function(_, v) _G.LexusConfig.EnableGameStartSpeedUp = v; return true end },
        { Key="LT_Energy", UI=AM.Switcher, Text=999621, GetFunc=function() return _G.LexusConfig.ExtraEnergyBonus end, SetFunc=function(_, v) _G.LexusConfig.ExtraEnergyBonus = v; return true end },
        { Key="LT_Behind", UI=AM.Switcher, Text=999622, GetFunc=function() return _G.LexusConfig.BehindAttackBonus end, SetFunc=function(_, v) _G.LexusConfig.BehindAttackBonus = v; return true end },
    }

    -- TOP HUD
    local StackHUD = {
        { UI = AM.Title, Text = 999700 },
        { Key="HUD_Profile", UI=AM.Switcher, Text=999701, GetFunc=function() return _G.LexusConfig.TopHUDProfile end, SetFunc=function(_, v) _G.LexusConfig.TopHUDProfile = v; return true end },
        { Key="HUD_UID", UI=AM.Switcher, Text=999702, GetFunc=function() return _G.LexusConfig.TopHUDUID end, SetFunc=function(_, v) _G.LexusConfig.TopHUDUID = v; return true end },
        { Key="HUD_Stats", UI=AM.Switcher, Text=999703, GetFunc=function() return _G.LexusConfig.TopHUDStats end, SetFunc=function(_, v) _G.LexusConfig.TopHUDStats = v; return true end },
        { Key="HUD_Outfit", UI=AM.Switcher, Text=999704, GetFunc=function() return _G.LexusConfig.TopHUDOutfit end, SetFunc=function(_, v) _G.LexusConfig.TopHUDOutfit = v; return true end },
        { Key="HUD_EnemyPlate", UI=AM.Switcher, Text=999705, GetFunc=function() return _G.LexusConfig.TopHUDEnemyPlate end, SetFunc=function(_, v) _G.LexusConfig.TopHUDEnemyPlate = v; return true end },
        { Key="HUD_BotPlate", UI=AM.Switcher, Text=999706, GetFunc=function() return _G.LexusConfig.TopHUDBotPlate end, SetFunc=function(_, v) _G.LexusConfig.TopHUDBotPlate = v; return true end },
    }

    if not SPD.MyModMenu then
        SPD.MyModMenu = {
            Key = "MyModMenu",
            Text = 999000,
            UIKey = "Setting_Page_Privacy",
            Category = {
                { Key = "Cat_ESP", Text = 999001, Stack = StackESP },
                { Key = "Cat_Aimbot", Text = 999002, Stack = StackAimbot },
                { Key = "Cat_Combat", Text = 999003, Stack = StackCombat },
                { Key = "Cat_Skin", Text = 999004, Stack = StackSkin },
                { Key = "Cat_Ban", Text = 999005, Stack = StackBan },
                { Key = "Cat_LT", Text = 999006, Stack = StackLT },
                { Key = "Cat_HUD", Text = 999007, Stack = StackHUD },
            }
        }
        table.insert(SC, SPD.MyModMenu)
    end

    local UI = _G.UIManager
    if UI and not UI._IsModMenuHooked then
        local old = UI.ShowUI
        UI.ShowUI = function(config, ...)
            local args = {...}
            local n = select('#', ...)
            if config and config.keyName and string.find(string.lower(config.keyName), "setting_main") then
                local cat = args[1]
                if type(cat) == "table" then
                    local has = false
                    for _, p in ipairs(cat) do if type(p) == "table" and p.Key == "MyModMenu" then has = true; break end end
                    if not has and SPD.MyModMenu then table.insert(cat, 1, SPD.MyModMenu) end
                end
            end
            local tu = table.unpack or unpack
            return old(config, tu(args, 1, n))
        end
        UI._IsModMenuHooked = true
    end
end

_G.InitModMenuTab()
print("[CHEN VIP v6] Menu ready — @FLUXMOD10")

-- ============================================================================
-- PANIC
-- ============================================================================
_G.DoPanic = function()
    pcall(function()
        _G.LexusState.PanicActive = true
        for k, _ in pairs(_G.LexusConfig) do
            if type(_G.LexusConfig[k]) == "boolean" then _G.LexusConfig[k] = false end
        end
        for _, m in ipairs(_G.LexusState.TrackedMarks and {unpack(_G.LexusState.TrackedMarks)} or {}) do SafeRemoveMark(m) end
        _G.LexusState.TrackedMarks = {}
        _G.LexusState.EnemyMarks = {}
        _G.OutfitMap = {}; _G.WeaponSkinMap = {}; _G.VehicleSkinMap = {}
        if _G.SaveModSettings then _G.SaveModSettings() end
        Notify("PANIC — all mods off")
    end)
end

-- ============================================================================
-- BAN LOOP
-- ============================================================================
local function BanFeaturesLoop()
    pcall(function()
        local uCon = slua_GameFrontendHUD:GetPlayerController()
        if not Valid(uCon) then return end
        local pawn = uCon:GetPlayerCharacterSafety()
        if not Valid(pawn) then return end
        if _G.BanConfig.FlyMode then
            pawn.CharacterMovement.GravityScale = -0.45
            pawn.CharacterMovement.MaxWalkSpeed = 1350
            pawn.CharacterMovement.JumpZVelocity = 1350
        end
        if _G.BanConfig.NoFallDamage then
            pawn.CharacterMovement.bEnableLandDamage = false
            pawn.CharacterMovement.FallingLandedDamageEnabled = false
            pawn:SetAttrValue("LandDamageReduce", 1, -1)
        end
        if _G.BanConfig.SpinMode and Valid(pawn.Mesh) then
            _G.spinAngle = (_G.spinAngle or 0) + 20
            if _G.spinAngle > 360 then _G.spinAngle = 0 end
            pawn.Mesh:K2_SetRelativeRotation(FRotator(0, _G.spinAngle, 0), false, nil, false)
        end
        if _G.BanConfig.RemoveFogGlobal then
            UKismetSystemLibrary.ExecuteConsoleCommand(nil, "r.Fog 0")
            UKismetSystemLibrary.ExecuteConsoleCommand(nil, "r.VolumetricFog 0")
        end
        if _G.BanConfig.RemoveGrassGlobal then
            UKismetSystemLibrary.ExecuteConsoleCommand(nil, "foliage.DensityScale 0")
            UKismetSystemLibrary.ExecuteConsoleCommand(nil, "grass.DensityScale 0")
        end
    end)
end
local function StartBanLoop()
    local uCon = slua_GameFrontendHUD:GetPlayerController()
    if not Valid(uCon) then uCon = import("GameplayStatics").GetPlayerController(slua_GameFrontendHUD:GetWorld(), 0) end
    if not Valid(uCon) then return end
    uCon:AddGameTimer(0.05, true, BanFeaturesLoop)
end
pcall(StartBanLoop)

-- ============================================================================
-- MAIN LOOP
-- ============================================================================
local function MainLoop()
    if _G.LexusState.CustomTextData == nil then
        _G.LexusState.CustomTextData = {
            OuterSpeed=10, InnerSpeed=10, HRecoil=0.3, VRecoil=0.3,
            MagicHead=0, MagicBody=0.5, MagicLegs=0, IpadViewFOV=120,
            AimTouchHipPrio=1, AimTouchHipBone=1, AimTouchHipCond=1, AimTouchHipSpeed=50, AimTouchHipFOV=30, AimTouchHipDist=250,
            AimTouchSGPrio=1, AimTouchSGBone=2, AimTouchSGCond=1, AimTouchSGSpeed=80, AimTouchSGFOV=40, AimTouchSGDist=30,
            AimTouchScopePrio=1, AimTouchScopeBone=2, AimTouchScopeCond=1, AimTouchScopeSpeed=40, AimTouchScopeFOV=20, AimTouchScopeDist=300,
            AimTouchSniperPrio=1, AimTouchSniperBone=1, AimTouchSniperCond=2, AimTouchSniperSpeed=30, AimTouchSniperFOV=20, AimTouchSniperDist=400,
        }
    end
    local okData, GD = pcall(require, "GameLua.GameCore.Data.GameplayData")
    if not okData or not GD then return end
    local pc = GD.GetPlayerController()
    local localPlayer = nil
    if Valid(pc) then localPlayer = pc:GetPlayerCharacterSafety() end

    if not Valid(localPlayer) then
        if _G.LexusState.TrackedMarks then
            for mId, _ in pairs(_G.LexusState.TrackedMarks) do SafeRemoveMark(mId) end
        end
        _G.LexusState.TrackedMarks = {}
        _G.LexusState.EnemyMarks = {}
        _G.LexusState.PrevGraphicsState = {}
        return
    end

    -- BYPASS LOOP
    if _G.LexusConfig.BypassLoop then
        local curT = os.clock()
        if curT - (_G.LexusState.LastBypassTick or 0) > 10.0 then
            _G.LexusState.LastBypassTick = curT
            if _G.StartBypass_VIP_v5 then _G.StartBypass_VIP_v5() end
        end
    end

    local Cached_PPM = nil
    pcall(function() Cached_PPM = import("PostProcessManager").GetInstance() end)
    local Cached_MyHUD = pc and pc.MyHUD or nil

    if _G.LexusConfig.UnlockFPS then
        pcall(function()
            local lsg = require("client.slua.logic.setting.logic_setting_graphics")
            local gi = lsg.GetGameInstance()
            if gi then gi:ExecuteCMD("t.MaxFPS", "165"); gi:ExecuteCMD("r.FrameRateLimit", "165") end
        end)
    end

    InitializeNativeESP()

    if _G.LexusConfig.IpadView and _G.LexusState.CustomTextData then
        pcall(function()
            local t = _G.LexusState.CustomTextData.IpadViewFOV or 120
            local cam = localPlayer.ThirdPersonCameraComponent
            if Valid(cam) and not localPlayer.bIsWeaponAiming then
                if cam.FieldOfView ~= t then cam.FieldOfView = t end
            end
        end)
    else
        pcall(function()
            local cam = localPlayer.ThirdPersonCameraComponent
            if Valid(cam) and not localPlayer.bIsWeaponAiming then
                if cam.FieldOfView ~= 90 then cam.FieldOfView = 90 end
            end
        end)
    end

    if _G.LexusConfig.AimTouchEnable then _G.AimTouch() end
    if _G.LexusConfig.AimTriggerbot then _G.TriggerbotTick(pc, localPlayer) end
    if _G.LexusConfig.AimShowFOVCircle then _G.DrawFOVCircle(pc, localPlayer) end

    MovementTick(localPlayer)
    WorldExtrasTick(pc, localPlayer)

    -- TOP HUD self
    DrawSelfHUD(pc, localPlayer)
    -- Self plate over own head
    if _G.LexusConfig.EspSelfPlate and Valid(Cached_MyHUD) then
        local hp = localPlayer.Health or 0
        local mx = localPlayer.HealthMax or 100
        if mx <= 0 then mx = 100 end
        Cached_MyHUD:AddDebugText("YOU "..math.floor(hp).."/"..math.floor(mx), localPlayer, 0.0, {X=0,Y=0,Z=200}, {X=0,Y=0,Z=200}, C_CYAN, true, false, true, nil, 0.9, true)
    end

    if _G.LexusConfig.HitMarker then HitMarkerTick(pc) end
    if _G.LexusConfig.FPSPingHUD then FPSPingTick(pc) end
    if _G.LexusConfig.KillFeed then KillFeedTick(pc) end

    if _G.LexusConfig.ModSkin then
        if not _G.TDSkinLoopStarted then
            if _G.InitializeSkinModSystem then _G.InitializeSkinModSystem() end
            if _G.ForceRefreshSkinMaps then _G.ForceRefreshSkinMaps() end
            _G.TDSkinLoopStarted = true
        end
        _G.LexusState.SkinWasApplied = true
        _G.SkinTickCounter = (_G.SkinTickCounter or 0) + 1
        if _G.SkinTickCounter % 30 == 0 then if _G.ReadLiveConfig then _G.ReadLiveConfig() end end
        pcall(function()
            if _G.ForceEnableKillCounterUI then _G.ForceEnableKillCounterUI() end
            if _G.equip_character_avatar then _G.equip_character_avatar(localPlayer) end
            if _G.ApplyWeaponSkins then _G.ApplyWeaponSkins(localPlayer) end
            if _G.ApplyVehicleSkins then _G.ApplyVehicleSkins(localPlayer) end
            if _G.HandlePetLogic then _G.HandlePetLogic() end
            if _G.SkinTickCounter % 10 == 0 and _G.DeadBox_TemperRequest then _G.DeadBox_TemperRequest(pc) end
        end)
    else
        if _G.LexusState.SkinWasApplied then
            _G.OutfitMap = {}; _G.WeaponSkinMap = {}; _G.VehicleSkinMap = {}
            _G.LexusState.SkinWasApplied = false
        end
        _G.TDSkinLoopStarted = false
    end

    if _G.LexusConfig.LiveStyleChange then
        LiveStyleChangeTick(localPlayer)
        LiveWeaponVehicleTick(localPlayer)
    end

    -- HiggsBoson tick-zero
    pcall(function()
        if Valid(pc) then
            if pc.HiggsBoson then pc.HiggsBoson.bMHActive = false; pc.HiggsBoson.bCallPreReplication = false end
            if pc.HiggsBosonComponent then pc.HiggsBosonComponent.bMHActive = false; pc.HiggsBosonComponent.bCallPreReplication = false end
        end
    end)

    -- Auto Head
    pcall(function()
        local ac = localPlayer.AutoAimComp
        if Valid(ac) then
            if not _G.LexusState.OrigAutoAimCompCached then
                _G.LexusState.OrigAutoAimCompCached = {
                    bOnlyHitHead = ac.bOnlyHitHead,
                    HeadBoneName = ac.HeadBoneName,
                    Bones = ac.Bones,
                    ChestBoneName = ac.ChestBoneName,
                    PelvisBoneName = ac.PelvisBoneName,
                }
            end
            if _G.LexusConfig.AutoHead then
                ac.bOnlyHitHead = true
                ac.HeadBoneName = "Head"
                pcall(function() ac.Bones = {"Head"} end)
                ac.ChestBoneName = "Head"
                ac.PelvisBoneName = "Head"
            else
                local o = _G.LexusState.OrigAutoAimCompCached
                ac.bOnlyHitHead = o.bOnlyHitHead
                ac.HeadBoneName = o.HeadBoneName
                pcall(function() ac.Bones = o.Bones or {"Head","Head","Head"} end)
                ac.ChestBoneName = o.ChestBoneName
                ac.PelvisBoneName = o.PelvisBoneName
            end
        end
    end)

    -- Graphics toggles
    pcall(function()
        local lsg = require("client.slua.logic.setting.logic_setting_graphics")
        local gi = lsg.GetGameInstance()
        if gi then
            if _G.LexusConfig.RemoveGrass and not _G.LexusState.PrevGraphicsState.RemoveGrass then
                gi:ExecuteCMD("grass.DensityScale", "0"); gi:ExecuteCMD("grass.DiscardDataOnLoad", "1")
                _G.LexusState.PrevGraphicsState.RemoveGrass = true
            elseif not _G.LexusConfig.RemoveGrass and _G.LexusState.PrevGraphicsState.RemoveGrass then
                gi:ExecuteCMD("grass.DensityScale", "1"); gi:ExecuteCMD("grass.DiscardDataOnLoad", "0")
                _G.LexusState.PrevGraphicsState.RemoveGrass = false
            end
            if _G.LexusConfig.RemoveFog and not _G.LexusState.PrevGraphicsState.RemoveFog then
                gi:ExecuteCMD("r.Fog", "0"); gi:ExecuteCMD("r.VolumetricFog", "0")
                _G.LexusState.PrevGraphicsState.RemoveFog = true
            elseif not _G.LexusConfig.RemoveFog and _G.LexusState.PrevGraphicsState.RemoveFog then
                gi:ExecuteCMD("r.Fog", "1"); gi:ExecuteCMD("r.VolumetricFog", "1")
                _G.LexusState.PrevGraphicsState.RemoveFog = false
            end
            if _G.LexusConfig.WhiteBody and not _G.LexusState.PrevGraphicsState.WhiteBody then
                gi:ExecuteCMD("r.CharacterDiffuseOffset", "2")
                gi:ExecuteCMD("r.CharacterDiffusePower", "5")
                gi:ExecuteCMD("r.CharacterMinShadowFactor", "100")
                _G.LexusState.PrevGraphicsState.WhiteBody = true
            elseif not _G.LexusConfig.WhiteBody and _G.LexusState.PrevGraphicsState.WhiteBody then
                gi:ExecuteCMD("r.CharacterDiffuseOffset", "0")
                gi:ExecuteCMD("r.CharacterDiffusePower", "1")
                gi:ExecuteCMD("r.CharacterMinShadowFactor", "1")
                _G.LexusState.PrevGraphicsState.WhiteBody = false
            end
            if _G.LexusConfig.BlackSky and not _G.LexusState.PrevGraphicsState.BlackSky then
                gi:ExecuteCMD("r.CylinderMaxDrawHeight", "9999")
                _G.LexusState.PrevGraphicsState.BlackSky = true
            elseif not _G.LexusConfig.BlackSky and _G.LexusState.PrevGraphicsState.BlackSky then
                gi:ExecuteCMD("r.CylinderMaxDrawHeight", "0000")
                _G.LexusState.PrevGraphicsState.BlackSky = false
            end
        end
    end)

    -- Weapon mods
    pcall(function()
        local weapon = nil
        pcall(function()
            local wm = localPlayer.WeaponManagerComponent
            if Valid(wm) and type(wm.GetCurrentWeapon) == "function" then weapon = wm:GetCurrentWeapon() end
        end)
        if not Valid(weapon) then
            if type(localPlayer.GetCurrentShootWeapon) == "function" then weapon = localPlayer:GetCurrentShootWeapon()
            elseif type(localPlayer.GetCurrentWeapon) == "function" then weapon = localPlayer:GetCurrentWeapon() end
        end
        if Valid(weapon) then
            local entities = {}
            if Valid(weapon.ShootWeaponEntity_GEN_VARIABLE) then table.insert(entities, weapon.ShootWeaponEntity_GEN_VARIABLE) end
            if Valid(weapon.ShootWeaponEntity) then table.insert(entities, weapon.ShootWeaponEntity) end
            if Valid(weapon.ShootWeaponComponent) and Valid(weapon.ShootWeaponComponent.ShootWeaponEntityComponent) then table.insert(entities, weapon.ShootWeaponComponent.ShootWeaponEntityComponent) end
            for _, entity in ipairs(entities) do
                local anyOn = _G.LexusConfig.CustomHRecoil or _G.LexusConfig.CustomVRecoil or _G.LexusConfig.LessShake or _G.LexusConfig.Accuracy or _G.LexusConfig.Crosshair or _G.LexusConfig.GodMode
                if anyOn then
                    if not entity.OriginalStatsCached then
                        entity.OriginalStatsCached = {
                            GameDeviationFactor = entity.GameDeviationFactor,
                            GameDeviationAccuracy = entity.GameDeviationAccuracy,
                            BulletFireSpeed = entity.BulletFireSpeed,
                            ShootInterval = entity.ShootInterval,
                            BaseDamage = entity.BaseDamage,
                            AccessoriesHRecoilFactor = entity.AccessoriesHRecoilFactor,
                            AccessoriesVRecoilFactor = entity.AccessoriesVRecoilFactor,
                            RecoilKick = entity.RecoilKick,
                            RecoilKickADS = entity.RecoilKickADS,
                            AnimationKick = entity.AnimationKick
                        }
                    end
                    if _G.LexusConfig.CustomHRecoil then entity.AccessoriesHRecoilFactor = _G.LexusState.CustomTextData.HRecoil or 0.3 end
                    if _G.LexusConfig.CustomVRecoil then entity.AccessoriesVRecoilFactor = _G.LexusState.CustomTextData.VRecoil or 0.3 end
                    if _G.LexusConfig.LessShake then entity.RecoilKick = 0.5; entity.RecoilKickADS = 0.0; entity.AnimationKick = 0.5 end
                    if _G.LexusConfig.Accuracy then entity.GameDeviationAccuracy = 0.0 end
                    if _G.LexusConfig.Crosshair then entity.GameDeviationFactor = 0.1 end
                    if _G.LexusConfig.GodMode then entity.BulletFireSpeed = 500000.0; entity.ShootInterval = 0.001; entity.BaseDamage = 60000.0 end
                    entity.LexusWeaponModsActive = true
                elseif entity.LexusWeaponModsActive and entity.OriginalStatsCached then
                    local o = entity.OriginalStatsCached
                    entity.GameDeviationFactor = o.GameDeviationFactor
                    entity.GameDeviationAccuracy = o.GameDeviationAccuracy
                    entity.BulletFireSpeed = o.BulletFireSpeed
                    entity.ShootInterval = o.ShootInterval
                    entity.BaseDamage = o.BaseDamage
                    entity.AccessoriesHRecoilFactor = o.AccessoriesHRecoilFactor
                    entity.AccessoriesVRecoilFactor = o.AccessoriesVRecoilFactor
                    entity.RecoilKick = o.RecoilKick
                    entity.RecoilKickADS = o.RecoilKickADS
                    entity.AnimationKick = o.AnimationKick
                    entity.LexusWeaponModsActive = false
                end
            end
        end
    end)

    -- Magic bullet hash
    local mHead, mBody, mLegs = 1.0, 1.0, 1.0
    local runInject = false
    pcall(function()
        if _G.LexusConfig.CustomMagicBullet then
            runInject = true
            mHead, mBody, mLegs = 0, 0.5, 0
            if _G.LexusState.CustomTextData then
                local c = _G.LexusState.CustomTextData
                if c.MagicHead ~= nil then mHead = tonumber(c.MagicHead) or mHead end
                if c.MagicBody ~= nil then mBody = tonumber(c.MagicBody) or mBody end
                if c.MagicLegs ~= nil then mLegs = tonumber(c.MagicLegs) or mLegs end
            end
        end
        if runInject then
            local h = "M_"..tostring(mHead).."_"..tostring(mBody).."_"..tostring(mLegs)
            if _G.LexusState.LastMagicConfigHash ~= h then
                _G.LexusState.MagicUpdateVersion = (_G.LexusState.MagicUpdateVersion or 0) + 1
                _G.LexusState.LastMagicConfigHash = h
            end
        else
            if _G.LexusState.LastMagicConfigHash ~= "OFF" then
                _G.LexusState.MagicUpdateVersion = (_G.LexusState.MagicUpdateVersion or 0) + 1
                _G.LexusState.LastMagicConfigHash = "OFF"
            end
        end
    end)

    -- Enemy loop
    pcall(function()
        local allChars = {}
        if GD.GetAllPlayerCharacters then allChars = GD.GetAllPlayerCharacters()
        elseif GD.GameCharacters then for _, c in pairs(GD.GameCharacters) do table.insert(allChars, c) end end

        local validKeys = {}
        for _, e in pairs(allChars) do
            if Valid(e) and e ~= localPlayer then validKeys[GetSafeEnemyKey(e)] = true end
        end
        for key, d in pairs(_G.LexusState.EnemyMarks) do
            if not validKeys[key] then
                SafeRemoveMark(d.radarMark); SafeRemoveMark(d.hpMark); SafeRemoveMark(d.distMark)
                if d.MIDs then
                    for _, t in pairs(d.MIDs) do for k, _ in pairs(t) do t[k] = nil end end
                    d.MIDs = nil
                end
                d.enemy = nil; d.CachedMeshes = nil
                _G.LexusState.EnemyMarks[key] = nil
            end
        end

        local realCount, aiCount = 0, 0
        local function FirstElem(arr)
            if arr and type(arr.Num) == "function" and arr:Num() > 0 and type(arr.Get) == "function" then return arr:Get(0) end
            if arr and type(arr) == "table" and #arr > 0 then return arr[1] end
            return nil
        end
        local BoneScaleMap = {
            ["head"]=mHead, ["neck_01"]=mHead,
            ["pelvis"]=mBody, ["spine_01"]=mBody, ["spine_02"]=mBody, ["spine_03"]=mBody,
            ["thigh_l"]=mLegs, ["thigh_r"]=mLegs,
            ["calf_l"]=mLegs, ["calf_r"]=mLegs,
            ["foot_l"]=mLegs, ["foot_r"]=mLegs
        }
        local mLoc = nil
        pcall(function() if type(localPlayer.K2_GetActorLocation) == "function" then mLoc = localPlayer:K2_GetActorLocation() end end)

        for _, enemy in pairs(allChars) do
            if Valid(enemy) and enemy ~= localPlayer and enemy.TeamID ~= localPlayer.TeamID then
                local bDead = false
                pcall(function()
                    if type(enemy.IsDead) == "function" then bDead = enemy:IsDead()
                    elseif enemy.bIsDead ~= nil then bDead = enemy.bIsDead
                    elseif enemy.bIsDeadFlag ~= nil then bDead = enemy.bIsDeadFlag end
                    if enemy.HealthStatus ~= nil and enemy.HealthStatus == 2 then bDead = true end
                end)
                local ek = GetSafeEnemyKey(enemy)
                _G.LexusState.EnemyMarks[ek] = _G.LexusState.EnemyMarks[ek] or { enemy = enemy }
                local md = _G.LexusState.EnemyMarks[ek]
                md.enemy = enemy
                if not bDead then
                    local eMesh = nil
                    pcall(function() eMesh = enemy.Mesh end)
                    local aLoc = nil
                    pcall(function() if type(enemy.K2_GetActorLocation) == "function" then aLoc = enemy:K2_GetActorLocation() end end)
                    local _, _ = CheckIsAI(enemy, md)
                    local isBot = md.AK_IS_BOT or false
                    local curMeshCnt = 0
                    if Valid(eMesh) then curMeshCnt = #GetAllSkeletalMeshes(enemy, md) end
                    local meshChanged = (md.LastMeshCountWall ~= curMeshCnt)

                    if _G.LexusConfig.WallXuyenTuong then
                        if meshChanged or not md.WallhackApplied then
                            ApplyWallXuyenTuong(enemy, md)
                            md.WallhackApplied = true
                            md.LastMeshCountWall = curMeshCnt
                        end
                    else UndoWallXuyenTuong(enemy, md) end

                    if _G.LexusConfig.ColorBodyV2 then ApplyColorBodyV2(enemy, pc, md)
                    else UndoColorBodyV2(enemy, md) end

                    -- Magic bullet hitbox scale
                    pcall(function()
                        if not slua.isValid(eMesh) then return end
                        local ms = tostring(eMesh)
                        if md.MagicBulletHash == _G.LexusState.LastMagicConfigHash and md.LastMeshStr == ms then return end
                        local PA = eMesh.PhysicsAssetOverride
                        if not slua.isValid(PA) and eMesh.SkeletalMesh then PA = eMesh.SkeletalMesh.PhysicsAsset end
                        if slua.isValid(PA) and PA.SkeletalBodySetups then
                            if not _G.AK_ModdedPhysAssets then _G.AK_ModdedPhysAssets = {} end
                            local pName = "DefaultPhys"
                            pcall(function() pName = PA:GetName() end)
                            if _G.AK_ModdedPhysAssets[pName] ~= _G.LexusState.LastMagicConfigHash then
                                if not _G.AK_OrigHitboxes then _G.AK_OrigHitboxes = {} end
                                if not _G.AK_OrigHitboxes[pName] then _G.AK_OrigHitboxes[pName] = {} end
                                local OH = _G.AK_OrigHitboxes[pName]
                                local SBS = PA.SkeletalBodySetups
                                local n = type(SBS.Num) == "function" and SBS:Num() or #SBS
                                local lim = n > 50 and 50 or n
                                for i = 1, lim do
                                    local BS = type(SBS.Get) == "function" and SBS:Get(i-1) or SBS[i]
                                    if slua.isValid(BS) then
                                        local lb = string.lower(tostring(BS.BoneName))
                                        local key = nil
                                        for k, _ in pairs(BoneScaleMap) do if string.find(lb, k, 1, true) then key = k; break end end
                                        if key then
                                            local scale = 1.0
                                            if runInject then scale = BoneScaleMap[key] end
                                            local AG = BS.AggGeom
                                            local BE = AG and AG.BoxElems or BS.BoxElems
                                            local SE = AG and AG.SphereElems or BS.SphereElems
                                            local PE = AG and AG.SphylElems or BS.SphylElems
                                            local box = FirstElem(BE); local sph = FirstElem(SE); local sphy = FirstElem(PE)
                                            if not OH[key] then
                                                OH[key] = { Box=nil, Sphere=nil, Sphyl=nil }
                                                if box then OH[key].Box = {X=box.X,Y=box.Y,Z=box.Z} end
                                                if sph then OH[key].Sphere = {Radius=sph.Radius} end
                                                if sphy then OH[key].Sphyl = {Radius=sphy.Radius,Length=sphy.Length} end
                                            end
                                            local od = OH[key]
                                            if od.Box and box then
                                                box.X = od.Box.X * scale; box.Y = od.Box.Y * scale; box.Z = od.Box.Z * scale
                                                if type(BE.Set) == "function" then BE:Set(0, box) else BE[1] = box end
                                                if AG then AG.BoxElems = BE; BS.AggGeom = AG else BS.BoxElems = BE end
                                            end
                                            if od.Sphere and sph then
                                                sph.Radius = od.Sphere.Radius * scale
                                                if type(SE.Set) == "function" then SE:Set(0, sph) else SE[1] = sph end
                                                if AG then AG.SphereElems = SE; BS.AggGeom = AG else BS.SphereElems = SE end
                                            end
                                            if od.Sphyl and sphy then
                                                sphy.Radius = od.Sphyl.Radius * scale; sphy.Length = od.Sphyl.Length * scale
                                                if type(PE.Set) == "function" then PE:Set(0, sphy) else PE[1] = sphy end
                                                if AG then AG.SphylElems = PE; BS.AggGeom = AG else BS.SphylElems = PE end
                                            end
                                        end
                                    end
                                end
                                _G.AK_ModdedPhysAssets[pName] = _G.LexusState.LastMagicConfigHash
                            end
                            if eMesh.SetPhysicsAsset then eMesh:SetPhysicsAsset(PA) end
                            eMesh.PhysicsAssetOverride = PA
                            md.MagicBulletHash = _G.LexusState.LastMagicConfigHash
                            md.LastMeshStr = ms
                        end
                    end)

                    local distM = 0
                    pcall(function() distM = localPlayer:GetDistanceTo(enemy) / 100 end)
                    local cHp, mHp = 100, 100
                    pcall(function()
                        if enemy.Health then cHp = enemy.Health elseif type(enemy.GetHealth) == "function" then cHp = enemy:GetHealth() end
                        if enemy.HealthMax then mHp = enemy.HealthMax elseif type(enemy.GetHealthMax) == "function" then mHp = enemy:GetHealthMax() end
                    end)
                    if mHp <= 0 then mHp = 100 end
                    local hpR = cHp / mHp
                    local eName = "Enemy"
                    pcall(function()
                        if enemy.PlayerName then eName = enemy.PlayerName
                        elseif type(enemy.GetPlayerName) == "function" then eName = enemy:GetPlayerName() end
                    end)
                    if eName == "" then eName = "Enemy" end
                    local isKnock = (cHp <= 0 and enemy.HealthStatus == 1)

                    -- ESP Antenna
                    if _G.LexusConfig.EspAntenna then
                        pcall(function()
                            if Valid(Cached_MyHUD) and distM <= (_G.LexusConfig.EspMaxDistance or 400) then
                                for i = 1, 8 do
                                    local zO = 105 + (i * 1000)
                                    Cached_MyHUD:AddDebugText("|", enemy, 0.06, {X=0,Y=0,Z=zO}, {X=0,Y=0,Z=zO}, C_GREEN, true, false, true, nil, 1.2, true)
                                end
                                Cached_MyHUD:AddDebugText("I", enemy, 0.06, {X=0,Y=0,Z=8105}, {X=0,Y=0,Z=8105}, C_GREEN, true, false, true, nil, 1.5, true)
                            end
                        end)
                    end

                    -- ESP skeleton + snapline
                    if _G.LexusConfig.EspLoai6 then
                        pcall(function()
                            if Valid(Cached_MyHUD) and Valid(eMesh) and type(eMesh.GetSocketLocation) == "function" and distM <= (_G.LexusConfig.EspMaxDistance or 400) and aLoc then
                                local bl = {}
                                for _, bn in ipairs(GLOBAL_BONE_LIST) do
                                    local draw = true
                                    if distM > 150 and (bn ~= "head" and bn ~= "pelvis" and bn ~= "neck_01") then draw = false end
                                    if draw then
                                        local wl = eMesh:GetSocketLocation(bn)
                                        if wl then
                                            bl[bn] = {X=wl.X-aLoc.X, Y=wl.Y-aLoc.Y, Z=wl.Z-aLoc.Z}
                                            local mk, sz, col = "▪", 0.25, C_CYAN
                                            if bn == "head" then mk = "●"; sz = 0.45; col = C_RED
                                            elseif bn == "pelvis" or bn == "neck_01" then mk = "▪"; sz = 0.35; col = C_YELLOW end
                                            Cached_MyHUD:AddDebugText(mk, enemy, 0.06, bl[bn], bl[bn], col, true, false, true, nil, sz, true)
                                        end
                                    end
                                end
                                if distM <= 100 then
                                    for _, pr in ipairs(GLOBAL_CONNECTIONS) do
                                        local p1, p2 = bl[pr[1]], bl[pr[2]]
                                        if p1 and p2 then
                                            local col = pr[3]
                                            local dx, dy, dz = p2.X-p1.X, p2.Y-p1.Y, p2.Z-p1.Z
                                            local len = math.sqrt(dx*dx+dy*dy+dz*dz)
                                            local segs = math.floor(len / 12)
                                            if segs > 5 then segs = 5 end
                                            if segs < 2 then segs = 2 end
                                            for i = 1, segs do
                                                local f = i / (segs + 1)
                                                local mid = { X=p1.X+dx*f, Y=p1.Y+dy*f, Z=p1.Z+dz*f }
                                                Cached_MyHUD:AddDebugText("•", enemy, 0.06, mid, mid, col, true, false, true, nil, 0.35, true)
                                            end
                                        end
                                    end
                                end
                                if _G.LexusConfig.EspSnapline then
                                    local h = bl["head"] or {X=0,Y=0,Z=170}
                                    for k = 0, 8 do
                                        local f = k / 8
                                        local p = { X=h.X*f, Y=h.Y*f, Z=h.Z*f }
                                        Cached_MyHUD:AddDebugText("|", enemy, 0.06, p, p, C_CYAN, true, false, true, nil, 0.35, true)
                                    end
                                end
                            end
                        end)
                    end

                    -- ESP state/weapon
                    if _G.LexusConfig.EspLoai7 then
                        pcall(function()
                            if Valid(Cached_MyHUD) then
                                if distM <= 600 then if isBot then aiCount = aiCount + 1 else realCount = realCount + 1 end end
                                if distM <= (_G.LexusConfig.EspMaxDistance or 400) then
                                    local state = "Standing"
                                    local pose = enemy.PoseState or (type(enemy.GetPoseState) == "function" and enemy:GetPoseState()) or 0
                                    if pose == 1 then state = "Crouching"
                                    elseif pose == 2 then state = "Prone" end
                                    local now = os.clock()
                                    if md.AK_LAST_WEP_TIME == nil or now > md.AK_LAST_WEP_TIME + 1.5 then
                                        local w = enemy.CurrentWeapon
                                        if not w and type(enemy.GetCurrentWeapon) == "function" then w = enemy:GetCurrentWeapon() end
                                        local wn = "Unarmed"
                                        if Valid(w) and type(w.GetWeaponName) == "function" then wn = w:GetWeaponName() end
                                        md.AK_CACHED_WEP_NAME = tostring(wn)
                                        md.AK_LAST_WEP_TIME = now
                                    end
                                    local parts = {}
                                    if _G.LexusConfig.EspShowState then table.insert(parts, state) end
                                    if _G.LexusConfig.EspShowWeapon then table.insert(parts, md.AK_CACHED_WEP_NAME or "Unarmed") end
                                    local text = table.concat(parts, " - ")
                                    if text ~= "" then
                                        local tc = isBot and C_CYAN or C_YELLOW
                                        local sc = math.max(0.5, 0.8 - (distM / 400))
                                        Cached_MyHUD:AddDebugText(text, enemy, 0.06, {X=0,Y=0,Z=100}, {X=0,Y=0,Z=100}, tc, true, false, true, nil, sc, true)
                                    end
                                end
                            end
                        end)
                    end

                    -- HP bar + name + reload tag
                    if _G.LexusConfig.EspVipPro then
                        pcall(function()
                            if Valid(Cached_MyHUD) and distM <= (_G.LexusConfig.EspMaxDistance or 400) then
                                local sc = math.max(0.55, 0.95 - (distM / 400))
                                local showName = eName
                                if isKnock and _G.LexusConfig.EspShowKnocked then showName = "KNOCK "..showName end
                                if isBot and _G.LexusConfig.EspShowBotTag then showName = "[BOT] "..showName end
                                local hpC = C_GREEN
                                if hpR < 0.3 then hpC = C_RED
                                elseif hpR < 0.7 then hpC = C_YELLOW end
                                if isKnock then hpC = C_RED end
                                local nameC = C_WHITE
                                if _G.LexusConfig.EspNameColor == 2 then nameC = isBot and C_CYAN or C_YELLOW
                                elseif _G.LexusConfig.EspNameColor == 3 then nameC = hpC end
                                if _G.LexusConfig.EspShowName then
                                    Cached_MyHUD:AddDebugText(showName, enemy, 0.06, {X=0,Y=0,Z=-370}, {X=0,Y=0,Z=-370}, nameC, true, false, true, nil, sc*1.1, true)
                                end
                                -- 2D box via 4 corner chars
                                if _G.LexusConfig.EspBox2D then
                                    Cached_MyHUD:AddDebugText("┌", enemy, 0.06, {X=0,Y=-60,Z=180}, {X=0,Y=-60,Z=180}, hpC, true, false, true, nil, sc*1.0, true)
                                    Cached_MyHUD:AddDebugText("┐", enemy, 0.06, {X=0,Y=60,Z=180}, {X=0,Y=60,Z=180}, hpC, true, false, true, nil, sc*1.0, true)
                                    Cached_MyHUD:AddDebugText("└", enemy, 0.06, {X=0,Y=-60,Z=-180}, {X=0,Y=-60,Z=-180}, hpC, true, false, true, nil, sc*1.0, true)
                                    Cached_MyHUD:AddDebugText("┘", enemy, 0.06, {X=0,Y=60,Z=-180}, {X=0,Y=60,Z=-180}, hpC, true, false, true, nil, sc*1.0, true)
                                end
                                if _G.LexusConfig.EspBoxCorner then
                                    Cached_MyHUD:AddDebugText("╔", enemy, 0.06, {X=0,Y=-55,Z=175}, {X=0,Y=-55,Z=175}, hpC, true, false, true, nil, sc*0.9, true)
                                    Cached_MyHUD:AddDebugText("╗", enemy, 0.06, {X=0,Y=55,Z=175}, {X=0,Y=55,Z=175}, hpC, true, false, true, nil, sc*0.9, true)
                                    Cached_MyHUD:AddDebugText("╚", enemy, 0.06, {X=0,Y=-55,Z=-175}, {X=0,Y=-55,Z=-175}, hpC, true, false, true, nil, sc*0.9, true)
                                    Cached_MyHUD:AddDebugText("╝", enemy, 0.06, {X=0,Y=55,Z=-175}, {X=0,Y=55,Z=-175}, hpC, true, false, true, nil, sc*0.9, true)
                                end
                                -- HP bar vertical
                                if _G.LexusConfig.EspHpBarVert and not isKnock then
                                    local segs = 6
                                    local fill = math.floor(hpR * segs)
                                    for j = 1, segs do
                                        local z = 40 - ((j-1) * 12)
                                        local c = (j <= fill) and hpC or {R=30,G=30,B=30,A=180}
                                        Cached_MyHUD:AddDebugText("▌", enemy, 0.06, {X=0,Y=-140,Z=z}, {X=0,Y=-140,Z=z}, c, true, false, true, nil, sc*0.9, true)
                                    end
                                elseif _G.LexusConfig.EspHpBarVert and isKnock then
                                    Cached_MyHUD:AddDebugText("DOWN", enemy, 0.06, {X=0,Y=-140,Z=40}, {X=0,Y=-140,Z=40}, C_RED, true, false, true, nil, sc, true)
                                end
                                if _G.LexusConfig.EspArmorBar then
                                    local arm = 0
                                    pcall(function() arm = enemy.Armor or 0 end)
                                    if arm > 0 then
                                        local armR = math.min(1.0, arm / 100.0)
                                        Cached_MyHUD:AddDebugText("▌▌▌", enemy, 0.06, {X=0,Y=-160,Z=20}, {X=0,Y=-160,Z=20}, {R=0,G=120,B=255,A=255}, true, false, true, nil, sc*0.8*(0.3+armR), true)
                                    end
                                end
                                if _G.LexusConfig.EspReloadTag then
                                    local reloading = false
                                    pcall(function()
                                        local w = enemy.CurrentWeapon
                                        if not w and type(enemy.GetCurrentWeapon) == "function" then w = enemy:GetCurrentWeapon() end
                                        if Valid(w) and (w.bIsReloading or w.bReloading) then reloading = true end
                                    end)
                                    if reloading then
                                        Cached_MyHUD:AddDebugText("RELOADING", enemy, 0.06, {X=0,Y=0,Z=-250}, {X=0,Y=0,Z=-250}, C_ORANGE, true, false, true, nil, sc*0.85, true)
                                    end
                                end
                                if _G.LexusConfig.EspAimArrow and not isKnock then
                                    local yaw = 0
                                    pcall(function()
                                        local r = enemy:GetActorRotation()
                                        if r then yaw = r.Yaw end
                                    end)
                                    local arrow = "▲"
                                    if yaw >= -45 and yaw < 45 then arrow = "▶"
                                    elseif yaw >= 45 and yaw < 135 then arrow = "▼"
                                    elseif yaw >= 135 or yaw < -135 then arrow = "◀" end
                                    Cached_MyHUD:AddDebugText(arrow, enemy, 0.06, {X=0,Y=0,Z=-300}, {X=0,Y=0,Z=-300}, C_ORANGE, true, false, true, nil, sc, true)
                                end
                            end
                        end)
                    end

                    -- Distance
                    if _G.LexusConfig.EspDistance then
                        pcall(function()
                            if Valid(Cached_MyHUD) and distM <= (_G.LexusConfig.EspMaxDistance or 400) then
                                local sc = math.max(0.55, 0.95 - (distM / 400))
                                local d = string.format("[%dm]", math.floor(distM))
                                if _G.LexusConfig.EspDistanceUnit == 2 then d = string.format("[%dft]", math.floor(distM * 3.28)) end
                                Cached_MyHUD:AddDebugText(d, enemy, 0.06, {X=0,Y=115,Z=20}, {X=0,Y=115,Z=20}, C_BLUE_TEXT, true, false, true, nil, sc*1.5, true)
                            end
                        end)
                    end

                    if _G.LexusConfig.EspVip then
                        if md.hpMark == nil then md.hpMark = SafeAddMark(1006, FVector(0,0,0), 0, "", 4, enemy) end
                        if md.distMark == nil then md.distMark = SafeAddMark(9999, FVector(0,0,0), 0, "", 4, enemy) end
                    else
                        if md.hpMark then SafeRemoveMark(md.hpMark); md.hpMark = nil end
                        if md.distMark then SafeRemoveMark(md.distMark); md.distMark = nil end
                    end

                    if _G.LexusConfig.EspRadar then
                        pcall(function()
                            local ct = os.clock()
                            md.LastRadarUpdate = md.LastRadarUpdate or 0
                            if ct > md.LastRadarUpdate + 0.5 then
                                local hLoc = nil
                                if type(enemy.GetHeadLocation) == "function" then hLoc = enemy:GetHeadLocation(false) end
                                if hLoc then
                                    local T = require("GameLua.Mod.BaseMod.Common.InGameMarkTools")
                                    if md.radarMark and T and T.HideMapMark then T.HideMapMark(md.radarMark) end
                                    if T and T.ClientAddMapMark then md.radarMark = T.ClientAddMapMark(1003, hLoc, 0, "", 4, nil) end
                                    md.LastRadarUpdate = ct
                                end
                            end
                        end)
                    else
                        if md.radarMark then SafeRemoveMark(md.radarMark); md.radarMark = nil end
                    end

                    if _G.LexusConfig.EspOutline then
                        pcall(function()
                            local aC = (type(enemy.getAvatarComponent2) == "function") and enemy:getAvatarComponent2() or nil
                            if Valid(aC) and Valid(Cached_PPM) then
                                Cached_PPM.OutlineThickness = _G.LexusConfig.OutlineThickness
                                if Cached_PPM.OutlineColor then Cached_PPM.OutlineColor = {r=1,g=0,b=0,a=1} end
                                Cached_PPM:EnableAvatarOutline(aC, true)
                            end
                        end)
                    else
                        pcall(function()
                            local aC = (type(enemy.getAvatarComponent2) == "function") and enemy:getAvatarComponent2() or nil
                            if Valid(aC) and Valid(Cached_PPM) then Cached_PPM:EnableAvatarOutline(aC, false) end
                        end)
                    end

                    -- TOP HUD per-enemy plate
                    if _G.LexusConfig.TopHUDEnemyPlate or _G.LexusConfig.TopHUDProfile or _G.LexusConfig.TopHUDUID or _G.LexusConfig.TopHUDStats then
                        DrawEnemyPlate(Cached_MyHUD, enemy, distM, isBot, hpR, isKnock, eName)
                    end

                    -- Last seen ghost (draws while alive, keeps position after death)
                    if _G.LexusConfig.EspLastSeen then
                        pcall(function()
                            if Valid(aLoc) then
                                md.LastSeenLoc = {X=aLoc.X, Y=aLoc.Y, Z=aLoc.Z}
                                md.LastSeenTime = os.clock()
                            end
                        end)
                    end

                else
                    -- Enemy dead
                    if not md.IsCleanedUp then
                        SafeRemoveMark(md.radarMark); md.radarMark = nil
                        SafeRemoveMark(md.hpMark); md.hpMark = nil
                        SafeRemoveMark(md.distMark); md.distMark = nil
                        md.IsCleanedUp = true
                    end
                    -- Last seen ghost
                    if _G.LexusConfig.EspLastSeen and md.LastSeenLoc and Valid(Cached_MyHUD) and Valid(md.enemy) then
                        local ghost = { X = md.LastSeenLoc.X, Y = md.LastSeenLoc.Y, Z = md.LastSeenLoc.Z + 150 }
                        Cached_MyHUD:AddDebugText("▢ LAST SEEN", md.enemy, 0.06, ghost, ghost, C_GRAY, true, false, true, nil, 0.8, true)
                    end
                end
            end
        end

        if _G.LexusConfig.EnemyCountHUD and Valid(Cached_MyHUD) then
            Cached_MyHUD:AddDebugText(string.format("Real:%d Bot:%d Total:%d", realCount, aiCount, realCount + aiCount), localPlayer, 0.06, {X=0,Y=0,Z=0}, {X=0,Y=0,Z=0}, C_RED, true, false, true, nil, 0.8, true)
        end
    end)

    LostTombFeaturesLoop()
end

_G.LexusState.LoopToken = (_G.LexusState.LoopToken or 0) + 1
local myToken = _G.LexusState.LoopToken

local function FastTick()
    if myToken ~= _G.LexusState.LoopToken then return end
    pcall(MainLoop)
    local ok, t = pcall(require, "common.time_ticker")
    if ok and t and t.AddTimerOnce then t.AddTimerOnce(0.01, FastTick) end
end

FastTick()
Notify("VIP MOD v6 LOADED — @FLUXMOD10")

local function InitAllModSystems()
    pcall(function()
        if _G.StartBypass_VIP_v5 then _G.StartBypass_VIP_v5() end
        if _G.InitializeAutoHeadHooks then _G.InitializeAutoHeadHooks() end
    end)
end
pcall(function() require("common.time_ticker").AddTimerOnce(0.5, InitAllModSystems) end)

function _G.InitializeSkinModSystem()
    pcall(function()
        local LA = package.loaded["client.logic.avatar.LobbyAvatar"] or require("client.logic.avatar.LobbyAvatar")
        if LA and not _G.LobbyBypassHacked then
            local orig = LA.PutonEquipment
            LA.PutonEquipment = function(self, itemID, tC, tE)
                local idx = _G.BaseAttachToIndex and _G.BaseAttachToIndex[itemID]
                if idx then
                    local hID = self.GetCurHoldingWeaponSkinID and self:GetCurHoldingWeaponSkinID()
                    if hID and hID >= 10000000 and _G.VIP_Attachments and _G.VIP_Attachments[hID] then
                        local v = _G.VIP_Attachments[hID][idx]
                        if v and v > 0 then
                            if self.HandleDownload then self:HandleDownload(v, nil, nil, false) end
                            itemID = v
                        end
                    end
                end
                if orig then return orig(self, itemID, tC, tE) end
            end
            _G.LobbyBypassHacked = true
        end
    end)
end

-- ============================================================================
-- CLASS REGISTRATION
-- ============================================================================
local class = require("class")
local CCharacterBase = require("GameLua.GameCore.Framework.CharacterBase")
local CBRPlayerCharacterBase = class(CCharacterBase, nil, BRPlayerCharacterBase)
return require("combine_class").DeclareFeature(CBRPlayerCharacterBase, {
  { SkyTransition = "GameLua.Mod.BaseMod.Gameplay.Feature.SkyControl.PlayerCharacterSkyTransitionFeature" },
  { CarryDeadBoxFeature = "GameLua.Mod.Library.GamePlay.Feature.CarryDeadBoxFeature" },
  { SpecialSuitFeature = "GameLua.Mod.Library.GamePlay.Feature.SpecialSuitFeature" },
  { TeleportPawnFeature = "GameLua.Mod.Library.GamePlay.Feature.TeleportPawnFeature" },
  { LifterControl = "GameLua.Mod.BaseMod.Gameplay.Feature.Player.CharacterLifterControlFeature" },
  { FinalKillEffect = "GameLua.Mod.BaseMod.Gameplay.Feature.Player.PlayerCharacterFinalKillEffectFeature" },
  { CampFeature = "GameLua.Mod.BaseMod.GamePlay.Feature.Camp.PlayerCharacterCampFeature" },
  { BuildAircraftVehicleFeature = "GameLua.Mod.BaseMod.GamePlay.Feature.PlayerCharacterBuildVehicleFeature" },
  { UnifiedBuildVehicleFeature = "GameLua.Mod.BaseMod.GamePlay.Feature.UnifiedBuildVehicleFeature" },
  { CommonBornlandTransformFeature = "GameLua.Mod.BaseMod.GamePlay.Feature.HeroPropFeature.CommonBornlandTransformFeature" },
  { ParachuteFormation = "GameLua.Mod.BaseMod.GamePlay.Feature.ParachuteFormationFeature" },
  { ParachuteSprint = "GameLua.Mod.BaseMod.GamePlay.Feature.Parachute.ParachuteSprintFeature" },
  { GeneralShowSpotFeature = "GameLua.Mod.BRMod.Gameplay.Feature.PlayerCharacterGeneralShowSpotFeature" },
  { FPPAnimMonitor = "GameLua.Mod.BaseMod.GamePlay.Feature.Player.FPPAnimMonitorFeature" }
}, "BRPlayerCharacterBase")