extends RefCounted
## One catalog for simulation, shop, UI and future content.
const Content=preload("res://scripts/garden_content.gd")
const CHARACTERS = {
    "yier": {"name":"一二", "title":"甜心守护", "desc":"草莓魔杖 · 移速快\n技能治疗并击退周围敌人", "hp":90.0, "speed":205.0, "damage":1.0, "armor":0.0, "weapon":"wand", "skill":"甜心拥抱"},
    "bubu": {"name":"布布", "title":"蜂蜜先锋", "desc":"蜂蜜木勺 · 血量厚\n技能震击并获得短暂护盾", "hp":120.0, "speed":185.0, "damage":1.12, "armor":2.0, "weapon":"spoon", "skill":"熊熊守护"}
}
static var WEAPONS = {
    "wand": {"name":"草莓魔杖", "desc":"远程追踪目标 · 弹丸可弹射两个目标", "kind":"ranged", "damage":17.0, "cooldown":0.68, "range":460.0, "speed":510.0, "price":22},
    "spoon": {"name":"蜂蜜木勺", "desc":"近身横扫 · 一次击中多个敌人", "kind":"melee", "damage":28.0, "cooldown":0.95, "range":118.0, "speed":0.0, "price":22},
    "petal": {"name":"花瓣环", "desc":"环形范围攻击 · 清理身边敌人", "kind":"area", "damage":16.0, "cooldown":1.6, "range":155.0, "speed":0.0, "price":30},
    "needle": {"name":"星星连弩", "desc":"高速连射 · 暴击流派伙伴", "kind":"rapid", "damage":7.0, "cooldown":0.21, "range":390.0, "speed":620.0, "price":28}
} .merged(Content.WEAPONS)
static var ENEMIES = {
    "sprout": {"name":"迷路芽芽", "hp":27.0, "speed":66.0, "damage":9.0, "radius":17.0, "xp":2, "coin":2},
    "bee": {"name":"急急蜂", "hp":19.0, "speed":120.0, "damage":7.0, "radius":13.0, "xp":2, "coin":2},
    "mushroom": {"name":"厚帽菇", "hp":100.0, "speed":43.0, "damage":16.0, "radius":24.0, "xp":5, "coin":4},
    "acorn": {"name":"橡果投手", "hp":46.0, "speed":59.0, "damage":10.0, "radius":18.0, "xp":4, "coin":3},
    "boss": {"name":"贪吃南瓜王", "hp":2400.0, "speed":43.0, "damage":22.0, "radius":52.0, "xp":40, "coin":40}
} .merged(Content.ENEMIES)
const UPGRADES = {
    "heart": {"name":"软软棉花糖", "desc":"最大生命 +20，并恢复 25 生命", "stat":"max_hp", "value":20.0, "price":18, "icon":"ui_upgrade_heart"},
    "power": {"name":"草莓果酱", "desc":"全部武器伤害 +18%", "stat":"damage", "value":0.18, "price":24, "icon":"ui_upgrade_power"},
    "haste": {"name":"晨露薄荷", "desc":"攻击速度 +15%", "stat":"attack_speed", "value":0.15, "price":22, "icon":"ui_upgrade_haste"},
    "speed": {"name":"散步小靴", "desc":"移动速度 +18", "stat":"speed", "value":18.0, "price":18, "icon":"ui_upgrade_speed"},
    "crit": {"name":"幸运星糖", "desc":"暴击率 +8% · 暴击伤害 2 倍", "stat":"crit", "value":0.08, "price":22, "icon":"ui_upgrade_crit"},
    "armor": {"name":"蜂蜜围巾", "desc":"护甲 +2 · 降低受到的伤害", "stat":"armor", "value":2.0, "price":20, "icon":"ui_upgrade_armor"},
    "magnet": {"name":"口袋小花", "desc":"拾取范围 +40", "stat":"magnet", "value":40.0, "price":16, "icon":"ui_upgrade_magnet"},
    "builder": {"name":"园艺手册","desc":"建筑伤害与维修 +20%","stat":"build_power","value":0.2,"price":24,"icon":"ui_upgrade_builder"},
    "area": {"name":"盛放花苞","desc":"范围伤害半径 +12%","stat":"area","value":0.12,"price":24,"icon":"ui_upgrade_area"},
    "cooldown": {"name":"清晨铃兰","desc":"技能冷却缩短 10%（最低 4 秒）","stat":"cooldown_bonus","value":0.1,"price":26,"icon":"ui_upgrade_cooldown"},
    "regen": {"name":"温热牛奶", "desc":"每秒恢复 0.7 生命", "stat":"regen", "value":0.7, "price":24, "icon":"ui_upgrade_regen"}
}
const WAVE_COUNT = 6
const COSTUMES={"plain":"原本的我们","casual":"暖暖日常","garden":"花园园丁","adventure":"森林探险","pajamas":"晚安小熊","spring":"春日花语","magic":"莓园魔法"}

static func costume_sprite(character: String, outfit: String, view: String="front") -> String:
    return character+"_"+(outfit+"_" if outfit!="plain" and COSTUMES.has(outfit) else "")+view
const ATTACK_MOTION = {
    "spoon":{"windup":0.13,"recover":0.20,"kick":5.0},
    "wand":{"windup":0.09,"recover":0.13,"kick":3.0},
    "needle":{"windup":0.033,"recover":0.067,"kick":2.0},
    "petal":{"windup":0.15,"recover":0.22,"kick":1.0}
}
const WAVE_SECONDS = [30.0, 35.0, 40.0, 45.0, 50.0, 120.0]
const ROUND_COUNT = 3
const BOSS_KINDS = ["snail","queen_wasp","moon_treant"]
const ARENA = Vector2(2200, 1500)
const OBSTACLES = [Vector3(420,320,33),Vector3(1770,330,37),Vector3(390,1180,34),Vector3(1790,1170,32),Vector3(730,520,32),Vector3(1460,1000,35),Vector3(1550,500,38),Vector3(720,1060,31)]

static func xp_needed(level: int) -> int:
    return 14 + level * 9
