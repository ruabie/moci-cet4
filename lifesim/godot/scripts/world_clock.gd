extends RefCounted
class_name WorldClock

# World wall-clock time always follows the device's real local clock.
# Gameplay tasks never accelerate this clock.
static func snapshot() -> Dictionary:
    var d: Dictionary = Time.get_datetime_dict_from_system(false)
    return {
        "year": int(d["year"]), "month": int(d["month"]), "day": int(d["day"]),
        "weekday": int(d["weekday"]), "hour": int(d["hour"]),
        "minute": int(d["minute"]), "second": int(d["second"]),
        "unix": int(Time.get_unix_time_from_system())
    }

static func display_text() -> String:
    var d := snapshot()
    return "%04d-%02d-%02d  %02d:%02d:%02d" % [d["year"], d["month"], d["day"], d["hour"], d["minute"], d["second"]]

static func daylight() -> float:
    var d := snapshot()
    var h: float = float(d["hour"]) + float(d["minute"]) / 60.0
    # Daylight smoothly transitions at dawn and dusk.
    return clampf(minf((h - 5.0) / 2.0, (20.0 - h) / 2.0), 0.0, 1.0)

static func is_night() -> bool:
    return daylight() < 0.15
