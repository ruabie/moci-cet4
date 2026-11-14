extends RefCounted
class_name CitySave

const SAVE_VERSION: int = 1
const SAVE_FILE: String = "user://same_time_city_v03.json"
const BACKUP_FILE: String = "user://same_time_city_v03.bak"
const MAX_BALANCE: int = 10000000
static var last_load_warning: String = ""

static func initial() -> Dictionary:
    return {
        "version": SAVE_VERSION,
        "balance": 800,
        "jobs_completed": 0,
        "owned_items": [],
        "position": [-8.1, 0.2, 8.0],
        "at_home": false,
        "last_seen_utc": int(Time.get_unix_time_from_system()),
        "completed_job_ids": []
    }

static func sanitize(raw: Variant) -> Dictionary:
    if typeof(raw) != TYPE_DICTIONARY:
        return {}
    if int(raw.get("version", -1)) != SAVE_VERSION:
        return {}
    if typeof(raw.get("owned_items", null)) != TYPE_ARRAY:
        return {}
    if typeof(raw.get("position", null)) != TYPE_ARRAY or raw["position"].size() != 3:
        return {}
    if typeof(raw.get("completed_job_ids", null)) != TYPE_ARRAY:
        return {}
    var balance: int = int(raw.get("balance", -1))
    if balance < 0 or balance > MAX_BALANCE:
        return {}
    var p: Array = raw["position"]
    for v in p:
        if typeof(v) != TYPE_FLOAT and typeof(v) != TYPE_INT:
            return {}
        if not is_finite(float(v)) or absf(float(v)) > 2000.0:
            return {}
    var result: Dictionary = initial()
    result["balance"] = balance
    result["jobs_completed"] = maxi(0, int(raw.get("jobs_completed", 0)))
    result["owned_items"] = raw["owned_items"].duplicate()
    result["position"] = p.duplicate()
    result["at_home"] = bool(raw.get("at_home", false))
    # Never accept malformed IDs or extremely large collections from corrupted saves.
    for item_id in raw["owned_items"]:
        if typeof(item_id) != TYPE_STRING or item_id.length() > 120:
            return {}
    for job_id in raw["completed_job_ids"]:
        if typeof(job_id) != TYPE_STRING or job_id.length() > 120:
            return {}
    if raw["owned_items"].size() > 2000 or raw["completed_job_ids"].size() > 50000:
        return {}
    result["completed_job_ids"] = raw["completed_job_ids"].duplicate()
    result["last_seen_utc"] = int(raw.get("last_seen_utc", 0))
    return result

static func read_save(path: String = SAVE_FILE, backup_path: String = BACKUP_FILE) -> Dictionary:
    last_load_warning = ""
    var had_save: bool = FileAccess.file_exists(path) or FileAccess.file_exists(backup_path)
    for current_path in [path, backup_path]:
        if not FileAccess.file_exists(current_path):
            continue
        var file: FileAccess = FileAccess.open(current_path, FileAccess.READ)
        if file == null:
            continue
        var parsed: Variant = JSON.parse_string(file.get_as_text())
        var cleaned: Dictionary = sanitize(parsed)
        if not cleaned.is_empty():
            if current_path == backup_path:
                last_load_warning = "主存档损坏，已从备份恢复。"
                push_warning(last_load_warning)
            return cleaned
    if had_save:
        last_load_warning = "现有存档不可读取，已使用新游戏状态，请先备份旧文件。"
        push_warning(last_load_warning)
    return initial()

static func write_save(state: Dictionary, path: String = SAVE_FILE, backup_path: String = BACKUP_FILE) -> bool:
    var checked: Dictionary = sanitize(state)
    if checked.is_empty():
        return false
    checked["last_seen_utc"] = int(Time.get_unix_time_from_system())
    # Keep previous valid data in a backup before replacing the main save.
    if FileAccess.file_exists(path):
        var source: FileAccess = FileAccess.open(path, FileAccess.READ)
        if source != null:
            var old_text: String = source.get_as_text()
            if not sanitize(JSON.parse_string(old_text)).is_empty():
                var backup: FileAccess = FileAccess.open(backup_path, FileAccess.WRITE)
                if backup != null:
                    backup.store_string(old_text)
                    backup.close()
    var target: FileAccess = FileAccess.open(path, FileAccess.WRITE)
    if target == null:
        return false
    target.store_string(JSON.stringify(checked, "  "))
    target.flush()
    target.close()
    return true

static func can_afford(state: Dictionary, cost: int) -> bool:
    return cost >= 0 and int(state.get("balance", -1)) >= cost

static func purchase(state: Dictionary, item_id: String, cost: int) -> bool:
    if item_id.is_empty() or not can_afford(state, cost):
        return false
    if item_id in state.get("owned_items", []):
        return false
    state["balance"] = int(state["balance"]) - cost
    state["owned_items"].append(item_id)
    return true


static func spend(state: Dictionary, cost: int) -> bool:
    # Consumables must not become permanent owned_items.
    if cost <= 0 or not can_afford(state, cost):
        return false
    state["balance"] = int(state["balance"]) - cost
    return true

static func pay_job_once(state: Dictionary, job_id: String, amount: int) -> bool:
    if job_id.is_empty() or amount <= 0:
        return false
    if job_id in state.get("completed_job_ids", []):
        return false
    if int(state.get("balance", 0)) + amount > MAX_BALANCE:
        return false
    state["balance"] = int(state["balance"]) + amount
    state["jobs_completed"] = int(state["jobs_completed"]) + 1
    state["completed_job_ids"].append(job_id)
    return true