extends RefCounted
## Shared, data-only content for authoritative rules and the supply station.
const WEAPONS={
"shears":{"name":"园艺剪","desc":"快速近战；第三击双倍，双持第三击扩大范围","kind":"melee","damage":15.0,"cooldown":0.35,"range":105.0,"speed":0.0,"price":28},
"shovel":{"name":"回旋铲","desc":"往返均伤害；双持额外发射一把","kind":"return","damage":22.0,"cooldown":1.2,"range":440.0,"speed":380.0,"price":34},
"honey":{"name":"蜂蜜喷枪","desc":"叠加黏糊减速；遇火焰产生爆燃","kind":"ranged","damage":7.0,"cooldown":0.25,"range":300.0,"speed":400.0,"price":32},
"bubble":{"name":"泡泡棒","desc":"普通怪概率被困；泡泡破裂范围伤害","kind":"ranged","damage":12.0,"cooldown":0.7,"range":400.0,"speed":320.0,"price":32},
"star_wand":{"name":"许愿星杖","desc":"目标处预警后落星，范围高伤害","kind":"star","damage":62.0,"cooldown":2.1,"range":480.0,"speed":0.0,"price":38},
"radish":{"name":"大萝卜锤","desc":"高伤害、低攻速；砸飞敌人撞伤怪群","kind":"melee","damage":58.0,"cooldown":1.6,"range":130.0,"speed":0.0,"price":38},
"thread":{"name":"红线纺锤","desc":"连接两只敌人，另一只分担 45% 伤害","kind":"ranged","damage":11.0,"cooldown":0.8,"range":450.0,"speed":440.0,"price":35},
"moon":{"name":"月牙蓄能刃","desc":"攻击积累能量；满能量释放大范围斩击","kind":"melee","damage":22.0,"cooldown":0.6,"range":120.0,"speed":0.0,"price":38},
"flame":{"name":"向日葵火枪","desc":"灼烧；引爆蜂蜜，适合范围流派","kind":"ranged","damage":10.0,"cooldown":0.32,"range":330.0,"speed":450.0,"price":34},
"bee_blade":{"name":"蜜晶短剑","desc":"连斩并施加蜂毒","kind":"melee","damage":24.0,"cooldown":0.46,"range":112.0,"speed":0.0,"price":42,"round":2},
"hive_bow":{"name":"蜂巢弓","desc":"同时射出两支蜜箭","kind":"ranged","damage":18.0,"cooldown":0.65,"range":460.0,"speed":520.0,"price":44,"round":2},
"prism_staff":{"name":"月棱星杖","desc":"星落后分裂为三枚光弹","kind":"star","damage":75.0,"cooldown":1.9,"range":500.0,"speed":0.0,"price":52,"round":3},
"root_hammer":{"name":"古根巨锤","desc":"大范围击退并眩晕","kind":"melee","damage":88.0,"cooldown":1.75,"range":150.0,"speed":0.0,"price":52,"round":3}
}
const GEAR={
"magnet_cap":{"name":"磁力帽","desc":"拾取范围 +80","slot":"head","price":25,"rarity":1},
"mechanic":{"name":"维修护目镜","desc":"建筑修复与治疗效率 +50%","slot":"head","price":28,"rarity":1},
"first_guard":{"name":"花瓣护冠","desc":"每小波第一次受伤完全格挡","slot":"head","price":32,"rarity":2},
"thorn_vest":{"name":"荆棘背心","desc":"护甲 +3；近身受击反伤","slot":"body","price":30,"rarity":1},
"dash_boots":{"name":"弹簧鞋","desc":"右侧冲刺按钮，冷却 4 秒","slot":"feet","price":30,"rarity":1},
"runner":{"name":"薄荷跑鞋","desc":"持续移动逐渐加速，停下重置","slot":"feet","price":28,"rarity":1},
"skill_stone":{"name":"技多不压身石","desc":"散发着淡淡紫光的小石头，似乎可以让佩戴者领悟技多不压身的道理。主动道具槽 +1","slot":"charm","price":55,"rarity":3},
"lucky":{"name":"四叶草","desc":"刷新时高品质商品更容易出现","slot":"charm","price":30,"rarity":2},
"couple":{"name":"同心坠","desc":"两人靠近时双方每秒恢复 2 生命","slot":"charm","price":30,"rarity":2},
"shock":{"name":"回响贝壳","desc":"受伤释放冲击波，冷却 6 秒","slot":"charm","price":32,"rarity":2},
"familiar":{"name":"小星灵","desc":"悬浮环绕；周期伤害附近敌人","slot":"charm","price":36,"rarity":2},
"lantern":{"name":"萤火灯","desc":"提供光源、拾取范围 +100，吸引掉落物","slot":"charm","price":26,"rarity":1},
"purse":{"name":"存钱袋","desc":"大回合结束按未花费资源收益 10%，最多 50","slot":"charm","price":24,"rarity":1},
"hive_helm":{"name":"蜂纹头冠","desc":"护甲 +4；蜂毒抗性","slot":"head","price":45,"rarity":2,"round":2},
"petal_mantle":{"name":"花瓣披风","desc":"受击后短暂加速并恢复生命","slot":"body","price":46,"rarity":2,"round":2},
"moon_boots":{"name":"月行靴","desc":"移动速度 +28；冲刺冷却更短","slot":"feet","price":48,"rarity":3,"round":3},
"root_charm":{"name":"古根护符","desc":"每秒恢复 1.5 生命；建筑耐久提高","slot":"charm","price":52,"rarity":3,"round":3}
}
const ITEMS={
"world":{"name":"世界","desc":"金黄色的概率点云，似乎没有实体但却可以拿起。一次性：只有使用者行动 5 秒","price":120,"rarity":4},
"bomb":{"name":"大甜莓炸弹","desc":"前方爆炸，巨额伤害所有实体并破坏地形；小心友伤","price":25,"rarity":2},
"heal_seed":{"name":"治疗种子","desc":"放置 8 秒治疗区域，恢复玩家和大甜莓","price":18,"rarity":1},
"fence_kit":{"name":"速生围栏","desc":"前方生成三段临时围栏，持续 20 秒","price":18,"rarity":1},
"decoy":{"name":"甜莓诱饵","desc":"吸引怪物；5 秒后爆炸","price":20,"rarity":1},
"home":{"name":"归巢石","desc":"立刻传送到大甜莓附近","price":16,"rarity":1},
"vacuum":{"name":"花园吸尘器","desc":"收集附近掉落，3 秒牵引轻型敌人","price":18,"rarity":1},
"mirror":{"name":"镜像手套","desc":"10 秒内复制左手攻击","price":26,"rarity":2},
"freeze":{"name":"冰冻沙漏","desc":"普通怪停止 4 秒，Boss 只减速","price":25,"rarity":2},
"dice":{"name":"商人骰子","desc":"补给站免费重抽全部商品","price":12,"rarity":1},
"rocket":{"name":"小火箭","desc":"乘坐火箭高速冲锋 2 秒，撞伤沿途敌人","price":26,"rarity":2},
"banana":{"name":"香蕉皮","desc":"放置滑倒陷阱，Boss 也短暂失衡","price":14,"rarity":1},
"nectar":{"name":"蜂蜜甘露","desc":"立刻恢复 35% 生命并解除减速","price":27,"rarity":2,"round":2},
"thorn_orb":{"name":"刺球弹","desc":"投掷会爆裂的刺球并定身敌人","price":30,"rarity":2,"round":2},
"moonbell":{"name":"月光铃","desc":"清除范围敌弹，给予队友护盾","price":38,"rarity":3,"round":3},
"rescue_flower":{"name":"重生花","desc":"立刻扶起最近倒地队友并回复生命","price":42,"rarity":3,"round":3}
}
const BUILDINGS={
"fence":{"name":"荆棘围栏","desc":"阻挡、低耐久；接触攻击反伤","hp":130.0,"range":40.0,"cooldown":1.0,"damage":12.0,"price":12},
"turret":{"name":"豌豆连射塔","desc":"快速自动攻击","hp":170.0,"range":350.0,"cooldown":0.4,"damage":13.0,"price":32},
"mortar":{"name":"莓果迫击炮","desc":"慢速攻击、延迟范围爆炸","hp":165.0,"range":440.0,"cooldown":2.4,"damage":48.0,"price":38},
"frost":{"name":"冰花","desc":"周期降低附近敌人速度","hp":135.0,"range":190.0,"cooldown":1.0,"damage":0.0,"price":25},
"fountain":{"name":"治愈花泉","desc":"恢复附近玩家、核心与建筑","hp":150.0,"range":200.0,"cooldown":1.0,"damage":4.0,"price":34},
"scarecrow":{"name":"稻草小熊","desc":"高仇恨，吸引附近敌人","hp":300.0,"range":380.0,"cooldown":1.0,"damage":0.0,"price":24},
"spikes":{"name":"地刺花圃","desc":"敌人走过持续受伤","hp":110.0,"range":54.0,"cooldown":0.6,"damage":22.0,"price":20},
"spring":{"name":"弹簧叶","desc":"将敌人弹飞，撞伤其他怪物","hp":130.0,"range":70.0,"cooldown":1.5,"damage":10.0,"price":24},
"repair":{"name":"修理机器人","desc":"周期维修附近损坏建筑","hp":130.0,"range":230.0,"cooldown":1.0,"damage":8.0,"price":30},
"trap":{"name":"藤蔓捕兽夹","desc":"一次触发；普通与精英定身 4 秒，Boss 0.6 秒","hp":90.0,"range":58.0,"cooldown":0.2,"damage":20.0,"price":16},
"beehive":{"name":"蜂巢炮塔","desc":"三连发蜜针，使敌人减速","hp":185.0,"range":390.0,"cooldown":1.2,"damage":12.0,"price":42,"round":2},
"wall":{"name":"加固花墙","desc":"高耐久保护核心","hp":430.0,"range":35.0,"cooldown":1.0,"damage":0.0,"price":32,"round":2},
"moon_lantern":{"name":"月光灯塔","desc":"清除迷雾，持续修复附近建筑","hp":190.0,"range":250.0,"cooldown":1.0,"damage":7.0,"price":46,"round":3},
"root_tower":{"name":"古根塔","desc":"藤蔓缠绕和范围攻击","hp":240.0,"range":300.0,"cooldown":1.9,"damage":43.0,"price":54,"round":3}
}
const CORE_UPGRADES={
"core_hp":{"name":"饱满果肉","desc":"核心最大生命 +150 并恢复 150","price":35},
"core_regen":{"name":"甘露循环","desc":"核心每秒恢复 +1.2","price":35},
"core_armor":{"name":"坚韧果皮","desc":"核心护甲 +3","price":35},
"core_aura":{"name":"甜心光环","desc":"核心周围玩家每秒回血 +1.5","price":40},
"core_repair":{"name":"滋养根系","desc":"核心周围建筑每秒修复 +2","price":40},
"core_shield":{"name":"糖晶护盾","desc":"每小波核心获得 100 点护盾","price":40},
"core_guard":{"name":"共生果园","desc":"附近建筑承受伤害降低 20%（最多 60%）","price":40},
"core_attack":{"name":"莓果发射","desc":"核心周期自动攻击附近敌人","price":45},
"core_vine":{"name":"荆棘根须","desc":"靠近核心的敌人持续受到范围伤害","price":45}
}
const ENEMIES={
"charger":{"name":"冲锋甲虫","hp":55.0,"speed":65.0,"damage":15.0,"radius":20.0,"xp":4,"coin":3},
"mole":{"name":"钻地鼹鼠","hp":55.0,"speed":80.0,"damage":12.0,"radius":18.0,"xp":4,"coin":3},
"termite":{"name":"拆家白蚁","hp":65.0,"speed":60.0,"damage":22.0,"radius":18.0,"xp":4,"coin":3},
"crow":{"name":"偷莓乌鸦","hp":34.0,"speed":115.0,"damage":10.0,"radius":16.0,"xp":3,"coin":3},
"shield_bug":{"name":"叶盾甲虫","hp":95.0,"speed":52.0,"damage":14.0,"radius":22.0,"xp":5,"coin":4},
"bomber":{"name":"爆爆菇","hp":40.0,"speed":65.0,"damage":24.0,"radius":18.0,"xp":4,"coin":3},
"healer":{"name":"治愈菇","hp":65.0,"speed":42.0,"damage":8.0,"radius":20.0,"xp":5,"coin":4},
"mimic":{"name":"模仿软泥","hp":70.0,"speed":57.0,"damage":12.0,"radius":20.0,"xp":5,"coin":4},
"moth":{"name":"迷雾蛾","hp":42.0,"speed":60.0,"damage":8.0,"radius":18.0,"xp":4,"coin":3},
"leech":{"name":"寄生藤虫","hp":45.0,"speed":70.0,"damage":5.0,"radius":15.0,"xp":4,"coin":3},
"snail":{"name":"苔壳巨蜗","hp":1700.0,"speed":38.0,"damage":28.0,"radius":58.0,"xp":45,"coin":55},
"wasp":{"name":"蜜刃蜂","hp":55.0,"speed":140.0,"damage":14.0,"radius":15.0,"xp":5,"coin":4},
"thornling":{"name":"冲刺刺芽","hp":85.0,"speed":87.0,"damage":20.0,"radius":18.0,"xp":6,"coin":5,"drop":"thorn_orb","drop_chance":.06},
"hedgehog":{"name":"刺背獾","hp":155.0,"speed":58.0,"damage":22.0,"radius":25.0,"xp":8,"coin":6},
"seedcaster":{"name":"荚弹射手","hp":80.0,"speed":68.0,"damage":16.0,"radius":19.0,"xp":6,"coin":5},
"shade":{"name":"暮影幽芽","hp":75.0,"speed":124.0,"damage":20.0,"radius":19.0,"xp":7,"coin":6},
"crystal_crab":{"name":"水晶钳蟹","hp":205.0,"speed":47.0,"damage":28.0,"radius":26.0,"xp":10,"coin":8},
"spore_bat":{"name":"孢子夜蝠","hp":65.0,"speed":145.0,"damage":18.0,"radius":17.0,"xp":8,"coin":6,"drop":"moonbell","drop_chance":.04},
"root_brute":{"name":"腐根巨灵","hp":270.0,"speed":52.0,"damage":36.0,"radius":30.0,"xp":12,"coin":9,"drop":"rescue_flower","drop_chance":.035},
"queen_wasp":{"name":"蜂巢女王","hp":2700.0,"speed":66.0,"damage":31.0,"radius":63.0,"xp":70,"coin":80,"drop":"nectar"},
"moon_treant":{"name":"月冠古树","hp":3500.0,"speed":48.0,"damage":39.0,"radius":72.0,"xp":95,"coin":105,"drop":"moonbell"}
}
const SKILL_UPGRADES={"skill_power":{"name":"甜莓共鸣","desc":"角色技能伤害与治疗提高 25%","price":0,"rarity":3,"icon":"ui_skill"},"skill_haste":{"name":"花园节拍","desc":"角色技能冷却缩短 18%","price":0,"rarity":3,"icon":"ui_upgrade_haste"}}
const INTEL=["东侧怪潮 · 飞行乌鸦直扑大甜莓","拆家白蚁增多 · 炮台需要维修与保护","远程投手与治愈菇 · 优先突破后排","地下鼹鼠来袭 · 核心附近留守","高速冲锋与叶盾精英 · 绕背并利用障碍","迷雾与寄生藤虫 · 携带光源、清理炮台周边","蜂群突袭 · 蜜刃蜂与刺芽从两翼包抄","荚弹压制 · 优先清除远程射手","刺背獾推进 · 建造花墙守护核心","女王侦察兵 · 蜂巢塔可压制蜂群","暮影潜袭 · 月光灯塔揭示幽影","晶蟹结阵 · 从侧面进攻其弱点","夜蝠孢子雨 · 警惕连续远程攻击","腐根巨灵拆墙 · 保留修复资源"]
static func category(key: String) -> String:
    if GEAR.has(key): return "装备" if GEAR[key].slot!="charm" else "饰品"
    if ITEMS.has(key): return "道具"
    if BUILDINGS.has(key): return "建筑"
    if CORE_UPGRADES.has(key): return "核心"
    if SKILL_UPGRADES.has(key): return "技能"
    return "武器"
static func data(key: String) -> Dictionary:
    for table in [GEAR,ITEMS,BUILDINGS,CORE_UPGRADES,SKILL_UPGRADES,WEAPONS]:
        if table.has(key): return table[key]
    return {}
