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
        "position": [0.0, 1.1, 14.0],
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
    result["completed_job_ids"] = raw["completed_job_ids"].duplicate()
    result["last_seen_utc"] = int(raw.get("last_seen_utc", 0))
    return result

static func read_save() -> Dictionary:
    last_load_warning = ""
    var had_save: bool = FileAccess.file_exists(SAVE_FILE) or FileAccess.file_exists(BACKUP_FILE)
    for path in [SAVE_FILE, BACKUP_FILE]:
        if not FileAccess.file_exists(path):
            continue
        var file: FileAccess = FileAccess.open(path, FileAccess.READ)
        if file == null:
            continue
        var parsed: Variant = JSON.parse_string(file.get_as_text())
        var cleaned: Dictionary = sanitize(parsed)
        if not cleaned.is_empty():
            if path == BACKUP_FILE:
                last_load_warning = "主存档损坏，已从备份恢复。"
                push_warning(last_load_warning)
            return cleaned
    if had_save:
        last_load_warning = "现有存档不可读取，已使用新游戏状态，请先备份旧文件。"
        push_warning(last_load_warning)
    return initial()

static func write_save(state: Dictionary) -> bool:
    var checked: Dictionary = sanitize(state)
    if checked.is_empty():
        return false
    checked["last_seen_utc"] = int(Time.get_unix_time_from_system())
    # Keep previous valid data in a backup before replacing the main save.
    if FileAccess.file_exists(SAVE_FILE):
        var source: FileAccess = FileAccess.open(SAVE_FILE, FileAccess.READ)
        if source != null:
            var old_text: String = source.get_as_text()
            if not sanitize(JSON.parse_string(old_text)).is_empty():
                var backup: FileAccess = FileAccess.open(BACKUP_FILE, FileAccess.WRITE)
                if backup != null:
                    backup.store_string(old_text)
                    backup.close()
    var target: FileAccess = FileAccess.open(SAVE_FILE, FileAccess.WRITE)
    if target == null:
        return false
    target.store_string(JSON.stringify(checked, "  "))
    target.flush()
    target.close()
    return true

static func can_afford(state: Dictionary, cost: int) -> bool:
    return cost >= 0 and int(state.get("balance", -1)) >= cost

static func purchase(state: Dictionary, item_id: String, cost: int) -> bool:
    if not can_afford(state, cost):
        return false
    if item_id in state.get("owned_items", []):
        return false
    state["balance"] = int(state["balance"]) - cost
    state["owned_items"].append(item_id)
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
