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
            'map:SetAttribute("MapStyle", "ClassicSimulator")',
            'map:SetAttribute("LayoutVersion", 5)',
            'map:SetAttribute("WorldScale", WORLD_SCALE)',
            'map:SetAttribute("InteractionDistance", PROMPT_DISTANCE)',
            'map:SetAttribute("GroundStyle", "ExtendedLandscape")',
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
        "Boundary",
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
            "local WORLD_SCALE = 2.5",
            "local PROMPT_DISTANCE = 18",
            '"P0_WorldTerrainMass", Vector3.new(380, 20, 400), Vector3.new(0, -11, 0)',
            '"P0_GrassField_Core", Vector3.new(374, 1.6, 394), Vector3.new(0, -0.8, 0)',
            '"P0_OuterLand_West", Vector3.new(58, 4, 250), Vector3.new(-128, 0.6, 8)',
            '"P0_OuterLand_North", Vector3.new(246, 5.5, 72), Vector3.new(0, 1, 127)',
            '"P0_DistantLandscape_"',
            '"P0_MainPath", Vector3.new(18, 0.4, 146), Vector3.new(0, 0.2, -5)',
            '"P0_CentralPlaza", Vector3.new(0.6, 64, 64), Vector3.new(0, 0.3, -6)',
            '"P0_SpawnPlatform", Vector3.new(22, 0.6, 14), Vector3.new(0, 0.3, -78)',
            'spawn.Position = worldVector(Vector3.new(0, 2, -78))',
            '"P0_School_MainBody", Vector3.new(60, 22, 20), Vector3.new(0, 11, 79)',
            '"P0_QuestBooth_Floor", Vector3.new(24, 0.8, 18), Vector3.new(-47, 0.4, -6)',
            '"P0_ChestBooth_Floor", Vector3.new(24, 0.8, 18), Vector3.new(47, 0.4, -6)',
            '"P0_ResearchKiosk_Base", Vector3.new(22, 0.8, 14), Vector3.new(-54, 0.4, -55)',
            '"P0_RankingBase", Vector3.new(20, 0.8, 12), Vector3.new(-67, 0.4, 39)',
            '"P0_ShopBase", Vector3.new(20, 0.8, 16), Vector3.new(66, 0.4, 38)',
            '"P0_AttendanceBase", Vector3.new(18, 0.8, 12), Vector3.new(48, 0.4, -61)',
            '"P0_BoundaryNorth", Vector3.new(180, 24, 2), Vector3.new(0, 12, 90)',
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
            '"ChestReadyIcon"',
            '"ProfessorBrain_Body"',
            '"QuestOpenPrompt"',
            '"QuestReadyIcon"',
            '"NextAreaGate"',
            '"NextAreaGate_Door"',
            '"NextAreaPrompt"',
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
            "ROLL IQ",
            "TAP TO GROW",
            '"P0_RollPedestal_FixedSign"',
            '"QUESTS\\nHOMEWORK BOARD',
            '"KNOWLEDGE CHESTS\\nBASIC OPEN',
            '"RESEARCH\\nCONCEPT INDEX',
            '"TOP GENIUSES',
            '"SCHOOL SHOP\\nBOOSTS',
            '"DAILY ATTENDANCE\\nCOMING SOON"',
            '"ELEMENTARY SCHOOL"',
            '"REQUIRED IQ 80.500"',
            '"P0_GateFixedSign"',
            '"P0_Area2ReturnFixedSign"',
            '"RETURN TO LOBBY"',
            '"ClassicSimulator"',
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
        '"P0_CampusBase"',
        '"P0_RollPlaza_Base"',
        '"P0_GatePlatform"',
        '"P0_SpawnArch_Left"',
        '"P0_GateSchoolPreview"',
        '"P0_MainGround"',
        '"P0_WorldTerrainMass", Vector3.new(380, 20, 400), Vector3.new(0, -10, 0)',
    ]
    found = [needle for needle in forbidden if needle in builder]
    if found:
        fail("Greybox removed", "Old greybox/legacy map strings remain: " + ", ".join(found))

    for forbidden_billboard in [
        'Instance.new("BillboardGui")',
        "BillboardGui",
        "RollButtonBillboard",
        "QuestStatusBillboard",
        "ChestStatusBillboard",
        "NextAreaGateBillboard",
        "Area2ReturnBillboard",
    ]:
        if forbidden_billboard in builder:
            fail("Floating map UI removed", f"SimpleWorldBuilder.lua still contains {forbidden_billboard!r}.")

    require_contains(
        "Fixed SurfaceGui signs",
        builder,
        [
            'Instance.new("SurfaceGui")',
            '"P0_RollPedestal_FixedSign"',
            '"QuestBoardText"',
            '"P0_ChestSign"',
            '"NextAreaGateSurfaceGui"',
            '"P0_Area2ReturnFixedSign"',
        ],
    )

    require_contains(
        "Prompts retained",
        builder,
        [
            "item.MaxActivationDistance = PROMPT_DISTANCE",
            '"QuestOpenPrompt"',
            '"ChestOpenPrompt"',
            '"NextAreaPrompt"',
            '"Area2ReturnPrompt"',
        ],
    )


def check_lighting_and_performance(builder: str) -> None:
    require_contains(
        "Lighting values",
        builder,
        [
            "Lighting.ClockTime = 13.5",
            "Lighting.Brightness = 2.2",
            "Lighting.GlobalShadows = true",
            "Lighting.ShadowSoftness = 0.35",
            "Lighting.Ambient = Color3.fromRGB(128, 137, 150)",
            "Lighting.OutdoorAmbient = Color3.fromRGB(170, 180, 190)",
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
