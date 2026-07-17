from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CONFIG = ROOT / "src/ReplicatedStorage/StudySimulatorConfig.lua"
DATA = ROOT / "src/ServerScriptService/StudySimulatorData.lua"
SERVICE = ROOT / "src/ServerScriptService/StudySimulatorService.server.lua"
STATE_SYNC = ROOT / "src/ServerScriptService/StudySimulatorStateSync.server.lua"
CLIENT = ROOT / "src/StarterPlayer/StarterPlayerScripts/StudySimulatorController.client.lua"
VISIBILITY = ROOT / "src/StarterPlayer/StarterPlayerScripts/StudyPartnerVisibility.client.lua"
MOVEMENT = ROOT / "src/ServerScriptService/PlayerProgressionInvariant.server.lua"


def read(path: Path) -> str:
    assert path.exists(), f"missing required file: {path.relative_to(ROOT)}"
    return path.read_text(encoding="utf-8")


def require(text: str, token: str, label: str) -> None:
    assert token in text, f"missing {label}: {token}"


def forbid(text: str, token: str, label: str) -> None:
    assert token not in text, f"forbidden {label}: {token}"


def main() -> int:
    config = read(CONFIG)
    data = read(DATA)
    service = read(SERVICE)
    state_sync = read(STATE_SYNC)
    client = read(CLIENT)
    visibility = read(VISIBILITY)
    movement = read(MOVEMENT)

    for token, label in [
        ("Config.BASE_DISPLAY_IQ = 80", "realistic base IQ"),
        ("Config.DIRECT_CLICKS_PER_REWARD = 3", "three-click study loop"),
        ("Config.BREAKTHROUGH_CHANCE = 0.05", "five-percent breakthrough"),
        ("Config.BREAKTHROUGH_MULTIPLIER = 3", "three-times breakthrough"),
        ("Config.PARTNER_UNLOCK_REWARDS = 10", "partner unlock threshold"),
        ("Config.PARTNER_BASE_INTERVAL = 18", "partner base interval"),
        ("Config.PARTNER_POWER_PER_POINT = 0.10", "power percentage upgrade"),
        ("Config.PARTNER_SPEED_PER_POINT = 0.10", "speed percentage upgrade"),
        ("GoalMicroIQ = 10000", "Kindergarten goal"),
        ("DirectRewardMicroIQ = 20", "Kindergarten direct reward"),
        ("GoalMicroIQ = 60000", "Elementary goal"),
        ("DirectRewardMicroIQ = 60", "Elementary direct reward"),
    ]:
        require(config, token, label)

    for obsolete in ["LEGENDARY", "MYTHIC", "SINGULARITY", "MAJOR_BREAKTHROUGH"]:
        forbid(config.upper(), obsolete, "RNG tier in simulator config")

    require(data, 'GetDataStore(Config.DATASTORE_NAME)', "separate study DataStore")
    require(data, "profile.Revision += 1", "dirty revision tracking")
    require(data, "profile.Revision == saveRevision", "save-race protection")
    require(data, "LOCK_REFRESH_SECONDS = 120", "session lock heartbeat")
    require(data, "UpdateAsync", "atomic profile snapshot write")

    require(service, "StudyClickRequest.OnServerEvent", "server-authoritative study clicks")
    require(service, "tonumber(nonce) ~= state.DistractionNonce", "nonce validation")
    require(service, "isNearStudyDesk(player)", "study distance validation")
    require(service, 'addMicroIQ(player, reward, "Partner", false)', "partner without breakthrough")
    require(service, "state.DirectActive = false", "goal/direct-study stop")
    require(service, "PartnerTrainingSeconds += dt", "time-based partner XP")
    require(service, "POWER_SPECIALIZATION_CAP", "Power specialization cap")
    require(service, "SPEED_SPECIALIZATION_CAP", "Speed specialization cap")
    require(service, 'print("[StudySimulator] Kindergarten and Elementary playable slice ready")', "playable-slice startup log")

    require(state_sync, 'StateRequest.OnServerEvent', "reliable initial state request")
    require(client, 'screenGui.Name = "BrainStudyHUD"', "new simulator HUD")
    require(client, "suppressLegacyGui()", "legacy HUD suppression")
    require(client, 'showToast("BREAKTHROUGH!"', "breakthrough feedback")
    require(client, 'string.upper(tostring(payload.To or "NEXT SCHOOL")) .. " UNLOCKED"', "graduation presentation")
    require(visibility, "LocalTransparencyModifier", "locked partner visibility")
    require(movement, "local FIXED_WALK_SPEED = 24", "fixed movement speed")

    print("Study simulator contract tests passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
