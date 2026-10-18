/**
 * 类别和生活领域（照网页版 shared/src/categories.ts、server/src/db/categories.ts、steps.ts 的 categoryOf，docs/prd-daily.md）：
 * - AI 提出新活动：名称和已有类别相近就用它（「慢跑」→ 跑步）；对得上一个常见生活领域就用这个领域（没有就建上）；都不是才新建
 * - 落进「其他」的：按名称、人、东西、地方再认一次（走路 → 运动、头痛 → 健康），买东西的归购物
 * - 买的东西看得出给谁用（奶粉 → 育儿、猫粮 → 宠物）；做饭是家务、吃饭才是饮食
 * 类别表在手机上：这里新建的类别放进改动包（newCategories），手机在同一个事务里建上
 */
import { randomBytes } from 'node:crypto'
import type { Category } from './contract.ts'
import { rootCategory } from './rules.ts'

/** 一个要新建的类别（AI 提的、或者常见的生活领域） */
export interface NewCategory {
  name: string
  emoji: string
  /** 九个领域色之一（iOS 规范 01 第 3.1 节） */
  color: string
  parent?: string | null
  measure?: string
  synonyms?: string[]
}

const normalize = (s: string) => s.replace(/[\s·、，,]/g, '').toLowerCase()

/**
 * 同义词检查：名称和已有类别的名称或同义词相同、或互相包含（两个字以上），就算同一个类别。
 * 「慢跑」「晨跑」都会找到「跑步」。先找子类别（更具体），再找顶级类别
 */
export function findSimilarCategory(name: string, categories: Category[], extraSynonyms: string[] = []): Category | null {
  const words = [name, ...extraSynonyms].map(normalize).filter(Boolean)
  const same = (a: string, b: string) => a === b || (Math.min(a.length, b.length) >= 2 && (a.includes(b) || b.includes(a)))
  const ordered = [...categories].sort((a, b) => Number(!a.parent) - Number(!b.parent))
  for (const c of ordered) {
    const names = [c.name, ...c.synonyms].map(normalize)
    if (words.some((w) => names.some((n) => same(w, n)))) return c
  }
  return null
}

/**
 * 常见的生活领域和各种人的典型说法（网页版 LIFE_DOMAINS 原样，颜色换成 iOS 的九个领域色）。
 * 数组顺序就是认的顺序：越具体的越靠前（「陪孩子」先被育儿认走，「宠物医院」先被宠物认走）。
 * 颜色：规范 01 第 3.1 节「默认给」——育儿、家人朋友樱，健康砖，家务陶，出行湖，娱乐藤；
 * 规范没列的四个（M2c 定）：宠物陶、兴趣麦、购物杏、办事石
 */
export const LIFE_DOMAINS: NewCategory[] = [
  { name: '育儿', emoji: '🍼', color: 'sakura', measure: 'count', synonyms: ['带娃', '带孩子', '陪孩子', '陪娃', '亲子', '喂奶', '夜奶', '冲奶粉', '奶粉', '尿不湿', '纸尿裤', '换尿布', '哄睡', '接孩子', '送孩子', '接送孩子', '幼儿园', '辅导作业', '家长会', '绘本', '宝宝', '大宝', '小宝', '孩子'] },
  { name: '宠物', emoji: '🐕', color: 'clay', measure: 'count', synonyms: ['养宠', '萌宠', '遛狗', '喂猫', '喂狗', '铲屎', '猫砂', '狗粮', '猫粮', '猫咪', '狗狗', '宠物医院', '逗猫', '撸猫', '给狗洗澡', '给猫洗澡', '给猫', '给狗', '带狗', '带猫', '养猫', '养狗', '驱虫', '绝育'] },
  { name: '健康', emoji: '🩺', color: 'brick', measure: 'count', synonyms: ['头痛', '头疼', '感冒', '发烧', '咳嗽', '胃疼', '肚子疼', '牙疼', '不舒服', '生病', '看病', '医院', '吃药', '体检', '过敏', '身体', '血压', '血糖', '体重', '称重', '心率', '体温', '降压药', '打针', '输液', '挂号', '复查', '看牙', '理疗', '疫苗'] },
  { name: '家人朋友', emoji: '👨‍👩‍👧', color: 'sakura', measure: 'count', synonyms: ['社交', '亲友', '朋友', '家人', '聚会', '聊天', '约会', '礼物', '老公', '老婆', '儿子', '女儿', '爸爸', '妈妈', '爸妈', '父母', '爷爷', '奶奶', '外公', '外婆', '孙子', '孙女', '同学', '同事', '看望', '回老家'] },
  { name: '兴趣', emoji: '🎨', color: 'straw', measure: 'duration', synonyms: ['爱好', '书法', '毛笔字', '画画', '绘画', '素描', '吉他', '钢琴', '古筝', '尤克里里', '摄影', '拍照', '手工', '钓鱼', '下棋', '围棋', '象棋', '社团', '话剧', '插花', '烘焙', '编织', '乐高'] },
  { name: '娱乐', emoji: '🎬', color: 'wisteria', measure: 'duration', synonyms: ['休闲', '电影', '追剧', '看剧', '电视', '游戏', '打游戏', '王者', '吃鸡', '刷手机', '刷抖音', '短视频', '综艺', '演唱会', '唱歌', 'K歌', '看直播', '番剧', '刷B站'] },
  { name: '家务', emoji: '🧹', color: 'clay', measure: 'duration', synonyms: ['做家务', '打扫', '打扫卫生', '大扫除', '拖地', '扫地', '洗衣服', '晾衣服', '洗碗', '收拾', '整理房间', '做饭', '倒垃圾', '擦窗'] },
  { name: '出行', emoji: '🚗', color: 'lake', measure: 'duration', synonyms: ['交通', '开车', '通勤', '地铁', '公交', '打车', '滴滴', '出差', '旅行', '旅游', '坐飞机', '高铁', '火车', '自驾'] },
  { name: '购物', emoji: '🛒', color: 'apricot', measure: 'count', synonyms: ['买东西', '逛街', '逛商场', '超市', '网购', '买菜', '菜市场', '买衣服', '淘宝', '京东', '拼多多'] },
  { name: '办事', emoji: '📋', color: 'stone', measure: 'count', synonyms: ['杂事', '事务', '银行', '办卡', '缴费', '交费', '交电费', '电费', '水费', '燃气费', '话费', '取快递', '寄快递', '快递', '营业厅', '办证', '身份证', '护照', '签证', '社保', '医保', '公积金', '物业', '政务', '房租', '交房租', '续租'] },
]

const COLORS = ['stone', 'clay', 'apricot', 'straw', 'moss', 'lake', 'wisteria', 'sakura', 'brick']
/** AI 照网页版的 Skill 写颜色名（gray、brown……）：换成 iOS 的九个领域色 */
const WEB_COLORS: Record<string, string> = {
  gray: 'stone',
  brown: 'clay',
  orange: 'apricot',
  yellow: 'straw',
  green: 'moss',
  blue: 'lake',
  purple: 'wisteria',
  pink: 'sakura',
  red: 'brick',
}

/** 这件事按常见的生活领域能认出来吗（名称、人物、关键词都看） */
export function lifeDomainOf(words: string[], domains: NewCategory[] = LIFE_DOMAINS): NewCategory | null {
  const asCats: Category[] = domains.map((d, i) => ({ key: `domain-${i}`, name: d.name, emoji: d.emoji, color: d.color, parent: null, measure: d.measure ?? 'count', synonyms: d.synonyms ?? [], order: 0 }))
  for (const w of words) {
    const hit = findSimilarCategory(w, asCats)
    if (hit) return domains[Number(hit.key.slice(7))]!
  }
  return null
}

/** 买的东西是给孩子还是给宠物用的：只认这两个领域，别的按字面比容易误认（「身体乳」会被健康的「身体」认走） */
export const purposeDomainOf = (words: string[]) => lifeDomainOf(words, LIFE_DOMAINS.filter((d) => d.name === '育儿' || d.name === '宠物'))
export const isShoppingName = (name: string) => lifeDomainOf([name])?.name === '购物'
const SHOPPING = LIFE_DOMAINS.find((d) => d.name === '购物')!
const HOUSEWORK = LIFE_DOMAINS.find((d) => d.name === '家务')!
/** 做饭是家务、吃饭才是饮食：名称里有「吃」的说的是吃 */
export const isCookingLabel = (label: string) => !label.includes('吃') && /做饭|煮饭|烧饭|下厨|做菜|炒菜|烧菜|做[早午晚][饭餐]|做了?顿饭/.test(label)
/** 名称说的是买东西：只看开头和「买了」，不看有没有花费（「交罚款 200」不是买东西） */
export const isPurchaseLabel = (label: string) => /^(买|购|网购|囤|下单)/.test(label.trim()) || label.includes('买了')

/** 还没用过的常见领域在背景里列给 AI 看，key 写成 `domain:育儿` */
export const DOMAIN_KEY_PREFIX = 'domain:'
const existingDomain = (domain: NewCategory, cats: Category[]) => findSimilarCategory(domain.name, cats.filter((c) => !c.parent))
export const unusedDomains = (cats: Category[]) => LIFE_DOMAINS.filter((d) => !existingDomain(d, cats))
export function domainFromKey(key: string | null | undefined): NewCategory | null {
  if (!key?.startsWith(DOMAIN_KEY_PREFIX)) return null
  const name = key.slice(DOMAIN_KEY_PREFIX.length).trim()
  return LIFE_DOMAINS.find((d) => d.name === name) ?? null
}

/**
 * 整理一段话时的类别表：开头是手机发来的那份，这段话里新建的类别加进来（AI 在同一段话里接着用得上），
 * 最后放进改动包，手机照着建上
 */
export class CategoryBook {
  readonly created: Category[] = []
  constructor(private categories: Category[]) {}

  get all(): Category[] {
    return this.categories
  }

  /** 找到或建上一个生活领域：只按名称找已有的顶级类别（领域的说法很多，按说法比会认错） */
  ensureDomain(domain: NewCategory): string {
    return (existingDomain(domain, this.categories) ?? this.insert(domain)).key
  }

  /** AI 提议新建类别：名称相近的已有类别 → 能认出的生活领域 → 说法相近的已有类别 → 新建 */
  placeNew(input: NewCategory): string {
    const similar = findSimilarCategory(input.name, this.categories)
    if (similar) return similar.key
    if (!input.parent) {
      const domain = lifeDomainOf([input.name, ...(input.synonyms ?? [])])
      if (domain) return this.ensureDomain(domain)
    }
    return (findSimilarCategory(input.name, this.categories, input.synonyms ?? []) ?? this.insert(input)).key
  }

  private insert(input: NewCategory): Category {
    const parent = input.parent && this.categories.some((c) => c.key === input.parent) ? input.parent : null
    const parentColor = parent ? this.categories.find((c) => c.key === parent)?.color : undefined
    const category: Category = {
      key: `c-${randomBytes(4).toString('hex')}`,
      name: input.name.trim().slice(0, 12),
      emoji: input.emoji.trim() || '📌',
      // 子类别跟上级同色；颜色不在九色里时用石
      color: parentColor ?? (COLORS.includes(input.color) ? input.color : (WEB_COLORS[input.color] ?? 'stone')),
      parent,
      measure: input.measure?.trim() || 'duration',
      synonyms: input.synonyms ?? [],
      order: 500,
    }
    this.categories = [...this.categories, category]
    this.created.push(category)
    return category
  }
}

/** AI 给的事件：类别、提议的新类别、名称和人物东西地方 */
export interface EventCategoryHint {
  category: string
  new_category?: NewCategory | undefined
  label: string
  people?: string[] | undefined
  things?: string[] | undefined
  places?: string[] | undefined
  tags?: string[] | undefined
}

/** 定一个事件的类别（网页版 resolveEventCategory + categoryOf） */
export function resolveEventCategory(item: EventCategoryHint, book: CategoryBook): string {
  const cats = () => book.all
  const purpose = purposeDomainOf([item.label, ...(item.things ?? [])])
  // 先看用途再建类别：不留下一个空的「购物」
  if (purpose && item.new_category && !item.new_category.parent && isShoppingName(item.new_category.name)) return book.ensureDomain(purpose)
  const key = categoryOf(item, book)
  const rootName = cats().find((c) => c.key === rootCategory(key, cats()))?.name
  if (purpose && rootName === '购物') return book.ensureDomain(purpose)
  // 做饭是家务：AI 常照着「饭」放进饮食，程序挪到家务
  if (isCookingLabel(item.label) && rootCategory(key, cats()) === 'diet') return book.ensureDomain(HOUSEWORK)
  return key
}

function categoryOf(item: EventCategoryHint, book: CategoryBook): string {
  if (item.new_category) {
    const given = item.new_category.parent ?? (item.category !== 'other' ? item.category : null)
    // 上级写的是还没用过的领域（`domain:育儿`）：先把领域建上
    const givenDomain = domainFromKey(given)
    const parent = givenDomain ? book.ensureDomain(givenDomain) : given
    return book.placeNew({ ...item.new_category, parent })
  }
  // AI 选了还没用过的常见领域：由程序建上
  const chosen = domainFromKey(item.category)
  if (chosen) return book.ensureDomain(chosen)
  const known = book.all.some((c) => c.key === item.category)
  const key = known ? item.category : (findSimilarCategory(item.label, book.all)?.key ?? 'other')
  // 放进了「其他」：按名称、人物、东西、地方再找一次已有的类别；还是没有，按常见的生活领域认；买东西的归购物
  if (key === 'other') {
    const words = [item.label, ...(item.people ?? []), ...(item.things ?? []), ...(item.places ?? []), ...(item.tags ?? [])]
    const existing = words.map((w) => findSimilarCategory(w, book.all.filter((c) => c.key !== 'other'))).find(Boolean)
    if (existing) return existing.key
    const domain = lifeDomainOf(words)
    if (domain) return book.ensureDomain(domain)
    if (isPurchaseLabel(item.label)) return book.ensureDomain(SHOPPING)
    return 'other'
  }
  // 有子类别、名称又对得上某个子类别：归到子类别
  const child = findSimilarCategory(item.label, book.all.filter((c) => c.parent === key))
  return child?.key ?? key
}

/** 这段话新建了类别：已有的「其他」记录里对得上的归进来（网页版 adoptFromOther，只看背景包里的那些） */
export function adoptsFromOther(category: Category, words: string[]): boolean {
  return words.some((w) => findSimilarCategory(w, [category]))
}
