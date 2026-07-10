from __future__ import annotations

import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
GAME_SERVER = ROOT / "src" / "ServerScriptService" / "GameServer.server.lua"
DATA_MANAGER = ROOT / "src" / "ServerScriptService" / "DataManager.lua"


class CheckFailure:
    def __init__(self, name: str, reason: str, file_path: Path) -> None:
        self.name = name
        self.reason = reason
        self.file_path = file_path


failures: list[CheckFailure] = []


def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except FileNotFoundError:
        fail("Missing file", "Required source file was not found.", path)
        return ""


def fail(name: str, reason: str, file_path: Path = GAME_SERVER) -> None:
    failures.append(CheckFailure(name, reason, file_path))


def require_contains(name: str, text: str, needles: list[str], file_path: Path = GAME_SERVER) -> None:
    missing = [needle for needle in needles if needle not in text]
    if missing:
        fail(name, "Missing required text: " + ", ".join(missing), file_path)


def require_regex(name: str, text: str, pattern: str, reason: str, file_path: Path = GAME_SERVER) -> None:
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


def get_player_removing_body(text: str) -> str:
    marker = "Players.PlayerRemoving:Connect(function(player)"
    start = text.find(marker)
    if start == -1:
        return ""

    end = text.find("\ntask.spawn(function()", start)
    if end == -1:
        end = len(text)
    return text[start:end]


def check_dirty_state_shape(game_server: str) -> None:
    require_regex(
        "Dirty save interval",
        game_server,
        r"local\s+DIRTY_SAVE_INTERVAL\s*=\s*45\b",
        "Dirty save interval must be 45 seconds.",
    )

    require_contains(
        "Dirty state fields",
        game_server,
        [
            "local dirtySaveStates = {}",
            "IsDirty = false",
            "DirtyReason = nil",
            "LastDirtyAt = 0",
            "LastSaveAttemptAt = 0",
            "SaveInProgress = false",
        ],
    )


def check_mark_player_dirty(game_server: str) -> None:
    body = get_function_body(game_server, "markPlayerDirty")
    if not body:
        fail("markPlayerDirty", "Could not find markPlayerDirty().")
        return

    require_contains(
        "markPlayerDirty sets dirty",
        body,
        [
            "state.IsDirty = true",
            "state.DirtyReasons[reason] = true",
            "state.DirtyReason = formatDirtyReasons(state)",
            "state.LastDirtyAt = os.clock()",
            "[DirtySave] Mark userId=",
        ],
    )


def check_save_success_and_failure(game_server: str) -> None:
    clear_body = get_function_body(game_server, "clearPlayerDirty")
    save_body = get_function_body(game_server, "trySaveDirtyPlayer")

    if not clear_body:
        fail("clearPlayerDirty", "Could not find clearPlayerDirty().")
    else:
        require_contains(
            "clearPlayerDirty clears dirty",
            clear_body,
            [
                "state.IsDirty = false",
                "state.DirtyReason = nil",
                "state.DirtyReasons = {}",
            ],
        )

    if not save_body:
        fail("trySaveDirtyPlayer", "Could not find trySaveDirtyPlayer().")
        return

    require_contains(
        "Dirty save success clears only on success",
        save_body,
        [
            "if success and savedOrError then",
            "clearPlayerDirty(player)",
            "[DirtySave] OK userId=",
        ],
    )

    require_contains(
        "Dirty save failure keeps dirty",
        save_body,
        [
            "state.IsDirty = true",
            "state.DirtyReason = reasons",
            "[DirtySave] Failed userId=",
        ],
    )


def check_duplicate_save_guard(game_server: str) -> None:
    save_body = get_function_body(game_server, "trySaveDirtyPlayer")
    release_body = get_function_body(game_server, "releaseProfileWithDirtyGuard")

    require_contains(
        "Dirty save duplicate guard",
        save_body,
        [
            "if state.SaveInProgress then",
            "return false, \"SAVE_IN_PROGRESS\"",
            "state.SaveInProgress = true",
            "state.SaveInProgress = false",
        ],
    )

    require_contains(
        "Release duplicate guard",
        release_body,
        [
            "waitForDirtySave(player, 5)",
            "state.SaveInProgress = true",
            "state.SaveInProgress = false",
        ],
    )


def check_roll_dirty_behavior(game_server: str) -> None:
    body = get_function_body(game_server, "handleRoll")
    if not body:
        fail("handleRoll", "Could not find handleRoll().")
        return

    mark_index = body.find("markPlayerDirty(player, \"RollIQ\")")
    success_index = body.find("local completedQuests, questProgressChanged = updateQuestProgressFromRoll(player, result)")
    invalid_index = body.find("if not isValidRollResult(result) then")

    if mark_index == -1:
        fail("Roll success dirty", "handleRoll does not mark RollIQ dirty.")
    elif success_index == -1 or mark_index < success_index:
        fail("Roll success dirty", "handleRoll marks dirty before roll data is successfully changed.")

    if invalid_index != -1 and mark_index != -1 and mark_index < invalid_index:
        fail("Roll rejection dirty", "handleRoll marks dirty before invalid roll rejection.")

    require_contains(
        "Roll dirty reasons",
        body,
        [
            "markPlayerDirty(player, \"RollIQ\")",
            "markPlayerDirty(player, \"ChestPointsGain\")",
            "markPlayerDirty(player, \"ConceptDiscovered\")",
            "markPlayerDirty(player, \"QuestProgress\")",
        ],
    )

    if "DataManager.SaveProfile" in body:
        fail("Roll path avoids direct save", "handleRoll must not call DataManager.SaveProfile directly.")


def check_important_event_saves(game_server: str) -> None:
    require_contains(
        "Important immediate save paths",
        game_server,
        [
            "safeSaveImportantEvent(player, \"QuestClaim\")",
            "safeSaveImportantEvent(player, \"ChestOpen\")",
            "clearPlayerDirty(player, \"LuckUpgrade\")",
            "clearPlayerDirty(player, \"AutoRollUpgrade\")",
            "clearPlayerDirty(player, \"WinPad\")",
            "return DataManager.SaveProfile(player, false",
            "return DataManager.ReleaseProfile(player)",
        ],
    )


def check_player_removing_order(game_server: str) -> None:
    body = get_player_removing_body(game_server)
    if not body:
        fail("PlayerRemoving", "Could not find Players.PlayerRemoving block.")
        return

    release_index = body.find("releaseProfileWithDirtyGuard(player, \"PlayerRemoving\")")
    quest_clear_index = body.find("playerQuestStates[userId] = nil")
    chest_clear_index = body.find("playerChestStates[userId] = nil")
    dirty_clear_index = body.find("dirtySaveStates[userId] = nil")

    if release_index == -1:
        fail("PlayerRemoving release", "PlayerRemoving must call releaseProfileWithDirtyGuard().")
        return

    early = []
    if quest_clear_index != -1 and quest_clear_index < release_index:
        early.append("playerQuestStates[userId] = nil")
    if chest_clear_index != -1 and chest_clear_index < release_index:
        early.append("playerChestStates[userId] = nil")
    if dirty_clear_index != -1 and dirty_clear_index < release_index:
        early.append("dirtySaveStates[userId] = nil")

    if early:
        fail("PlayerRemoving order", "State cleared before ReleaseProfile: " + ", ".join(early))


def check_bind_to_close(game_server: str) -> None:
    require_contains(
        "BindToClose dirty handling",
        game_server,
        [
            "local BIND_TO_CLOSE_MAX_WAIT_SECONDS = 25",
            "releaseProfileWithDirtyGuard(player, \"BindToClose\")",
            "releaseProfileWithDirtyGuard(player, \"BindToCloseRetry\")",
            "[DirtySave] BindToClose summary success=",
            "dirtySaveStates[player.UserId] = nil",
        ],
    )


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
    data_manager = read_text(DATA_MANAGER)

    check_dirty_state_shape(game_server)
    check_mark_player_dirty(game_server)
    check_save_success_and_failure(game_server)
    check_duplicate_save_guard(game_server)
    check_roll_dirty_behavior(game_server)
    check_important_event_saves(game_server)
    check_player_removing_order(game_server)
    check_bind_to_close(game_server)
    check_data_version(data_manager)

    if failures:
        for failure in failures:
            print(f"[FAIL] {failure.name}")
            print(f"- {failure.reason}")
            print(f"- 확인해야 할 파일: {failure.file_path}")
        return 1

    print("[PASS] Dirty save headless tests passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
