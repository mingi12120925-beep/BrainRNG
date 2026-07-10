from __future__ import annotations

import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
GAME_SERVER = ROOT / "src" / "ServerScriptService" / "GameServer.server.lua"
UI_CONTROLLER = ROOT / "src" / "StarterPlayer" / "StarterPlayerScripts" / "UIController.client.lua"
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
    pattern = re.compile(r"local function\s+" + re.escape(function_name) + r"\s*\([^)]*\)")
    match = pattern.search(text)
    if not match:
        return ""

    start = match.end()
    next_match = re.search(r"\n(?:local\s+function|function\s+)", text[start:])
    if next_match:
        return text[start : start + next_match.start()]

    return text[start:]


def check_server_ready_signal(game_server: str) -> None:
    require_contains(
        "PlayerDataReady RemoteEvent",
        game_server,
        [
            "local PlayerDataReady = getOrCreateRemoteEvent(\"PlayerDataReady\")",
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
    ready_index = body.find("PlayerDataReady:FireClient(player)")
    kick_index = body.find("player:Kick(loadError)")

    if min(setup_index, load_index, update_index, ready_index, kick_index) == -1:
        fail("PlayerDataReady order", "Missing expected load/update/ready statements.", GAME_SERVER)
        return

    if not (setup_index < load_index < update_index < ready_index):
        fail("PlayerDataReady order", "PlayerDataReady must be sent after SetupPlayer, LoadProfile, and updateAllStats.", GAME_SERVER)

    if not (load_index < kick_index < update_index):
        fail("PlayerDataReady failure path", "LoadProfile failure must kick and return before PlayerDataReady.", GAME_SERVER)


def check_loading_gui(ui_controller: str) -> None:
    require_contains(
        "Loading constants",
        ui_controller,
        [
            "local MIN_LOADING_TIME = 1.2",
            "local MAX_LOADING_TIME = 12",
            "local FADE_OUT_TIME = 0.35",
        ],
        UI_CONTROLLER,
    )

    require_contains(
        "Loading remote connection",
        ui_controller,
        [
            "local PlayerDataReady = remotesFolder:WaitForChild(\"PlayerDataReady\")",
            "PlayerDataReady.OnClientEvent:Connect(function()",
            "task.spawn(completeLoadingScreen)",
        ],
        UI_CONTROLLER,
    )

    body = get_function_body(ui_controller, "createLoadingScreen")
    if not body:
        fail("createLoadingScreen", "Could not find createLoadingScreen().", UI_CONTROLLER)
        return

    require_contains(
        "Loading ScreenGui shape",
        body,
        [
            "loadingGui.Name = \"BrainRNG_LoadingGui\"",
            "loadingGui.IgnoreGuiInset = true",
            "loadingGui.ResetOnSpawn = false",
            "loadingGui.DisplayOrder = 10000",
            "loadingGui.ZIndexBehavior = Enum.ZIndexBehavior.Global",
            "loadingGui.Enabled = true",
            "loadingGui.Parent = playerGui",
            "background.Name = \"LoadingBackground\"",
            "background.Size = UDim2.fromScale(1, 1)",
            "background.BackgroundColor3 = Color3.fromRGB(12, 17, 30)",
            "loadingTitle.Name = \"GameTitle\"",
            "loadingTitle.Text = \"BRAIN RNG\"",
            "subtitle.Text = \"ROLL. LEARN. EVOLVE.\"",
            "progressBackground.Name = \"ProgressBarBackground\"",
            "progressSizeConstraint.MinSize = Vector2.new(230, 10)",
            "progressSizeConstraint.MaxSize = Vector2.new(520, 20)",
            "loadingProgressFill.Name = \"ProgressFill\"",
            "loadingProgressFill.Size = UDim2.fromScale(0.06, 1)",
            "loadingStatusLabel.Name = \"LoadingStatus\"",
            "[Loading] Screen shown",
        ],
        UI_CONTROLLER,
    )

    require_contains(
        "Loading progress and delay states",
        body,
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
        UI_CONTROLLER,
    )


def check_loading_finish_requires_ready_signal(ui_controller: str) -> None:
    complete_body = get_function_body(ui_controller, "completeLoadingScreen")
    fade_body = get_function_body(ui_controller, "fadeOutLoadingScreen")

    if not complete_body:
        fail("completeLoadingScreen", "Could not find completeLoadingScreen().", UI_CONTROLLER)
    else:
        require_contains(
            "Ready signal completion",
            complete_body,
            [
                "loadingReadyReceived = true",
                "[Loading] PlayerDataReady received",
                "loadingStatusLabel.Text = \"Ready!\"",
                "tweenLoadingProgress(1, 0.18)",
                "if elapsed < MIN_LOADING_TIME then",
                "task.wait(MIN_LOADING_TIME - elapsed)",
                "task.wait(0.15)",
                "fadeOutLoadingScreen()",
            ],
            UI_CONTROLLER,
        )

    if not fade_body:
        fail("fadeOutLoadingScreen", "Could not find fadeOutLoadingScreen().", UI_CONTROLLER)
    else:
        require_contains(
            "Loading fade destroy",
            fade_body,
            [
                "loadingFinished = true",
                "loadingGui:Destroy()",
                "[Loading] Fade out complete",
            ],
            UI_CONTROLLER,
        )

    create_index = ui_controller.find("createLoadingScreen()")
    remotes_index = ui_controller.find("local remotesFolder = ReplicatedStorage:WaitForChild(\"Remotes\")")
    if create_index == -1 or remotes_index == -1 or create_index > remotes_index:
        fail("Immediate loading screen", "Loading screen must be created before waiting for Remotes.", UI_CONTROLLER)


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
    data_manager = read_text(DATA_MANAGER)

    check_server_ready_signal(game_server)
    check_loading_gui(ui_controller)
    check_loading_finish_requires_ready_signal(ui_controller)
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
