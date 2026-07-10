from __future__ import annotations

import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
WORLD_BUILDER = ROOT / "src" / "ServerScriptService" / "SimpleWorldBuilder.lua"
GAME_SERVER = ROOT / "src" / "ServerScriptService" / "GameServer.server.lua"
DATA_MANAGER = ROOT / "src" / "ServerScriptService" / "DataManager.lua"
LOADING_CONTROLLER = ROOT / "src" / "StarterPlayer" / "StarterPlayerScripts" / "LoadingController.lua"


class CheckFailure:
    def __init__(self, name: str, reason: str, file_path: Path) -> None:
        self.name = name
        self.reason = reason
        self.file_path = file_path


failures: list[CheckFailure] = []


def fail(name: str, reason: str, file_path: Path = WORLD_BUILDER) -> None:
    failures.append(CheckFailure(name, reason, file_path))


def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except FileNotFoundError:
        fail("Missing file", "Required source file was not found.", path)
        return ""


def require_contains(name: str, text: str, needles: list[str], file_path: Path = WORLD_BUILDER) -> None:
    missing = [needle for needle in needles if needle not in text]
    if missing:
        fail(name, "Missing required text: " + ", ".join(missing), file_path)


def require_regex(name: str, text: str, pattern: str, reason: str, file_path: Path = WORLD_BUILDER) -> None:
    if not re.search(pattern, text, re.MULTILINE | re.DOTALL):
        fail(name, reason, file_path)


def check_lobby_root_and_folders(builder: str) -> None:
    require_contains(
        "Prestige 0 lobby root",
        builder,
        [
            'local MAP_NAME = "SimpleMap"',
            'local LOBBY_NAME = "Lobby_Prestige0_School"',
            'folder(map, "World")',
            "folder(world, LOBBY_NAME)",
            'map:SetAttribute("Theme", "Prestige0SchoolLobby")',
        ],
    )

    for folder_name in [
        "Ground",
        "SpawnArea",
        "RollArea",
        "GateArea",
        "QuestArea",
        "ChestArea",
        "ResearchArea",
        "RankingArea",
        "ShopArea",
        "AttendanceArea",
        "Paths",
        "Decorations",
        "InteractionZones",
        "Debug",
    ]:
        require_contains("Lobby folder " + folder_name, builder, [f'"{folder_name}"'])


def check_required_geometry(builder: str) -> None:
    require_contains(
        "Main campus geometry",
        builder,
        [
            '"P0_MainGround", Vector3.new(190, 2, 190), Vector3.new(0, -1, 0)',
            '"P0_CampusBase", Vector3.new(150, 0.3, 150), Vector3.new(0, 0.15, 0)',
            '"P0_SpawnPlatform", Vector3.new(38, 1.5, 20), Vector3.new(0, 0.75, -76)',
            'spawn.Position = Vector3.new(0, 2, -76)',
            '"P0_RollPlaza_Base", Vector3.new(42, 1.6, 42), Vector3.new(0, 0.8, 0)',
            '"P0_GatePlatform", Vector3.new(46, 1.6, 28), Vector3.new(0, 0.8, 68)',
            '"P0_QuestBase", Vector3.new(36, 1.6, 30), Vector3.new(-62, 0.8, 2)',
            '"P0_ChestBase", Vector3.new(38, 1.6, 30), Vector3.new(62, 0.8, 2)',
            '"P0_ResearchBase", Vector3.new(48, 1.4, 22), Vector3.new(0, 0.7, -52)',
            '"P0_RankingBase", Vector3.new(34, 1.2, 18), Vector3.new(-65, 0.6, -50)',
            '"P0_ShopBase", Vector3.new(28, 1.2, 18), Vector3.new(65, 0.6, -50)',
            '"P0_AttendanceBase", Vector3.new(16, 1, 12), Vector3.new(25, 0.5, -68)',
        ],
    )


def check_functional_names(builder: str, game_server: str) -> None:
    require_contains(
        "Functional world names preserved",
        builder,
        [
            '"RollButton"',
            '"WorldChestStation"',
            '"WorldChestModel"',
            '"ChestPromptPart"',
            '"ChestOpenPrompt"',
            '"ChestStatusBillboard"',
            '"ChestReadyIcon"',
            '"ProfessorBrain_Body"',
            '"QuestOpenPrompt"',
            '"QuestStatusBillboard"',
            '"QuestReadyIcon"',
            '"NextAreaGate"',
            '"NextAreaGate_Door"',
            '"NextAreaPrompt"',
            '"NextAreaGateBillboard"',
            '"NextAreaGateTitle"',
            '"NextAreaGateSubtitle"',
            '"NextAreaLockIcon"',
            '"Area2PreviewZone"',
            '"Area2ArrivalPad"',
            '"Area2ReturnPromptPart"',
            '"Area2ReturnPrompt"',
            '"PlayerSpawn"',
            '"SpawnLocation"',
            '"WinPad_Plaza"',
            'tag(pad, "WinPad")',
        ],
    )

    require_contains(
        "Existing server lookup names",
        game_server,
        [
            'Workspace:FindFirstChild("SimpleMap")',
            'simpleMap:FindFirstChild("WorldChestStation")',
            'simpleMap:FindFirstChild("Area2ArrivalPad", true)',
            'simpleMap:FindFirstChild("PlayerSpawn", true)',
        ],
        GAME_SERVER,
    )


def check_visual_policy(builder: str) -> None:
    require_contains(
        "School visual labels",
        builder,
        [
            '"BRAIN RNG SCHOOL"',
            '"ROLL IQ"',
            '"TAP TO GROW"',
            '"QUESTS\\nHOMEWORK BOARD',
            '"KNOWLEDGE CHESTS\\nBASIC OPEN',
            '"RESEARCH\\nCONCEPT INDEX',
            '"TOP GENIUSES',
            '"SCHOOL SHOP\\nBOOSTS',
            '"DAILY ATTENDANCE\\nCOMING SOON"',
            '"ELEMENTARY SCHOOL"',
            '"REQUIRED IQ 80.500"',
        ],
    )

    forbidden = [
        "Simple simulator lobby greybox created",
        '"LobbyGrass"',
        '"SimulatorLobby"',
        '"LegacyZone2"',
        '"LegacyZone3"',
        '"ZONE 2 ARCHIVE"',
        '"ZONE 3 ARCHIVE"',
    ]
    found = [needle for needle in forbidden if needle in builder]
    if found:
        fail("Greybox removed", "Old greybox/legacy map strings remain: " + ", ".join(found))


def check_lighting_and_performance(builder: str) -> None:
    require_contains(
        "Lighting values",
        builder,
        [
            "Lighting.ClockTime = 14",
            "Lighting.Brightness = 2.2",
            "Lighting.GlobalShadows = true",
            "Lighting.ShadowSoftness = 0.35",
            "Lighting.Ambient = Color3.fromRGB(120, 125, 135)",
            "Lighting.OutdoorAmbient = Color3.fromRGB(150, 155, 165)",
            "Lighting.EnvironmentDiffuseScale = 0.35",
            "Lighting.EnvironmentSpecularScale = 0.25",
            "atmosphere.Density = 0.18",
            "bloom.Intensity = 0.08",
        ],
    )

    created_parts = len(re.findall(r"\bpart\(", builder))
    if created_parts > 350:
        fail("Part budget", f"Static part creation calls should be <= 350, found {created_parts}.")

    if "while true" in builder or "Heartbeat" in builder:
        fail("No map loops", "Lobby builder should not add Heartbeat or while true decoration loops.")


def check_existing_systems(data_manager: str, loading_controller: str, game_server: str) -> None:
    require_regex(
        "DATA_VERSION unchanged",
        data_manager,
        r"local\s+DATA_VERSION\s*=\s*3\b",
        "DataManager.lua must keep DATA_VERSION = 3.",
        DATA_MANAGER,
    )
    require_contains(
        "LoadingController retained",
        loading_controller,
        ["function LoadingController.Start(config)", "BrainRNG_LoadingGui", "DataReady"],
        LOADING_CONTROLLER,
    )
    require_contains(
        "DirtySave retained",
        game_server,
        ["local dirtySaveStates = {}", "DirtyRevision", "trySaveDirtyPlayer", "releaseProfileWithDirtyGuard"],
        GAME_SERVER,
    )


def main() -> int:
    builder = read_text(WORLD_BUILDER)
    game_server = read_text(GAME_SERVER)
    data_manager = read_text(DATA_MANAGER)
    loading_controller = read_text(LOADING_CONTROLLER)

    check_lobby_root_and_folders(builder)
    check_required_geometry(builder)
    check_functional_names(builder, game_server)
    check_visual_policy(builder)
    check_lighting_and_performance(builder)
    check_existing_systems(data_manager, loading_controller, game_server)

    if failures:
        for failure in failures:
            print(f"[FAIL] {failure.name}")
            print(f"- {failure.reason}")
            print(f"- Check file: {failure.file_path}")
        return 1

    print("[PASS] Lobby map headless tests passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
