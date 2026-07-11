from __future__ import annotations

import hashlib
import math
import random
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
GAME_SERVER = ROOT / "src" / "ServerScriptService" / "GameServer.server.lua"
GAME_LOGIC = ROOT / "src" / "ServerScriptService" / "GameLogic.lua"
CONCEPT_GENERATOR = ROOT / "src" / "ServerScriptService" / "ConceptGenerator.lua"
DATA_MANAGER = ROOT / "src" / "ServerScriptService" / "DataManager.lua"
SIMPLE_WORLD_BUILDER = ROOT / "src" / "ServerScriptService" / "SimpleWorldBuilder.lua"
UI_CONTROLLER = ROOT / "src" / "StarterPlayer" / "StarterPlayerScripts" / "UIController.client.lua"

SEED = 8050082000
RUNS = 10_000
SIM_SECONDS = 600.0
CHECKPOINTS = (180.0, 300.0, 600.0)


@dataclass(frozen=True)
class RarityConfig:
    min_iq: int
    max_iq: int
    base_weight: float
    luck_curve: float
    rarity_rank_boost: float
    max_luck_multiplier: float
    target_count: int
    secret_check: bool
    gate_chance_base: float


@dataclass(frozen=True)
class ChestReward:
    weight: float
    reward_type: str
    amount: int
    text: str


@dataclass(frozen=True)
class QuestDefinition:
    quest_id: str
    goal: int
    reward_type: str
    reward_amount: int


@dataclass
class Settings:
    starting_iq: int
    display_formula: str
    server_next_area_required_iq: int
    map_elementary_required_iq: int
    ui_next_area_required_iq: int
    middle_school_required_iq: int | None
    roll_cooldown_seconds: float
    server_min_roll_cooldown: float
    auto_roll_level0_delay: float
    brain_surge_target: int
    brain_surge_multiplier: float
    max_luck_level: int
    luck_scale: float
    rarity_order: list[str]
    gate_rarity_order: list[str]
    rarity_config: dict[str, RarityConfig]
    kp_rewards: dict[str, int]
    index_level_thresholds: dict[int, int]
    index_milestone_bonuses: list[tuple[int, float]]
    basic_chest_cost: int
    basic_chest_rewards: list[ChestReward]
    quest_definitions: list[QuestDefinition]


def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except FileNotFoundError:
        print(f"[FAIL] Missing file: {path}")
        sys.exit(1)


def extract_number(text: str, pattern: str, name: str, path: Path, cast: type = int) -> Any:
    match = re.search(pattern, text, re.MULTILINE)
    if not match:
        print(f"[FAIL] Could not parse {name} from {path}")
        sys.exit(1)
    return cast(match.group(1))


def extract_lua_table(text: str, assignment_pattern: str, name: str, path: Path) -> str:
    match = re.search(assignment_pattern, text, re.MULTILINE)
    if not match:
        print(f"[FAIL] Could not find {name} in {path}")
        sys.exit(1)

    start = text.find("{", match.end() - 1)
    if start == -1:
        print(f"[FAIL] Could not find table start for {name} in {path}")
        sys.exit(1)

    depth = 0
    for index in range(start, len(text)):
        char = text[index]
        if char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return text[start + 1 : index]

    print(f"[FAIL] Could not find table end for {name} in {path}")
    sys.exit(1)


def parse_quoted_list(table_body: str) -> list[str]:
    return re.findall(r'"([^"]+)"', table_body)


def parse_lua_number(value: str) -> float:
    if value == "nil":
        return 0.0
    return float(value)


def parse_rarity_config(concept_generator: str) -> dict[str, RarityConfig]:
    table = extract_lua_table(
        concept_generator,
        r"local\s+RarityConfig\s*=\s*{",
        "RarityConfig",
        CONCEPT_GENERATOR,
    )
    result: dict[str, RarityConfig] = {}
    for match in re.finditer(r"\n\t([A-Z_]+)\s*=\s*{(.*?)\n\t},", table, re.DOTALL):
        rarity = match.group(1)
        body = match.group(2)

        def number(field: str, default: float | None = None) -> float:
            found = re.search(field + r"\s*=\s*([0-9.]+|nil)", body)
            if found:
                return parse_lua_number(found.group(1))
            if default is not None:
                return default
            print(f"[FAIL] Missing {field} for rarity {rarity}")
            sys.exit(1)

        def boolean(field: str) -> bool:
            found = re.search(field + r"\s*=\s*(true|false)", body)
            if not found:
                print(f"[FAIL] Missing {field} for rarity {rarity}")
                sys.exit(1)
            return found.group(1) == "true"

        result[rarity] = RarityConfig(
            min_iq=int(number("MinIQ")),
            max_iq=int(number("MaxIQ")),
            base_weight=number("BaseWeight"),
            luck_curve=number("LuckCurve", 1.0),
            rarity_rank_boost=number("RarityRankBoost", 0.0),
            max_luck_multiplier=number("MaxLuckMultiplier", math.inf),
            target_count=int(number("TargetCount")),
            secret_check=boolean("SecretCheck"),
            gate_chance_base=number("GateChanceBase", 0.0),
        )

    if not result:
        print("[FAIL] Parsed zero rarity configs")
        sys.exit(1)
    return result


def parse_kp_rewards(game_logic: str) -> dict[str, int]:
    table = extract_lua_table(game_logic, r"local\s+KNOWLEDGE_POINTS_REWARD\s*=\s*{", "KNOWLEDGE_POINTS_REWARD", GAME_LOGIC)
    return {rarity: int(amount) for rarity, amount in re.findall(r"([A-Z_]+)\s*=\s*(\d+)", table)}


def parse_index_thresholds(game_logic: str) -> dict[int, int]:
    table = extract_lua_table(game_logic, r"local\s+INDEX_LEVEL_THRESHOLDS\s*=\s*{", "INDEX_LEVEL_THRESHOLDS", GAME_LOGIC)
    return {int(level): int(kp) for level, kp in re.findall(r"\[(\d+)\]\s*=\s*(\d+)", table)}


def parse_index_milestones(game_logic: str) -> list[tuple[int, float]]:
    table = extract_lua_table(game_logic, r"local\s+INDEX_MILESTONE_BONUSES\s*=\s*{", "INDEX_MILESTONE_BONUSES", GAME_LOGIC)
    milestones = [(int(count), float(bonus)) for count, bonus in re.findall(r"Count\s*=\s*(\d+),\s*Bonus\s*=\s*([0-9.]+)", table)]
    if not milestones:
        print("[FAIL] Parsed zero index milestones")
        sys.exit(1)
    return milestones


def parse_chest_rewards(game_server: str) -> list[ChestReward]:
    table = extract_lua_table(game_server, r"local\s+BASIC_CHEST_REWARDS\s*=\s*{", "BASIC_CHEST_REWARDS", GAME_SERVER)
    rewards: list[ChestReward] = []
    for weight, reward_type, amount, text in re.findall(
        r'Weight\s*=\s*([0-9.]+),\s*Type\s*=\s*"([^"]+)",\s*Amount\s*=\s*(\d+),\s*Text\s*=\s*"([^"]+)"',
        table,
    ):
        rewards.append(ChestReward(float(weight), reward_type, int(amount), text))
    if not rewards:
        print("[FAIL] Parsed zero Basic chest rewards")
        sys.exit(1)
    return rewards


def parse_quest_definitions(game_server: str) -> list[QuestDefinition]:
    table = extract_lua_table(game_server, r"local\s+QUEST_DEFINITIONS\s*=\s*{", "QUEST_DEFINITIONS", GAME_SERVER)
    quests: list[QuestDefinition] = []
    for block in re.findall(r"\{\s*Id\s*=.*?\n\t},", table, re.DOTALL):
        quest_id = re.search(r'Id\s*=\s*"([^"]+)"', block)
        goal = re.search(r"Goal\s*=\s*(\d+)", block)
        reward = re.search(r'Reward\s*=\s*{\s*Type\s*=\s*"([^"]+)",\s*Amount\s*=\s*(\d+)\s*}', block)
        if quest_id and goal and reward:
            quests.append(QuestDefinition(quest_id.group(1), int(goal.group(1)), reward.group(1), int(reward.group(2))))
    if not quests:
        print("[FAIL] Parsed zero quest definitions")
        sys.exit(1)
    return quests


def load_settings() -> Settings:
    game_server = read_text(GAME_SERVER)
    game_logic = read_text(GAME_LOGIC)
    concept_generator = read_text(CONCEPT_GENERATOR)
    data_manager = read_text(DATA_MANAGER)
    simple_world_builder = read_text(SIMPLE_WORLD_BUILDER)
    ui_controller = read_text(UI_CONTROLLER)

    rarity_order = parse_quoted_list(extract_lua_table(concept_generator, r"local\s+rarityOrder\s*=\s*{", "rarityOrder", CONCEPT_GENERATOR))
    gate_rarity_order = parse_quoted_list(
        extract_lua_table(concept_generator, r"local\s+gateRarityOrder\s*=\s*{", "gateRarityOrder", CONCEPT_GENERATOR)
    )
    server_min_roll_cooldown = extract_number(
        game_server,
        r"local\s+SERVER_MIN_ROLL_COOLDOWN\s*=\s*([0-9.]+)",
        "SERVER_MIN_ROLL_COOLDOWN",
        GAME_SERVER,
        float,
    )
    auto_roll_level0_delay = extract_number(
        game_server,
        r"if\s+autoLevel\s+<=\s+0\s+then\s*\n\s*return\s+([0-9.]+)",
        "AutoRoll level 0 delay",
        GAME_SERVER,
        float,
    )
    roll_cooldown = max(auto_roll_level0_delay, server_min_roll_cooldown)

    middle_matches = re.findall(r"82000|82\.000|MiddleSchool|Middle School", simple_world_builder + "\n" + game_server + "\n" + ui_controller)

    return Settings(
        starting_iq=extract_number(data_manager, r"IQ\s*=\s*(\d+),", "default IQ", DATA_MANAGER),
        display_formula="formatNumber: >=1B -> %.1fB, >=1M -> %.1fM, >=1K -> %.1fK, else floor(value)",
        server_next_area_required_iq=extract_number(game_server, r"local\s+NEXT_AREA_REQUIRED_IQ\s*=\s*(\d+)", "server NEXT_AREA_REQUIRED_IQ", GAME_SERVER),
        map_elementary_required_iq=extract_number(
            simple_world_builder,
            r"local\s+NEXT_AREA_REQUIRED_IQ\s*=\s*(\d+)",
            "map NEXT_AREA_REQUIRED_IQ",
            SIMPLE_WORLD_BUILDER,
        ),
        ui_next_area_required_iq=extract_number(ui_controller, r"local\s+NEXT_AREA_REQUIRED_IQ\s*=\s*(\d+)", "client NEXT_AREA_REQUIRED_IQ", UI_CONTROLLER),
        middle_school_required_iq=82000 if middle_matches and any(value in {"82000", "82.000"} for value in middle_matches) else None,
        roll_cooldown_seconds=roll_cooldown,
        server_min_roll_cooldown=server_min_roll_cooldown,
        auto_roll_level0_delay=auto_roll_level0_delay,
        brain_surge_target=extract_number(game_server, r"local\s+BRAIN_SURGE_TARGET\s*=\s*(\d+)", "BRAIN_SURGE_TARGET", GAME_SERVER),
        brain_surge_multiplier=extract_number(game_server, r"local\s+BRAIN_SURGE_MULTIPLIER\s*=\s*([0-9.]+)", "BRAIN_SURGE_MULTIPLIER", GAME_SERVER, float),
        max_luck_level=extract_number(concept_generator, r"local\s+MAX_LUCK_LEVEL\s*=\s*(\d+)", "MAX_LUCK_LEVEL", CONCEPT_GENERATOR),
        luck_scale=extract_number(concept_generator, r"local\s+LUCK_SCALE\s*=\s*([0-9.]+)", "LUCK_SCALE", CONCEPT_GENERATOR, float),
        rarity_order=rarity_order,
        gate_rarity_order=gate_rarity_order,
        rarity_config=parse_rarity_config(concept_generator),
        kp_rewards=parse_kp_rewards(game_logic),
        index_level_thresholds=parse_index_thresholds(game_logic),
        index_milestone_bonuses=parse_index_milestones(game_logic),
        basic_chest_cost=extract_number(game_server, r"local\s+BASIC_CHEST_COST\s*=\s*(\d+)", "BASIC_CHEST_COST", GAME_SERVER),
        basic_chest_rewards=parse_chest_rewards(game_server),
        quest_definitions=parse_quest_definitions(game_server),
    )


def format_number(value: float) -> str:
    value = float(value)
    if value >= 1_000_000_000:
        return f"{value / 1_000_000_000:.1f}B"
    if value >= 1_000_000:
        return f"{value / 1_000_000:.1f}M"
    if value >= 1_000:
        return f"{value / 1_000:.1f}K"
    return str(math.floor(value))


def index_level_from_kp(settings: Settings, kp: int) -> int:
    level = 1
    for candidate, required in sorted(settings.index_level_thresholds.items()):
        if kp >= required:
            level = candidate
    return level


def index_iq_multiplier(settings: Settings, kp: int) -> float:
    return min(1 + ((index_level_from_kp(settings, kp) - 1) * 0.05), 2.0)


def milestone_bonus(settings: Settings, discovered_count: int) -> float:
    current = settings.index_milestone_bonuses[0][1]
    for count, bonus in settings.index_milestone_bonuses:
        if discovered_count >= count:
            current = bonus
        else:
            break
    return current


def effective_luck(settings: Settings, luck_level: float) -> float:
    if luck_level <= 0:
        return 0.0
    return math.log(1 + (luck_level * settings.luck_scale)) / math.log(1 + (settings.max_luck_level * settings.luck_scale))


def rarity_multiplier(settings: Settings, config: RarityConfig, luck_level: float) -> float:
    luck = max(0.0, min(float(luck_level), float(settings.max_luck_level)))
    eff = effective_luck(settings, luck)
    return min(1 + ((eff ** config.luck_curve) * config.rarity_rank_boost), config.max_luck_multiplier)


def adjusted_weight(settings: Settings, rarity: str, luck_level: float) -> float:
    config = settings.rarity_config[rarity]
    if config.secret_check:
        return 0.0
    return config.base_weight * rarity_multiplier(settings, config, luck_level)


def gate_chance(settings: Settings, rarity: str, luck_level: float) -> float:
    config = settings.rarity_config[rarity]
    if not config.secret_check:
        return 0.0
    return config.gate_chance_base * rarity_multiplier(settings, config, luck_level)


def choose_rarity(settings: Settings, rng: random.Random, luck_level: float) -> str:
    for rarity in settings.gate_rarity_order:
        chance = gate_chance(settings, rarity, luck_level)
        if chance > 0 and rng.random() < chance:
            return rarity

    weighted: list[tuple[str, float]] = []
    total = 0.0
    for rarity in settings.rarity_order:
        weight = adjusted_weight(settings, rarity, luck_level)
        if weight > 0:
            weighted.append((rarity, weight))
            total += weight

    roll = rng.random() * total
    running = 0.0
    for rarity, weight in weighted:
        running += weight
        if roll <= running:
            return rarity
    return "COMMON"


def build_rarity_cumulative(settings: Settings, luck_level: float) -> tuple[list[tuple[str, float]], float]:
    weighted: list[tuple[str, float]] = []
    total = 0.0
    for rarity in settings.rarity_order:
        weight = adjusted_weight(settings, rarity, luck_level)
        if weight > 0:
            total += weight
            weighted.append((rarity, total))
    return weighted, total


def choose_rarity_from_cumulative(rng: random.Random, cumulative: list[tuple[str, float]], total: float) -> str:
    roll = rng.random() * total
    for rarity, running in cumulative:
        if roll <= running:
            return rarity
    return "COMMON"


def build_chest_cumulative(settings: Settings) -> tuple[list[tuple[ChestReward, float]], float]:
    weighted: list[tuple[ChestReward, float]] = []
    total = 0.0
    for reward in settings.basic_chest_rewards:
        total += max(0.0, reward.weight)
        weighted.append((reward, total))
    return weighted, total


def choose_chest_from_cumulative(rng: random.Random, cumulative: list[tuple[ChestReward, float]], total: float) -> ChestReward:
    roll = rng.random() * total
    for reward, running in cumulative:
        if roll <= running:
            return reward
    return cumulative[0][0]


def roll_basic_chest_reward(settings: Settings, rng: random.Random) -> ChestReward:
    total = sum(max(0.0, reward.weight) for reward in settings.basic_chest_rewards)
    roll = rng.random() * total
    running = 0.0
    for reward in settings.basic_chest_rewards:
        running += max(0.0, reward.weight)
        if roll <= running:
            return reward
    return settings.basic_chest_rewards[0]


def apply_reward(state: dict[str, Any], reward_type: str, amount: int) -> None:
    if reward_type == "IQ":
        state["iq"] += amount
    elif reward_type in {"KP", "KnowledgePoints"}:
        state["kp"] += amount


def run_one(
    settings: Settings,
    rng: random.Random,
    include_chest_and_quest: bool,
    rarity_cumulative: list[tuple[str, float]],
    rarity_total: float,
    chest_cumulative: list[tuple[ChestReward, float]],
    chest_total: float,
) -> dict[str, Any]:
    iq = settings.starting_iq
    kp = 0
    luck = 0
    brain_surge_count = 0
    concepts: set[tuple[str, int]] = set()
    chest_points = 0
    chest_total_opened = 0

    quest_by_id = {quest.quest_id: quest for quest in settings.quest_definitions}
    roll_quest = quest_by_id.get("Roll_50")
    gain_quest = quest_by_id.get("GainIQ_1000")
    discover_quest = quest_by_id.get("Discover_3")
    roll_progress = 0
    gain_progress = 0
    discover_progress = 0
    roll_completed = False
    gain_completed = False
    discover_completed = False
    roll_claimed = False
    gain_claimed = False
    discover_claimed = False

    checkpoints: dict[float, int] = {checkpoint: settings.starting_iq for checkpoint in CHECKPOINTS}
    previous_iq = settings.starting_iq
    display_decrease_cases = 0
    wrong_school_pass = False
    elementary_time: float | None = None
    elementary_rolls: int | None = None
    middle_time: float | None = None
    middle_rolls: int | None = None
    server_unlock_time: float | None = None
    roll_count = 0

    roll_times: list[float] = []
    time = 0.0
    while time <= SIM_SECONDS + 0.000001:
        roll_times.append(round(time, 8))
        time += settings.roll_cooldown_seconds

    for roll_time in roll_times:
        roll_count += 1

        next_count = brain_surge_count + 1
        brain_surge_active = next_count >= settings.brain_surge_target
        if brain_surge_active:
            effective_luck_level = min(float(luck) * settings.brain_surge_multiplier, settings.max_luck_level)
            brain_surge_count = 0
        else:
            effective_luck_level = float(luck)
            brain_surge_count = next_count

        if effective_luck_level == 0:
            rarity = choose_rarity_from_cumulative(rng, rarity_cumulative, rarity_total)
        else:
            rarity = choose_rarity(settings, rng, effective_luck_level)
        rarity_config = settings.rarity_config[rarity]
        concept_index = rng.randrange(rarity_config.target_count)
        base_iq = rng.randint(rarity_config.min_iq, rarity_config.max_iq)
        concept_key = (rarity, concept_index)
        is_new_concept = concept_key not in concepts

        if is_new_concept:
            concepts.add(concept_key)
            kp += settings.kp_rewards.get(rarity, 0)

        gained_iq = max(1, math.floor(base_iq * index_iq_multiplier(settings, kp) * milestone_bonus(settings, len(concepts))))
        iq += gained_iq

        if roll_quest and not roll_claimed:
            roll_progress = min(roll_quest.goal, roll_progress + 1)
            roll_completed = roll_progress >= roll_quest.goal
        if gain_quest and not gain_claimed:
            gain_progress = min(gain_quest.goal, gain_progress + gained_iq)
            gain_completed = gain_progress >= gain_quest.goal
        if discover_quest and is_new_concept and not discover_claimed:
            discover_progress = min(discover_quest.goal, discover_progress + 1)
            discover_completed = discover_progress >= discover_quest.goal

        chest_points += 4 if is_new_concept else 1

        if include_chest_and_quest:
            if roll_quest and roll_completed and not roll_claimed:
                if roll_quest.reward_type in {"KP", "KnowledgePoints"}:
                    kp += roll_quest.reward_amount
                elif roll_quest.reward_type == "IQ":
                    iq += roll_quest.reward_amount
                roll_claimed = True
                chest_points += 10
            if gain_quest and gain_completed and not gain_claimed:
                if gain_quest.reward_type in {"KP", "KnowledgePoints"}:
                    kp += gain_quest.reward_amount
                elif gain_quest.reward_type == "IQ":
                    iq += gain_quest.reward_amount
                gain_claimed = True
                chest_points += 10
            if discover_quest and discover_completed and not discover_claimed:
                if discover_quest.reward_type in {"KP", "KnowledgePoints"}:
                    kp += discover_quest.reward_amount
                elif discover_quest.reward_type == "IQ":
                    iq += discover_quest.reward_amount
                discover_claimed = True
                chest_points += 10

            while chest_points >= settings.basic_chest_cost:
                chest_points -= settings.basic_chest_cost
                reward = choose_chest_from_cumulative(rng, chest_cumulative, chest_total)
                if reward.reward_type in {"KP", "KnowledgePoints"}:
                    kp += reward.amount
                elif reward.reward_type == "IQ":
                    iq += reward.amount
                chest_total_opened += 1

        if iq < previous_iq:
            display_decrease_cases += 1
        previous_iq = iq

        for checkpoint in CHECKPOINTS:
            if roll_time <= checkpoint:
                checkpoints[checkpoint] = iq

        if server_unlock_time is None and iq >= settings.server_next_area_required_iq:
            server_unlock_time = roll_time

        if elementary_time is None and iq >= settings.map_elementary_required_iq:
            elementary_time = roll_time
            elementary_rolls = roll_count

        if settings.middle_school_required_iq is not None and middle_time is None and iq >= settings.middle_school_required_iq:
            middle_time = roll_time
            middle_rolls = roll_count

        if iq >= settings.server_next_area_required_iq and iq < settings.map_elementary_required_iq:
            wrong_school_pass = True

    return {
        "final_iq": iq,
        "roll_count": roll_count,
        "checkpoints": checkpoints,
        "elementary_time": elementary_time,
        "elementary_rolls": elementary_rolls,
        "middle_time": middle_time,
        "middle_rolls": middle_rolls,
        "server_unlock_time": server_unlock_time,
        "remaining_elementary_iq": max(0, settings.map_elementary_required_iq - int(iq)),
        "remaining_middle_iq": None
        if settings.middle_school_required_iq is None
        else max(0, settings.middle_school_required_iq - int(iq)),
        "display_decrease_cases": display_decrease_cases,
        "wrong_school_pass_cases": 1 if wrong_school_pass else 0,
        "chest_total_opened": chest_total_opened,
        "chest_points": chest_points,
        "quest_claimed_count": sum(1 for claimed in (roll_claimed, gain_claimed, discover_claimed) if claimed),
    }


def percentile(values: list[float], p: float) -> float | None:
    if not values:
        return None
    sorted_values = sorted(values)
    if len(sorted_values) == 1:
        return sorted_values[0]
    rank = (len(sorted_values) - 1) * p
    low = math.floor(rank)
    high = math.ceil(rank)
    if low == high:
        return sorted_values[low]
    return sorted_values[low] + ((sorted_values[high] - sorted_values[low]) * (rank - low))


def fmt_seconds(value: float | None) -> str:
    if value is None:
        return "N/A"
    return f"{value:.2f}s"


def fmt_number(value: float | None) -> str:
    if value is None:
        return "N/A"
    if abs(value - round(value)) < 0.000001:
        return str(int(round(value)))
    return f"{value:.2f}"


def summarize(settings: Settings, results: list[dict[str, Any]]) -> dict[str, Any]:
    elementary_times = [item["elementary_time"] for item in results if item["elementary_time"] is not None]
    elementary_rolls = [item["elementary_rolls"] for item in results if item["elementary_rolls"] is not None]
    middle_times = [item["middle_time"] for item in results if item["middle_time"] is not None]
    middle_rolls = [item["middle_rolls"] for item in results if item["middle_rolls"] is not None]

    summary: dict[str, Any] = {
        "elementary_time_p10": percentile(elementary_times, 0.10),
        "elementary_time_p50": percentile(elementary_times, 0.50),
        "elementary_time_p90": percentile(elementary_times, 0.90),
        "elementary_under_3m_rate": sum(1 for item in results if item["elementary_time"] is not None and item["elementary_time"] <= 180.0) / len(results),
        "elementary_roll_p10": percentile(elementary_rolls, 0.10),
        "elementary_roll_p50": percentile(elementary_rolls, 0.50),
        "elementary_roll_p90": percentile(elementary_rolls, 0.90),
        "middle_time_p10": percentile(middle_times, 0.10),
        "middle_time_p50": percentile(middle_times, 0.50),
        "middle_time_p90": percentile(middle_times, 0.90),
        "middle_under_10m_rate": None
        if settings.middle_school_required_iq is None
        else sum(1 for item in results if item["middle_time"] is not None and item["middle_time"] <= 600.0) / len(results),
        "middle_roll_p10": percentile(middle_rolls, 0.10),
        "middle_roll_p50": percentile(middle_rolls, 0.50),
        "middle_roll_p90": percentile(middle_rolls, 0.90),
        "display_decrease_cases": sum(int(item["display_decrease_cases"]) for item in results),
        "wrong_school_pass_cases": sum(int(item["wrong_school_pass_cases"]) for item in results),
        "avg_chest_opened": sum(int(item["chest_total_opened"]) for item in results) / len(results),
        "avg_quest_claimed": sum(int(item["quest_claimed_count"]) for item in results) / len(results),
    }

    for checkpoint in CHECKPOINTS:
        values = [item["checkpoints"][checkpoint] for item in results]
        summary[f"iq_{int(checkpoint)}_p10"] = percentile(values, 0.10)
        summary[f"iq_{int(checkpoint)}_p50"] = percentile(values, 0.50)
        summary[f"iq_{int(checkpoint)}_p90"] = percentile(values, 0.90)

    not_reached_elementary_remaining = [item["remaining_elementary_iq"] for item in results if item["elementary_time"] is None]
    summary["elementary_unreached_count"] = len(not_reached_elementary_remaining)
    summary["elementary_remaining_p10"] = percentile(not_reached_elementary_remaining, 0.10)
    summary["elementary_remaining_p50"] = percentile(not_reached_elementary_remaining, 0.50)
    summary["elementary_remaining_p90"] = percentile(not_reached_elementary_remaining, 0.90)

    if settings.middle_school_required_iq is None:
        summary["middle_unreached_count"] = None
        summary["middle_remaining_p10"] = None
        summary["middle_remaining_p50"] = None
        summary["middle_remaining_p90"] = None
    else:
        not_reached_middle_remaining = [item["remaining_middle_iq"] for item in results if item["middle_time"] is None]
        summary["middle_unreached_count"] = len(not_reached_middle_remaining)
        summary["middle_remaining_p10"] = percentile(not_reached_middle_remaining, 0.10)
        summary["middle_remaining_p50"] = percentile(not_reached_middle_remaining, 0.50)
        summary["middle_remaining_p90"] = percentile(not_reached_middle_remaining, 0.90)

    return summary


def simulate(settings: Settings, include_chest_and_quest: bool, runs: int = RUNS) -> tuple[list[dict[str, Any]], dict[str, Any], str]:
    rng = random.Random(SEED + (1 if include_chest_and_quest else 0))
    rarity_cumulative, rarity_total = build_rarity_cumulative(settings, 0)
    chest_cumulative, chest_total = build_chest_cumulative(settings)
    results = [
        run_one(settings, rng, include_chest_and_quest, rarity_cumulative, rarity_total, chest_cumulative, chest_total)
        for _ in range(runs)
    ]
    summary = summarize(settings, results)
    digest = hashlib.sha256(repr(summary).encode("utf-8")).hexdigest()
    return results, summary, digest


def validate_settings(settings: Settings) -> None:
    missing_rarities = [rarity for rarity in settings.rarity_order if rarity not in settings.rarity_config]
    if missing_rarities:
        print(f"[FAIL] RarityOrder entries missing config: {missing_rarities}")
        sys.exit(1)

    for rarity, config in settings.rarity_config.items():
        if config.min_iq > config.max_iq:
            print(f"[FAIL] Invalid IQ range for {rarity}")
            sys.exit(1)
        if config.target_count <= 0:
            print(f"[FAIL] Invalid TargetCount for {rarity}")
            sys.exit(1)

    total_weight = sum(adjusted_weight(settings, rarity, 0) for rarity in settings.rarity_order)
    if total_weight <= 0:
        print("[FAIL] Rarity positive weight sum is zero")
        sys.exit(1)

    chest_weight = sum(reward.weight for reward in settings.basic_chest_rewards)
    if abs(chest_weight - 100.0) > 0.000001:
        print(f"[FAIL] Basic chest reward weights sum to {chest_weight}, expected 100")
        sys.exit(1)

    if settings.roll_cooldown_seconds < settings.server_min_roll_cooldown:
        print("[FAIL] Effective roll cooldown is lower than SERVER_MIN_ROLL_COOLDOWN")
        sys.exit(1)


def print_settings(settings: Settings) -> None:
    print("== Actual Settings Read ==")
    print(f"Starting display IQ: {format_number(settings.starting_iq)} (internal {settings.starting_iq})")
    print(f"Display IQ formula: {settings.display_formula}")
    print(f"Elementary map requirement: {settings.map_elementary_required_iq} ({format_number(settings.map_elementary_required_iq)})")
    print(f"Server next-area requirement: {settings.server_next_area_required_iq} ({format_number(settings.server_next_area_required_iq)})")
    print(f"Client next-area requirement: {settings.ui_next_area_required_iq} ({format_number(settings.ui_next_area_required_iq)})")
    print(
        "MiddleSchool requirement: "
        + ("not found in current files" if settings.middle_school_required_iq is None else str(settings.middle_school_required_iq))
    )
    print(
        f"Roll cooldown: {settings.roll_cooldown_seconds:.2f}s "
        f"(level0={settings.auto_roll_level0_delay:.2f}s, min={settings.server_min_roll_cooldown:.2f}s)"
    )
    print(f"Brain Surge: target={settings.brain_surge_target}, luck multiplier={settings.brain_surge_multiplier:g}")
    print("Rarity rewards:")
    for rarity in settings.rarity_order:
        config = settings.rarity_config[rarity]
        print(
            f"  {rarity}: iq={config.min_iq}-{config.max_iq}, "
            f"weight={config.base_weight:g}, targetCount={config.target_count}, kp={settings.kp_rewards.get(rarity, 0)}"
        )
    print(f"Basic Chest: cost={settings.basic_chest_cost}, rewards=" + ", ".join(f"{r.weight:g}% {r.text}" for r in settings.basic_chest_rewards))
    print("Quests: " + ", ".join(f"{q.quest_id} goal={q.goal} reward={q.reward_type}+{q.reward_amount}" for q in settings.quest_definitions))


def print_summary(title: str, settings: Settings, summary: dict[str, Any]) -> None:
    print(f"\n== {title} ==")
    print(
        "Elementary 80.500 time P10/P50/P90: "
        f"{fmt_seconds(summary['elementary_time_p10'])} / {fmt_seconds(summary['elementary_time_p50'])} / {fmt_seconds(summary['elementary_time_p90'])}"
    )
    print(f"Elementary <= 3m rate: {summary['elementary_under_3m_rate'] * 100:.2f}%")
    print(
        "Elementary roll count P10/P50/P90: "
        f"{fmt_number(summary['elementary_roll_p10'])} / {fmt_number(summary['elementary_roll_p50'])} / {fmt_number(summary['elementary_roll_p90'])}"
    )

    if settings.middle_school_required_iq is None:
        print("MiddleSchool 82.000 time P10/P50/P90: N/A (no actual MiddleSchool 82.000 requirement found)")
        print("MiddleSchool <= 10m rate: N/A")
        print("MiddleSchool roll count P10/P50/P90: N/A")
    else:
        print(
            "MiddleSchool 82.000 time P10/P50/P90: "
            f"{fmt_seconds(summary['middle_time_p10'])} / {fmt_seconds(summary['middle_time_p50'])} / {fmt_seconds(summary['middle_time_p90'])}"
        )
        print(f"MiddleSchool <= 10m rate: {summary['middle_under_10m_rate'] * 100:.2f}%")
        print(
            "MiddleSchool roll count P10/P50/P90: "
            f"{fmt_number(summary['middle_roll_p10'])} / {fmt_number(summary['middle_roll_p50'])} / {fmt_number(summary['middle_roll_p90'])}"
        )

    for checkpoint in CHECKPOINTS:
        key = int(checkpoint)
        print(
            f"{int(checkpoint / 60)}m IQ P10/P50/P90: "
            f"{fmt_number(summary[f'iq_{key}_p10'])} / {fmt_number(summary[f'iq_{key}_p50'])} / {fmt_number(summary[f'iq_{key}_p90'])}"
        )

    print(
        "Unreached Elementary remaining IQ at 10m P10/P50/P90: "
        f"{fmt_number(summary['elementary_remaining_p10'])} / {fmt_number(summary['elementary_remaining_p50'])} / {fmt_number(summary['elementary_remaining_p90'])} "
        f"(runs={summary['elementary_unreached_count']})"
    )
    if settings.middle_school_required_iq is None:
        print("Unreached MiddleSchool remaining IQ at 10m P10/P50/P90: N/A")
    else:
        print(
            "Unreached MiddleSchool remaining IQ at 10m P10/P50/P90: "
            f"{fmt_number(summary['middle_remaining_p10'])} / {fmt_number(summary['middle_remaining_p50'])} / {fmt_number(summary['middle_remaining_p90'])} "
            f"(runs={summary['middle_unreached_count']})"
        )
    print(f"Display/internal IQ decrease cases: {summary['display_decrease_cases']}")
    print(f"School threshold mismatch pass cases: {summary['wrong_school_pass_cases']}")
    print(f"Average chests opened: {summary['avg_chest_opened']:.2f}")
    print(f"Average quests claimed: {summary['avg_quest_claimed']:.2f}")


def main() -> int:
    settings = load_settings()
    validate_settings(settings)
    print_settings(settings)

    _, scenario_a_smoke, digest_a_smoke = simulate(settings, include_chest_and_quest=False, runs=100)
    _, scenario_a_repeat, digest_a_repeat = simulate(settings, include_chest_and_quest=False, runs=100)
    if scenario_a_smoke != scenario_a_repeat or digest_a_smoke != digest_a_repeat:
        print("[FAIL] Scenario A is not deterministic with the same seed")
        return 1

    _, scenario_b_smoke, digest_b_smoke = simulate(settings, include_chest_and_quest=True, runs=100)
    _, scenario_b_repeat, digest_b_repeat = simulate(settings, include_chest_and_quest=True, runs=100)
    if scenario_b_smoke != scenario_b_repeat or digest_b_smoke != digest_b_repeat:
        print("[FAIL] Scenario B is not deterministic with the same seed")
        return 1

    _, scenario_a, digest_a = simulate(settings, include_chest_and_quest=False)
    _, scenario_b, digest_b = simulate(settings, include_chest_and_quest=True)

    print("\n== Simulation Assumptions ==")
    print(f"Seed: {SEED}; runs: {RUNS}; duration: {SIM_SECONDS:.0f}s; first roll at t=0; roll interval={settings.roll_cooldown_seconds:.2f}s")
    print("Scenario A: Roll success path only; Roll-side new-concept KP, quest progress, and chest point gain are still applied because handleRoll applies them.")
    print("Scenario B: Same Roll path, then immediately claim completed unclaimed quests and open Basic chests while CP is sufficient.")
    print("MiddleSchool 82.000 is not simulated unless an actual current source requirement is found.")
    print(f"Determinism hashes: A={digest_a[:16]}, B={digest_b[:16]}")

    print_summary("Scenario A - Roll Only", settings, scenario_a)
    print_summary("Scenario B - Roll + Immediate Quest Claim/Basic Chest Open", settings, scenario_b)

    print("\n[PASS] Early game balance simulation completed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
