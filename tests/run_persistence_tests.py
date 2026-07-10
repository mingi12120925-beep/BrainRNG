from __future__ import annotations

import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DATA_MANAGER = ROOT / "src" / "ServerScriptService" / "DataManager.lua"
GAME_LOGIC = ROOT / "src" / "ServerScriptService" / "GameLogic.lua"
GAME_SERVER = ROOT / "src" / "ServerScriptService" / "GameServer.server.lua"


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
        fail(f"Missing file", "Required source file was not found.", path)
        return ""


def fail(name: str, reason: str, file_path: Path) -> None:
    failures.append(CheckFailure(name, reason, file_path))


def require_contains(name: str, text: str, needles: list[str], file_path: Path) -> None:
    missing = [needle for needle in needles if needle not in text]
    if missing:
        fail(name, "Missing required text: " + ", ".join(missing), file_path)


def require_regex(name: str, text: str, pattern: str, file_path: Path, reason: str) -> None:
    if not re.search(pattern, text, re.MULTILINE | re.DOTALL):
        fail(name, reason, file_path)


def get_lua_function_body(text: str, function_name: str) -> str:
    pattern = re.compile(r"local function\s+" + re.escape(function_name) + r"\s*\([^)]*\)")
    match = pattern.search(text)
    if not match:
        return ""

    start = match.end()
    depth = 1
    cursor = start

    token_pattern = re.compile(r"\b(function|if|for|while|repeat|do|end|until)\b")
    for token in token_pattern.finditer(text, start):
        word = token.group(1)
        if word in {"function", "if", "for", "while", "repeat", "do"}:
            depth += 1
        elif word in {"end", "until"}:
            depth -= 1
            if depth == 0:
                return text[start:token.start()]
        cursor = token.end()

    return text[start:cursor]


def get_player_removing_body(text: str) -> str:
    marker = "Players.PlayerRemoving:Connect(function(player)"
    start = text.find(marker)
    if start == -1:
        return ""

    next_section_candidates = [
        text.find("\ntask.spawn(function()", start),
        text.find("\ngame:BindToClose", start),
    ]
    next_section_candidates = [index for index in next_section_candidates if index != -1]
    end = min(next_section_candidates) if next_section_candidates else len(text)
    return text[start:end]


def check_data_version(data_manager: str) -> None:
    require_regex(
        "DATA_VERSION",
        data_manager,
        r"local\s+DATA_VERSION\s*=\s*3\b",
        DATA_MANAGER,
        "DataManager.lua must set DATA_VERSION to 3.",
    )


def check_default_data(data_manager: str) -> None:
    default_body = get_lua_function_body(data_manager, "defaultData")
    if not default_body:
        fail("DEFAULT_DATA", "Could not find defaultData().", DATA_MANAGER)
        return

    require_contains(
        "DEFAULT_DATA fields",
        default_body,
        [
            "ChestPoints = 0",
            "ChestTotalOpened = 0",
            "Quests = {",
            "Progress = {}",
            "Completed = {}",
            "Claimed = {}",
        ],
        DATA_MANAGER,
    )

    forbidden = [
        "AutoRollDelay",
        "AutoRollUpgradeCost",
        "LuckUpgradeCost",
        "IndexLevel",
        "IndexIQMultiplier",
        "IndexMilestoneBonus",
        "chestOpenDebounce",
        "adminSaveStates",
    ]
    present = [field for field in forbidden if field in default_body]
    if present:
        fail(
            "Forbidden DEFAULT_DATA fields",
            "Calculated or temporary fields found in defaultData(): " + ", ".join(present),
            DATA_MANAGER,
        )


def check_normalize_data(data_manager: str) -> None:
    normalize_body = get_lua_function_body(data_manager, "normalizeData")
    normalize_quests_body = get_lua_function_body(data_manager, "normalizeQuests")

    if not normalize_body:
        fail("normalizeData", "Could not find normalizeData().", DATA_MANAGER)
        return

    require_contains(
        "normalizeData Chest fields",
        normalize_body,
        [
            "normalized.ChestPoints",
            "readNumber(data, { \"ChestPoints\", \"CP\", { \"Chest\", \"CP\" }, { \"Chest\", \"ChestPoints\" }, { \"Chest\", \"Points\" } }",
            "normalized.ChestTotalOpened",
            "readNumber(data, { \"ChestTotalOpened\", { \"Chest\", \"TotalOpened\" }, { \"Chest\", \"ChestTotalOpened\" }, \"TotalChestsOpened\" }",
            "normalized.Quests = normalizeQuests(data.Quests)",
        ],
        DATA_MANAGER,
    )

    if not normalize_quests_body:
        fail("normalizeData Quests", "Could not find normalizeQuests().", DATA_MANAGER)
        return

    require_contains(
        "normalizeData Quest dictionaries",
        normalize_quests_body,
        [
            "source = type(source) == \"table\" and source or {}",
            "Progress = normalizeQuestDictionary(source.Progress, \"number\")",
            "Completed = normalizeQuestDictionary(source.Completed, \"boolean\")",
            "Claimed = normalizeQuestDictionary(source.Claimed, \"boolean\")",
            "normalizeLegacyQuestEntry(result, key, value)",
            "readLegacyQuestField(value, \"Id\")",
        ],
        DATA_MANAGER,
    )

    require_contains(
        "normalizeData legacy Quest helpers",
        data_manager,
        [
            "local LEGACY_QUEST_FIELDS",
            "Progress = { \"Progress\", \"progress\" }",
            "Completed = { \"Completed\", \"completed\" }",
            "Claimed = { \"Claimed\", \"claimed\" }",
            "local function normalizeLegacyQuestEntry",
            "if result.Progress[questId] == nil and progress ~= nil then",
            "if result.Completed[questId] == nil and completed ~= nil then",
            "if result.Claimed[questId] == nil and claimed ~= nil then",
            "local function hasLegacyQuestEntryProgress",
        ],
        DATA_MANAGER,
    )


def check_export_player_data(game_logic: str) -> None:
    export_body = re.search(
        r"function\s+GameLogic\.ExportPlayerData\s*\([^)]*\)(.*?)\nend",
        game_logic,
        re.DOTALL,
    )
    if not export_body:
        fail("ExportPlayerData", "Could not find GameLogic.ExportPlayerData().", GAME_LOGIC)
        return

    body = export_body.group(1)
    require_contains(
        "ExportPlayerData v3 fields",
        body,
        ["Version = 3", "exported.ChestPoints", "exported.ChestTotalOpened", "exported.Quests"],
        GAME_LOGIC,
    )


def check_import_player_data(game_logic: str, game_server: str) -> None:
    require_contains(
        "ImportPlayerData bridge",
        game_logic,
        ["sessionPersistence.ImportPlayerData(player, data)"],
        GAME_LOGIC,
    )
    require_contains(
        "GameServer import restoration",
        game_server,
        [
            "local function importChestState",
            "data and data.ChestPoints",
            "data and data.ChestTotalOpened",
            "local function importQuestState",
            "questsData.Progress",
            "questsData.Completed",
            "questsData.Claimed",
            "importChestState(player, data)",
            "importQuestState(player, data and data.Quests)",
        ],
        GAME_SERVER,
	)


def check_persistence_audit_tools(data_manager: str, game_server: str) -> None:
	require_contains(
		"DataManager persistence audit",
		data_manager,
		[
			"local persistenceAudits = {}",
			"[PersistAudit] LoadRaw",
			"[PersistAudit] Normalize",
			"[PersistAudit] SaveOK",
			"SaveFail",
			"[PersistAudit] RecoveryBeforeExport",
			"[PersistAudit] RecoveryAfterExport",
			"[PersistAudit] RecoverySavePayload",
			"[PersistAudit] RecoverySaveOK",
			"RecoverySaveFail",
			"local function buildSaveSnapshot",
			"function DataManager.GetPersistenceAuditSnapshot",
			"Kind = saveKind",
			"Payload = cloneSummary(exportedSummary)",
			"profile.Data = exportedDataForAudit",
		],
		DATA_MANAGER,
	)

	require_contains(
		"GameServer persistence audit",
		game_server,
		[
			"local function printSessionPersistenceAudit",
			"[PersistAudit] \" .. tostring(label)",
			"printSessionPersistenceAudit(player, \"ImportSession\")",
		],
		GAME_SERVER,
	)

	admin_test_commands = read_text(ROOT / "src" / "ServerScriptService" / "AdminTestCommands.server.lua")
	require_contains(
		"Admin persistence audit commands",
		admin_test_commands,
		[
			"/test_persist_audit",
			"/test_force_save",
			"persist_audit = testPersistAudit",
			"force_save = testForceSave",
			"DataManager.GetPersistenceAuditSnapshot(player)",
			"tostring(audit.LastSave.Kind or \"nil\")",
			"LastSave.Payload",
			"Reason = \"AdminTestForceSave\"",
		],
		ROOT / "src" / "ServerScriptService" / "AdminTestCommands.server.lua",
	)


def check_quest_dictionary_shape(game_server: str) -> None:
    require_contains(
        "Quest dictionary structure",
        game_server,
        [
            "local questId = questDefinition.Id",
            "state.Quests[questId]",
            "exported.Progress[questDefinition.Id]",
            "exported.Completed[questDefinition.Id]",
            "exported.Claimed[questDefinition.Id]",
            "progressData[questId]",
            "completedData[questId]",
            "claimedData[questId]",
        ],
        GAME_SERVER,
    )


def check_player_removing_order(game_server: str) -> None:
    body = get_player_removing_body(game_server)
    if not body:
        fail("PlayerRemoving order", "Could not find Players.PlayerRemoving block.", GAME_SERVER)
        return

    release_index = body.find("DataManager.ReleaseProfile(player)")
    dirty_guard_release_index = body.find("releaseProfileWithDirtyGuard(player, \"PlayerRemoving\")")
    if release_index == -1 or (dirty_guard_release_index != -1 and dirty_guard_release_index < release_index):
        release_index = dirty_guard_release_index
    chest_nil_index = body.find("playerChestStates[userId] = nil")
    quest_nil_index = body.find("playerQuestStates[userId] = nil")

    if release_index == -1:
        fail("PlayerRemoving order", "PlayerRemoving does not call DataManager.ReleaseProfile(player) or releaseProfileWithDirtyGuard().", GAME_SERVER)
        return

    if chest_nil_index == -1 or quest_nil_index == -1:
        fail("PlayerRemoving cleanup", "PlayerRemoving must clean chest and quest state after release.", GAME_SERVER)
        return

    early = []
    if chest_nil_index < release_index:
        early.append("playerChestStates[userId] = nil")
    if quest_nil_index < release_index:
        early.append("playerQuestStates[userId] = nil")

    if early:
        fail(
            "PlayerRemoving order",
            "Session persistence state is cleared before ReleaseProfile: " + ", ".join(early),
            GAME_SERVER,
        )


def main() -> int:
    data_manager = read_text(DATA_MANAGER)
    game_logic = read_text(GAME_LOGIC)
    game_server = read_text(GAME_SERVER)

    check_data_version(data_manager)
    check_default_data(data_manager)
    check_normalize_data(data_manager)
    check_export_player_data(game_logic)
    check_import_player_data(game_logic, game_server)
    check_persistence_audit_tools(data_manager, game_server)
    check_quest_dictionary_shape(game_server)
    check_player_removing_order(game_server)

    if failures:
        for failure in failures:
            print(f"[FAIL] {failure.name}")
            print(f"- {failure.reason}")
            print(f"- 확인해야 할 파일: {failure.file_path}")
        return 1

    print("[PASS] Data Persistence v3 headless tests passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
