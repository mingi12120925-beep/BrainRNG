from __future__ import annotations

import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
GAME_SERVER = ROOT / "src" / "ServerScriptService" / "GameServer.server.lua"
UI_CONTROLLER = ROOT / "src" / "StarterPlayer" / "StarterPlayerScripts" / "UIController.client.lua"
LOADING_CONTROLLER = ROOT / "src" / "StarterPlayer" / "StarterPlayerScripts" / "LoadingController.lua"
DATA_MANAGER = ROOT / "src" / "ServerScriptService" / "DataManager.lua"


class CheckFailure:
    def __init__(self, name: str, reason: str, file_path: Path) -> None:
        self.name = name
        self.reason = reason
        self.file_path = file_path


failures: list[CheckFailure] = []


def fail(name: str, reason: str, file_path: Path) -> None:
    failures.append(CheckFailure(name, reason, file_path))


def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except FileNotFoundError:
        fail("Missing file", "Required source file was not found.", path)
        return ""


def require_contains(name: str, text: str, needles: list[str], file_path: Path) -> None:
    missing = [needle for needle in needles if needle not in text]
    if missing:
        fail(name, "Missing required text: " + ", ".join(missing), file_path)


def require_regex(name: str, text: str, pattern: str, reason: str, file_path: Path) -> None:
    if not re.search(pattern, text, re.MULTILINE | re.DOTALL):
        fail(name, reason, file_path)


def get_function_body(text: str, function_name: str) -> str:
    pattern = re.compile(r"(?:local\s+function|function)\s+" + re.escape(function_name) + r"\s*\([^)]*\)")
    match = pattern.search(text)
    if not match:
        return ""

    start = match.end()
    next_match = re.search(r"\n(?:local\s+function|function\s+)", text[start:])
    if next_match:
        return text[start : start + next_match.start()]

    return text[start:]


def count_top_level_local_declarations(text: str) -> int:
    count = 0
    depth = 0
    token_pattern = re.compile(r"\b(function|if|for|while|repeat|do|end|until)\b")

    for raw_line in text.splitlines():
        line = raw_line.strip()
        if not line or line.startswith("--"):
            continue

        if re.match(r"local\s+(?:function\s+)?[A-Za-z_]", line) and depth == 0:
            count += 1

        for token in token_pattern.findall(line):
            if token in {"function", "if", "for", "while", "repeat", "do"}:
                depth += 1
            elif token in {"end", "until"}:
                depth = max(0, depth - 1)

    return count


def check_server_ready_signal(game_server: str) -> None:
    require_contains(
        "PlayerDataReady RemoteEvent",
        game_server,
        [
            "local PlayerDataReady = getOrCreateRemoteEvent(\"PlayerDataReady\")",
            "player:SetAttribute(\"DataReady\", false)",
            "player:SetAttribute(\"DataReady\", true)",
            "PlayerDataReady:FireClient(player)",
            "[Loading] PlayerDataReady sent player=",
        ],
        GAME_SERVER,
    )

    body = get_function_body(game_server, "handlePlayerAdded")
    if not body:
        fail("handlePlayerAdded", "Could not find handlePlayerAdded().", GAME_SERVER)
        return

    setup_index = body.find("GameLogic.SetupPlayer(player)")
    load_index = body.find("local loaded = DataManager.LoadProfile(player)")
    update_index = body.find("updateAllStats(player)")
    ready_attribute_index = body.find("player:SetAttribute(\"DataReady\", true)")
    ready_index = body.find("PlayerDataReady:FireClient(player)")
    kick_index = body.find("player:Kick(loadError)")
    false_attribute_index = body.find("player:SetAttribute(\"DataReady\", false)")

    if min(setup_index, load_index, update_index, ready_attribute_index, ready_index, kick_index, false_attribute_index) == -1:
        fail("PlayerDataReady order", "Missing expected load/update/ready statements.", GAME_SERVER)
        return

    if not (false_attribute_index < setup_index < load_index < update_index < ready_attribute_index < ready_index):
        fail(
            "PlayerDataReady order",
            "DataReady false, SetupPlayer, LoadProfile, updateAllStats, DataReady true, and FireClient must run in order.",
            GAME_SERVER,
        )

    if not (load_index < kick_index < update_index):
        fail("PlayerDataReady failure path", "LoadProfile failure must kick and return before PlayerDataReady.", GAME_SERVER)


def check_loading_module(ui_controller: str, loading_controller: str) -> None:
    require_contains(
        "Loading constants",
        loading_controller,
        [
            "local MIN_LOADING_TIME = 1.2",
            "local MAX_LOADING_TIME = 12",
            "local FADE_OUT_TIME = 0.35",
        ],
        LOADING_CONTROLLER,
    )

    require_contains(
        "LoadingController module",
        loading_controller,
        [
            "local LoadingController = {}",
            "function LoadingController.Start(config)",
            "return LoadingController",
        ],
        LOADING_CONTROLLER,
    )

    require_contains(
        "Loading remote connection",
        loading_controller,
        [
            "state.PlayerDataReady.OnClientEvent:Connect(function()",
            "complete(state)",
            "if state.Player:GetAttribute(\"DataReady\") == true then",
        ],
        LOADING_CONTROLLER,
    )

    require_contains(
        "UIController loading entrypoint",
        ui_controller,
        [
            "local LoadingController = require(script.Parent:WaitForChild(\"LoadingController\"))",
            "local PlayerDataReady = remotesFolder:WaitForChild(\"PlayerDataReady\")",
            "LoadingController.Start({",
            "Player = player",
            "PlayerGui = playerGui",
            "PlayerDataReady = PlayerDataReady",
            "TweenService = TweenService",
        ],
        UI_CONTROLLER,
    )

    body = get_function_body(loading_controller, "createLoadingScreen")
    if not body:
        fail("createLoadingScreen", "Could not find createLoadingScreen().", LOADING_CONTROLLER)
        return

    require_contains(
        "Loading ScreenGui shape",
        body,
        [
            "state.Gui.Name = \"BrainRNG_LoadingGui\"",
            "state.Gui.IgnoreGuiInset = true",
            "state.Gui.ResetOnSpawn = false",
            "state.Gui.DisplayOrder = 10000",
            "state.Gui.ZIndexBehavior = Enum.ZIndexBehavior.Global",
            "state.Gui.Enabled = true",
            "state.Gui.Parent = state.PlayerGui",
            "background.Name = \"LoadingBackground\"",
            "background.Size = UDim2.fromScale(1, 1)",
            "background.BackgroundColor3 = Color3.fromRGB(12, 17, 30)",
            "state.Title.Name = \"GameTitle\"",
            "state.Title.Text = \"BRAIN RNG\"",
            "subtitle.Text = \"ROLL. LEARN. EVOLVE.\"",
            "progressBackground.Name = \"ProgressBarBackground\"",
            "progressSizeConstraint.MinSize = Vector2.new(230, 10)",
            "progressSizeConstraint.MaxSize = Vector2.new(520, 20)",
            "state.ProgressFill.Name = \"ProgressFill\"",
            "state.ProgressFill.Size = UDim2.fromScale(0.06, 1)",
            "state.StatusLabel.Name = \"LoadingStatus\"",
            "[Loading] Screen shown",
        ],
        LOADING_CONTROLLER,
    )

    require_contains(
        "Loading progress and delay states",
        loading_controller,
        [
            "{ Delay = 0, Progress = 0.06 }",
            "{ Delay = 0.5, Progress = 0.22 }",
            "{ Delay = 1.5, Progress = 0.48 }",
            "{ Delay = 3, Progress = 0.72 }",
            "{ Delay = MAX_LOADING_TIME, Progress = 0.88 }",
            "\"Still loading...\"",
            "\"Please wait a moment.\"",
            "\"Loading is taking longer than expected.\"",
        ],
        LOADING_CONTROLLER,
    )


def check_loading_finish_requires_ready_signal(ui_controller: str, loading_controller: str) -> None:
    complete_body = get_function_body(loading_controller, "complete")
    fade_body = get_function_body(loading_controller, "fadeOut")

    if not complete_body:
        fail("complete", "Could not find complete().", LOADING_CONTROLLER)
    else:
        require_contains(
            "Ready signal completion",
            complete_body,
            [
                "state.ReadyReceived = true",
                "[Loading] PlayerDataReady received",
                "state.StatusLabel.Text = \"Ready!\"",
                "tweenProgress(state, 1, 0.18)",
                "if elapsed < MIN_LOADING_TIME then",
                "task.wait(MIN_LOADING_TIME - elapsed)",
                "task.wait(0.15)",
                "fadeOut(state)",
            ],
            LOADING_CONTROLLER,
        )

    if not fade_body:
        fail("fadeOut", "Could not find fadeOut().", LOADING_CONTROLLER)
    else:
        require_contains(
            "Loading fade destroy",
            fade_body,
            [
                "state.Finished = true",
                "state.Gui:Destroy()",
                "[Loading] Fade out complete",
            ],
            LOADING_CONTROLLER,
        )

    remotes_index = ui_controller.find("local remotesFolder = ReplicatedStorage:WaitForChild(\"Remotes\")")
    player_data_ready_index = ui_controller.find("local PlayerDataReady = remotesFolder:WaitForChild(\"PlayerDataReady\")")
    loading_start_index = ui_controller.find("LoadingController.Start({")
    general_remote_indices = [
        ui_controller.find("local RollRequest = remotesFolder:WaitForChild(\"RollRequest\")"),
        ui_controller.find("local UpgradeRequest = remotesFolder:WaitForChild(\"UpgradeRequest\")"),
        ui_controller.find("local UpdateStats = remotesFolder:WaitForChild(\"UpdateStats\")"),
        ui_controller.find("local PopupEvent = remotesFolder:WaitForChild(\"PopupEvent\")"),
    ]

    if -1 in [remotes_index, player_data_ready_index, loading_start_index] or any(index == -1 for index in general_remote_indices):
        fail("PlayerDataReady early hookup", "Missing PlayerDataReady early module start or general remote waits.", UI_CONTROLLER)
        return

    first_general_remote_index = min(general_remote_indices)
    if not (remotes_index < player_data_ready_index < loading_start_index < first_general_remote_index):
        fail(
            "PlayerDataReady early hookup",
            "LoadingController.Start must receive PlayerDataReady before general RemoteEvent WaitForChild calls.",
            UI_CONTROLLER,
        )

    forbidden_ui_loading_locals = [
        "local MIN_LOADING_TIME",
        "local MAX_LOADING_TIME",
        "local FADE_OUT_TIME",
        "local loadingStartedAt",
        "local loadingReadyReceived",
        "local loadingFinished",
        "local loadingGui",
        "local loadingProgressFill",
        "local loadingStatusLabel",
        "local loadingTitle",
        "local loadingGlowLeft",
        "local loadingGlowRight",
        "local function addLoadingCorner",
        "local function addLoadingTextConstraint",
        "local function tweenLoadingProgress",
        "local function createLoadingScreen",
        "local function fadeOutLoadingScreen",
        "local function completeLoadingScreen",
    ]
    leaked = [needle for needle in forbidden_ui_loading_locals if needle in ui_controller]
    if leaked:
        fail("UIController loading locals removed", "Loading locals still present in UIController: " + ", ".join(leaked), UI_CONTROLLER)


def check_ui_controller_local_budget(ui_controller: str) -> None:
    count = count_top_level_local_declarations(ui_controller)
    if count > 180:
        fail("UIController local budget", f"Top-level local declarations should be <= 180, found {count}.", UI_CONTROLLER)


def check_data_version(data_manager: str) -> None:
    require_regex(
        "DATA_VERSION unchanged",
        data_manager,
        r"local\s+DATA_VERSION\s*=\s*3\b",
        "DataManager.lua must keep DATA_VERSION = 3.",
        DATA_MANAGER,
    )


def main() -> int:
    game_server = read_text(GAME_SERVER)
    ui_controller = read_text(UI_CONTROLLER)
    loading_controller = read_text(LOADING_CONTROLLER)
    data_manager = read_text(DATA_MANAGER)

    check_server_ready_signal(game_server)
    check_loading_module(ui_controller, loading_controller)
    check_loading_finish_requires_ready_signal(ui_controller, loading_controller)
    check_ui_controller_local_budget(ui_controller)
    check_data_version(data_manager)

    if failures:
        for failure in failures:
            print(f"[FAIL] {failure.name}")
            print(f"- {failure.reason}")
            print(f"- Check file: {failure.file_path}")
        return 1

    print("[PASS] Loading screen headless tests passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
