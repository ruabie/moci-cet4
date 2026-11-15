extends RefCounted
class_name LifeContent

# Persistent life-loop state. All rewards are committed by the caller through CitySave.
# Daily keys follow the device's local date, never a fictional accelerated clock.
const MAX_BALANCE: int = 10000000
const RESIDENTS: Array[String] = ["小遥", "拓海", "晴子", "阿诚", "美咲", "木村"]
const JOB_TASKS: Dictionary = {
    "便利店": [
        ["客人买了矿泉水，应该扫描哪件商品？", "1 饼干  /  2 矿泉水  /  3 便当", 2],
        ["标签显示面包 12 城币。应输入？", "1 12  /  2 20  /  3 40", 1],
        ["客人递给你 50 城币，商品 30 城币。找零？", "1 10  /  2 15  /  3 20", 3]
    ],
    "咖啡馆": [
        ["订单：冰拿铁。先选哪种饮品？", "1 热茶  /  2 冰拿铁  /  3 果汁", 2],
        ["客人要求无糖。应选哪种配方？", "1 无糖  /  2 半糖  /  3 全糖", 1],
        ["饮品需要打包外带。应该使用？", "1 玻璃杯  /  2 瓷杯  /  3 外带杯", 3]
    ]
}

static func date_key() -> String:
    var d: Dictionary = WorldClock.snapshot()
    return "%04d-%02d-%02d" % [d["year"], d["month"], d["day"]]

static func prepare_day(s: Dictionary, day: String) -> bool:
    var previous: String = str(s.get("day_key", ""))
    if previous != "" and previous >= day:
        return false
    s["day_key"] = day
    s["daily_done"] = []
    s["photo_spots"] = []
    s["npc_talked_today"] = []
    s["delivery_active"] = false
    s["jobs_today"] = 0
    note(s, "新的一天：委托板更新。")
    return true

static func note(s: Dictionary, event: String) -> void:
    var j: Array = s.get("journal", []).duplicate()
    j.push_front(event.substr(0, 100))
    if j.size() > 24:
        j.resize(24)
    s["journal"] = j

static func _reward(s: Dictionary, amount: int) -> bool:
    var current: int = int(s.get("balance", 0))
    if amount < 0 or current > MAX_BALANCE - amount:
        return false
    s["balance"] = current + amount
    return true

static func completed(s: Dictionary, key: String) -> bool:
    return key in s.get("daily_done", [])

static func talk(s: Dictionary, resident: String, day: String) -> bool:
    prepare_day(s, day)
    if resident not in RESIDENTS or resident in s["npc_talked_today"]:
        return false
    s["npc_talked_today"].append(resident)
    var friends: Dictionary = s["friends"]
    friends[resident] = mini(10, int(friends.get(resident, 0)) + 1)
    s["mood"] = mini(100, int(s["mood"]) + 5)
    note(s, "和%s聊了聊天，关系提升。" % resident)
    if not completed(s, "social"):
        if _reward(s, 30):
            s["daily_done"].append("social")
            note(s, "日常目标：认识街坊 +30 城币。")
    return true

static func photo(s: Dictionary, spot_id: String, day: String) -> bool:
    prepare_day(s, day)
    if spot_id not in ["river", "crossing", "window"] or spot_id in s["photo_spots"]:
        return false
    s["photo_spots"].append(spot_id)
    s["mood"] = mini(100, int(s["mood"]) + 3)
    note(s, "记录了青川町的一处街景。")
    if s["photo_spots"].size() >= 2 and not completed(s, "photos"):
        if _reward(s, 25):
            s["daily_done"].append("photos")
            note(s, "摄影目标完成：+25 城币。")
    return true

static func begin_delivery(s: Dictionary, day: String) -> bool:
    prepare_day(s, day)
    if completed(s, "delivery") or bool(s.get("delivery_active", false)):
        return false
    s["delivery_active"] = true
    note(s, "收到配送委托：把包裹送到河边取件箱。")
    return true

static func finish_delivery(s: Dictionary, day: String) -> bool:
    prepare_day(s, day)
    if not bool(s.get("delivery_active", false)) or completed(s, "delivery"):
        return false
    if not _reward(s, 90):
        return false
    s["delivery_active"] = false
    s["daily_done"].append("delivery")
    s["deliveries"] = int(s.get("deliveries", 0)) + 1
    note(s, "河畔包裹已签收，配送工资 +90 城币。")
    return true

static func job_finish(s: Dictionary, job_id: String, place: String, correct: int, day: String) -> int:
    prepare_day(s, day)
    if place not in JOB_TASKS or correct < 0 or correct > 3:
        return 0
    if int(s.get("energy", 0)) < 12:
        return 0
    var base: int = 38 if place == "便利店" else 45
    var wage: int = base + correct * (14 if place == "便利店" else 15)
    if not CitySave.pay_job_once(s, job_id, wage):
        return 0
    s["energy"] = maxi(0, int(s["energy"]) - 12)
    s["jobs_today"] = int(s.get("jobs_today", 0)) + 1
    var skills: Dictionary = s["skills"]
    var skill: String = "service" if place == "便利店" else "barista"
    skills[skill] = mini(999, int(skills.get(skill, 0)) + 1)
    if not completed(s, "work") and _reward(s, 25):
        s["daily_done"].append("work")
        note(s, "每日首次工作额外奖励 +25 城币。")
    note(s, "%s完成三笔订单（正确 %d/3），收入 %d 城币。" % [place, correct, wage])
    return wage

static func rest(s: Dictionary, at_home: bool) -> void:
    s["energy"] = mini(100, int(s.get("energy", 50)) + (40 if at_home else 15))
    s["mood"] = mini(100, int(s.get("mood", 50)) + (8 if at_home else 10))
    note(s, "在%s休息了一会。" % ("家里" if at_home else "公园"))

static func task_line(s: Dictionary) -> String:
    var done: Array = s.get("daily_done", [])
    var status: String = "✓" if "work" in done else "○"
    var social: String = "✓" if "social" in done else "○"
    var photos: String = "✓" if "photos" in done else "○"
    return "%s 完成兼职（+25）\n%s 与居民交流（+30）\n%s 拍摄两处街景（+25）" % [status, social, photos]