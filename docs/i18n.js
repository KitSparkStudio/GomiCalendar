/**
 * ゴミログ docs — 5 语言切换（ja / en / zh-Hans / ko / vi）
 * URL: ?lang=en | 浏览器语言自动匹配 | 默认 ja
 */
(function () {
  /** 顶部切换栏顺序：日本語 | English | 简体中文 | 한국어 | Tiếng Việt */
  const SUPPORTED = ["ja", "en", "zh-Hans", "ko", "vi"];
  const LABELS = {
    ja: "日本語",
    en: "English",
    "zh-Hans": "简体中文",
    ko: "한국어",
    vi: "Tiếng Việt",
  };

  function normalize(raw) {
    if (!raw) return null;
    const s = String(raw).trim().replace("_", "-");
    const lower = s.toLowerCase();
    if (lower === "zh-cn" || lower === "zh-hans" || lower === "zh") return "zh-Hans";
    if (lower.startsWith("ja")) return "ja";
    if (lower.startsWith("en")) return "en";
    if (lower.startsWith("ko")) return "ko";
    if (lower.startsWith("vi")) return "vi";
    if (SUPPORTED.includes(s)) return s;
    return null;
  }

  function detectLang() {
    const params = new URLSearchParams(window.location.search);
    const fromUrl = normalize(params.get("lang"));
    if (fromUrl) return fromUrl;
    const stored = normalize(localStorage.getItem("gomilog_docs_lang"));
    if (stored) return stored;
    const nav = normalize(navigator.language || (navigator.languages && navigator.languages[0]));
    return nav || "ja";
  }

  function setLang(code) {
    const lang = normalize(code) || "ja";
    localStorage.setItem("gomilog_docs_lang", lang);
    const url = new URL(window.location.href);
    url.searchParams.set("lang", lang);
    window.history.replaceState({}, "", url);
    document.documentElement.lang = lang === "zh-Hans" ? "zh-Hans" : lang;
    applyPage(lang);
    highlightSwitcher(lang);
  }

  function t(dict, lang, key) {
    const row = dict[key];
    if (!row) return key;
    return row[lang] || row.ja || row.en || key;
  }

  function applyAttrs(root, dict, lang) {
    root.querySelectorAll("[data-i18n]").forEach((el) => {
      const key = el.getAttribute("data-i18n");
      const val = t(dict, lang, key);
      if (el.tagName === "INPUT" || el.tagName === "TEXTAREA") {
        el.value = val;
      } else {
        el.textContent = val;
      }
    });
    root.querySelectorAll("[data-i18n-html]").forEach((el) => {
      const key = el.getAttribute("data-i18n-html");
      el.innerHTML = t(dict, lang, key);
    });
    const titleKey = document.body.getAttribute("data-i18n-title");
    if (titleKey) document.title = t(dict, lang, titleKey);
    const descKey = document.body.getAttribute("data-i18n-desc");
    if (descKey) {
      const meta = document.querySelector('meta[name="description"]');
      if (meta) meta.setAttribute("content", t(dict, lang, descKey));
    }
  }

  function highlightSwitcher(lang) {
    document.querySelectorAll(".lang-btn").forEach((btn) => {
      btn.classList.toggle("active", btn.dataset.lang === lang);
    });
  }

  function mountSwitcher(container) {
    if (!container) return;
    container.innerHTML = "";
    const wrap = document.createElement("div");
    wrap.className = "lang-switcher";
    wrap.setAttribute("role", "navigation");
    wrap.setAttribute("aria-label", "Language");
    SUPPORTED.forEach((code, i) => {
      if (i > 0) {
        const sep = document.createElement("span");
        sep.className = "lang-sep";
        sep.textContent = "|";
        wrap.appendChild(sep);
      }
      const btn = document.createElement("button");
      btn.type = "button";
      btn.className = "lang-btn";
      btn.dataset.lang = code;
      btn.textContent = LABELS[code];
      btn.addEventListener("click", () => setLang(code));
      wrap.appendChild(btn);
    });
    container.appendChild(wrap);
  }

  // ——— index.html ———
  const INDEX = {
    title: {
      ja: "ゴミログ · KitSpark Studio",
      en: "GomiLog · KitSpark Studio",
      "zh-Hans": "ゴミログ · KitSpark Studio",
      ko: "ゴミ로그 · KitSpark Studio",
      vi: "GomiLog · KitSpark Studio",
    },
    desc: {
      ja: "ゴミログ — 日本全国のごみ収集カレンダー。市区町村の自動判定、カスタム収集日、ウィジェット＆ライブアクティビティ対応。",
      en: "GomiLog — Japan-wide trash collection calendar. Auto district matching, custom schedules, widgets & Live Activities.",
      "zh-Hans": "ゴミログ — 日本全国垃圾收集日历。自动匹配市区町村、自定义收集日、小组件与灵动岛实时活动。",
      ko: "ゴミ로그 — 일본 전국 쓰레기 수거 캘린더. 시구정촌 자동 매칭, 맞춤 일정, 위젯·라이브 액티비티.",
      vi: "GomiLog — lịch thu rác toàn Nhật. Ghép quận tự động, lịch tùy chỉnh, widget & Live Activity.",
    },
    nav_demo: { ja: "デモ", en: "Demo", "zh-Hans": "演示", ko: "데모", vi: "Demo" },
    nav_features: { ja: "機能", en: "Features", "zh-Hans": "功能", ko: "기능", vi: "Tính năng" },
    nav_guide: { ja: "使い方", en: "How to", "zh-Hans": "用法", ko: "사용법", vi: "Cách dùng" },
    nav_support: { ja: "サポート", en: "Support", "zh-Hans": "支持", ko: "지원", vi: "Hỗ trợ" },
    nav_privacy: { ja: "プライバシー", en: "Privacy", "zh-Hans": "隐私", ko: "개인정보", vi: "Quyền riêng tư" },
    pill: {
      ja: "iOS · Widget · Live Activity",
      en: "iOS · Widget · Live Activity",
      "zh-Hans": "iOS · 小组件 · Live Activity",
      ko: "iOS · Widget · Live Activity",
      vi: "iOS · Widget · Live Activity",
    },
    hero_title: { ja: "ゴミログ", en: "GomiLog", "zh-Hans": "ゴミログ", ko: "ゴミ로그", vi: "GomiLog" },
    hero_lead: {
      ja: "KitSpark Studio が届ける、在日外国人にもわかりやすい日本のごみ収集カレンダー。全国 1,400 以上の市区町村に対応し、現在地からエリアを自動判定。収集日カスタムは無料。Pro（買い切り・永久解放）で解放：① 多地区管理（自宅＋会社／実家）② 中サイズ／ロック画面ウィジェット（7日一覧＋ワンタップ打刻）③ ダイナミックアイランド＆ロック画面のリアルタイムカウントダウン。価格は App Store の表示に従います。",
      en: "KitSpark Studio’s Japan trash calendar—clear for residents and newcomers. 1,400+ municipalities, auto area detection from location. Custom collection days are free. Pro (one-time purchase · forever unlock) includes: ① multi-district management (home + work / parents) ② medium & Lock Screen widgets (7-day overview + one-tap check-in) ③ Dynamic Island & Lock Screen live countdown. Price is shown live in the App Store.",
      "zh-Hans": "KitSpark Studio 打造的日本垃圾收集日历，在日外国人也能轻松使用。覆盖全国 1,400+ 市区町村，可按当前位置自动匹配。自定义收集日免费。Pro（一次性买断・永久解锁）包含：① 多地区管理（自宅 + 公司 / 父母家）② 中号与锁屏小组件（7日全览 + 一键打卡）③ 灵动岛与锁屏实时倒计时。具体价格以 App Store 实时显示为准。",
      ko: "KitSpark Studio의 일본 쓰레기 수거 캘린더. 거주 외국인도 쉽게. 전국 1,400+ 시구정촌, 현재 위치로 자동 매칭. 맞춤 수거일은 무료. Pro(일회 구매 · 영구 해제)로: ① 다중 지역 관리(자택+회사/본가) ② 중형·잠금화면 위젯(7일 전체 보기+원탭 체크인) ③ 다이나믹 아일랜드·잠금화면 실시간 카운트다운. 가격은 App Store 실시간 표시를 따릅니다.",
      vi: "Lịch thu rác Nhật Bản từ KitSpark Studio—dễ hiểu cho người nước ngoài. 1.400+ đô thị, tự nhận khu vực theo vị trí. Ngày thu tùy chỉnh miễn phí. Pro (mua một lần · mở khóa vĩnh viễn): ① quản lý đa khu vực (nhà + công ty / nhà bố mẹ) ② widget vừa & khóa (tóm tắt 7 ngày + check-in một chạm) ③ đếm ngược Live trên Dynamic Island & màn hình khóa. Giá theo hiển thị thời gian thực trên App Store.",
    },
    cta_demo: { ja: "デモを見る", en: "See demo", "zh-Hans": "查看演示", ko: "데모 보기", vi: "Xem demo" },
    cta_support: { ja: "サポートとプライバシー", en: "Support & privacy", "zh-Hans": "支持与隐私", ko: "지원·개인정보", vi: "Hỗ trợ & quyền riêng tư" },
    demo_menubar: {
      ja: "ゴミログ デモ — 曜日をタップして収集区分をプレビュー",
      en: "GomiLog demo — tap weekdays to preview categories",
      "zh-Hans": "ゴミログ 演示 — 点按星期预览垃圾分类",
      ko: "ゴミ로그 데모 — 요일을 눌러 분류 미리보기",
      vi: "Demo GomiLog — chạm thứ để xem loại rác",
    },
    demo_week_title: { ja: "今週の収集", en: "This week", "zh-Hans": "本周收集", ko: "이번 주 수거", vi: "Thu tuần này" },
    demo_tap_hint: { ja: "タップで区分を切替", en: "Tap to switch category", "zh-Hans": "点按切换分类", ko: "탭하여 분류 전환", vi: "Chạm để đổi loại" },
    demo_selected: { ja: "選択中", en: "Selected", "zh-Hans": "当前", ko: "선택", vi: "Đang chọn" },
    demo_bag: { ja: "指定袋", en: "Bag type", "zh-Hans": "指定袋", ko: "지정 봉투", vi: "Túi quy định" },
    demo_deadline: { ja: "締切目安", en: "Deadline", "zh-Hans": "截止参考", ko: "마감 기준", vi: "Hạn tham khảo" },
    demo_cats: { ja: "ごみの区分", en: "Waste types", "zh-Hans": "垃圾分类", ko: "쓰레기 분류", vi: "Loại rác" },
    demo_reset: { ja: "デモをリセット", en: "Reset demo", "zh-Hans": "重置演示", ko: "데모 초기화", vi: "Đặt lại demo" },
    demo_note: {
      ja: "デモはページ内のプレビューのみです。正式アプリでは端末と個人 iCloud にのみ保存され、位置情報は市区町村マッチング以外に使いません。",
      en: "This is an on-page preview only. In the app, data stays on device and your personal iCloud—location is used only for city matching.",
      "zh-Hans": "本页仅为演示预览。正式 App 中数据仅保存在本机与个人 iCloud；位置信息仅用于匹配市区町村。",
      ko: "페이지 미리보기입니다. 앱에서는 기기와 개인 iCloud에만 저장되며, 위치는 시구정촌 매칭에만 사용합니다.",
      vi: "Chỉ là bản xem trước trên trang. Trong app, dữ liệu chỉ ở máy và iCloud cá nhân—vị trí chỉ để khớp đô thị.",
    },
    features_h2: { ja: "コア機能", en: "Core features", "zh-Hans": "核心功能", ko: "핵심 기능", vi: "Tính năng cốt lõi" },
    f1_t: { ja: "全国 1,400+ 市区町村", en: "1,400+ municipalities", "zh-Hans": "全国 1,400+ 市区町村", ko: "전국 1,400+ 시구정촌", vi: "1.400+ đô thị toàn quốc" },
    f1_p: {
      ja: "47 都道府県・全市区町村カタログから検索。主要都市は詳細カレンダー、その他は標準テンプレートで曜日を調整できます。",
      en: "Search all 47 prefectures. Major cities include detailed calendars; others use an editable standard template.",
      "zh-Hans": "可从 47 都道府县全目录检索。主要城市提供详细日历，其余可用标准模板调整星期。",
      ko: "47 도도부현 전체 검색. 주요 도시는 상세 캘린더, 그 외는 표준 템플릿으로 요일 조정.",
      vi: "Tìm trong 47 tỉnh. Thành phố lớn có lịch chi tiết; nơi khác dùng mẫu chuẩn chỉnh được thứ.",
    },
    f2_t: { ja: "現在地から即カレンダー", en: "Calendar from location", "zh-Hans": "按当前位置匹配日历", ko: "현재 위치로 즉시 캘린더", vi: "Lịch từ vị trí hiện tại" },
    f2_p: {
      ja: "GPS＋日本語住所解析（ja_JP）で都道府県・市区町村を自動マッチ。IP ずれに頼らない、ワンタップ設定。",
      en: "GPS + Japanese address parsing (ja_JP) matches your prefecture/city—one tap, no IP guesswork.",
      "zh-Hans": "GPS + 日语地址解析（ja_JP）自动匹配都道府县/市区町村，一键完成，不依赖 IP 猜测。",
      ko: "GPS+일본어 주소 해석(ja_JP)으로 도도부현·시구정촌 자동 매칭. IP 추정 없이 원탭.",
      vi: "GPS + phân tích địa chỉ tiếng Nhật (ja_JP) khớp tỉnh/thành—một chạm, không đoán IP.",
    },
    f3_t: { ja: "収集日カスタム", en: "Custom collection days", "zh-Hans": "自定义收集日", ko: "수거일 맞춤", vi: "Ngày thu tùy chỉnh" },
    f3_p: {
      ja: "町丁目やマンション規定と違う場合も、「収集日カスタム」で周期・臨時日を自由に上書き。ホームとウィジェットへ即反映。",
      en: "Override cycles and temporary days when your building differs—updates home and widgets instantly. Free.",
      "zh-Hans": "与町丁目或公寓规定不一致时，可用「自定义收集日」覆盖周期与临时日，首页与小组件即时刷新。免费。",
      ko: "동네·아파트 규정과 다를 때 주기·임시일을 덮어쓰기. 홈·위젯에 즉시 반영. 무료.",
      vi: "Khi khác quy định khu/nhà: ghi đè chu kỳ & ngày tạm—cập nhật home & widget ngay. Miễn phí.",
    },
    f4_t: { ja: "ウィジェット＆ライブアクティビティ", en: "Widgets & Live Activities", "zh-Hans": "小组件与实时活动", ko: "위젯·라이브 액티비티", vi: "Widget & Live Activity" },
    f4_p: {
      ja: "ホーム画面の基本ウィジェットは無料。Pro（買い切り・永久解放）で次を解放：① 多地区管理（自宅＋会社／実家）② 中サイズ／ロック画面ウィジェット（7日一覧＋ワンタップ打刻）③ ダイナミックアイランド＆ロック画面のリアルタイムカウントダウン。サブスクリプションはありません。価格は App Store 表示に従います。",
      en: "Basic Home widgets are free. Pro (one-time purchase · forever) unlocks: ① multi-district management (home + work / parents) ② medium & Lock Screen widgets (7-day overview + one-tap check-in) ③ Dynamic Island & Lock Screen live countdown. No subscription. Price is shown live in the App Store.",
      "zh-Hans": "主屏幕基础小组件免费。Pro（一次性买断・永久解锁）：① 多地区管理（自宅 + 公司 / 父母家）② 中号与锁屏小组件（7日全览 + 一键打卡）③ 灵动岛与锁屏实时倒计时。无订阅。具体价格以 App Store 实时显示为准。",
      ko: "기본 홈 위젯은 무료. Pro(일회 구매 · 영구 해제): ① 다중 지역 관리(자택+회사/본가) ② 중형·잠금화면 위젯(7일 전체 보기+원탭 체크인) ③ 다이나믹 아일랜드·잠금화면 실시간 카운트다운. 구독 없음. 가격은 App Store 실시간 표시를 따릅니다.",
      vi: "Widget Home cơ bản miễn phí. Pro (mua một lần · mở khóa vĩnh viễn): ① quản lý đa khu vực (nhà + công ty / nhà bố mẹ) ② widget vừa & khóa (tóm tắt 7 ngày + check-in một chạm) ③ đếm ngược Live trên Dynamic Island & màn hình khóa. Không đăng ký. Giá theo App Store.",
    },
    price_tag: {
      ja: "無料ダウンロード ＋ Pro 買い切り・永久解放",
      en: "Free download + Pro one-time purchase",
      "zh-Hans": "免费下载 + Pro 一次买断・永久解锁",
      ko: "무료 다운로드 + Pro 일회 구매 · 영구",
      vi: "Tải miễn phí + Pro mua một lần · vĩnh viễn",
    },
    guide_h2: { ja: "使い方（かんたん 3 ステップ）", en: "How to use (3 steps)", "zh-Hans": "用法（三步上手）", ko: "사용법 (3단계)", vi: "Cách dùng (3 bước)" },
    g1_t: { ja: "1. 地区を決める", en: "1. Set your area", "zh-Hans": "1. 设定地区", ko: "1. 지역 설정", vi: "1. Chọn khu vực" },
    g1_p: {
      ja: "「現在地から自動設定」を押すか、都道府県 → 市区町村を検索。見つからない場合は手動入力も可能です。",
      en: "Tap auto-locate or search prefecture → city. Manual entry is available if needed.",
      "zh-Hans": "点「按当前位置自动设定」，或搜索都道府县 → 市区町村；找不到时可手动输入。",
      ko: "현재 위치 자동 설정 또는 도도부현→시구정촌 검색. 필요 시 수동 입력.",
      vi: "Chạm tự định vị hoặc tìm tỉnh → thành phố. Có thể nhập tay nếu cần.",
    },
    g2_t: { ja: "2. 収集日を合わせる", en: "2. Align collection days", "zh-Hans": "2. 对齐收集日", ko: "2. 수거일 맞추기", vi: "2. Khớp ngày thu" },
    g2_p: {
      ja: "掲示板や自治体案内と違う日があれば「収集日カスタム」で修正。テンプレート地区は可燃曜日の調整も無料です。",
      en: "If your notice board differs, edit Custom Schedule. Template areas can adjust burnable weekdays for free.",
      "zh-Hans": "若与告示或自治体说明不一致，用「自定义收集日」修改；模板地区调整可燃星期也免费。",
      ko: "공지와 다르면 맞춤 수거일로 수정. 템플릿 지역은 가연 요일 조정도 무료.",
      vi: "Nếu khác bảng thông báo, sửa Lịch tùy chỉnh. Vùng mẫu chỉnh thứ đốt cũng miễn phí.",
    },
    g3_t: { ja: "3. リマインドを置く", en: "3. Set reminders", "zh-Hans": "3. 设置提醒", ko: "3. 알림 설정", vi: "3. Đặt nhắc nhở" },
    g3_p: {
      ja: "通知と基本ウィジェットで出し忘れを防止。対応機種のダイナミックアイランド Live Countdown は Pro で利用可能。粗大ごみの予約メモも同梱。",
      en: "Notifications and basic widgets help you remember. Dynamic Island Live Countdown is Pro on supported iPhones. Bulky-waste memos included.",
      "zh-Hans": "通知与基础小组件减少漏扔。支持机型的灵动岛 Live Countdown 为 Pro。附带粗大垃圾预约备忘。",
      ko: "알림·기본 위젯으로 깜빡임을 줄입니다. 지원 기기의 다이나믹 아일랜드 Live Countdown은 Pro. 대형쓰레기 메모 포함.",
      vi: "Thông báo & widget cơ bản giảm quên. Dynamic Island Live Countdown là Pro trên máy hỗ trợ. Có ghi chú rác cồng kềnh.",
    },
    g4_t: {
      ja: "Pro で広がる使い方（買い切り・永久解放）",
      en: "Pro unlocks more (one-time purchase)",
      "zh-Hans": "Pro 扩展用法（一次买断・永久解锁）",
      ko: "Pro로 더 넓게 (일회 구매 · 영구)",
      vi: "Pro mở rộng (mua một lần · vĩnh viễn)",
    },
    g4_p: {
      ja: "一度の購入で永久解放：① 多地区管理（自宅＋会社／実家）② 中サイズ／ロック画面ウィジェット（7日一覧＋ワンタップ打刻）③ ダイナミックアイランド＆ロック画面のリアルタイムカウントダウン。サブスクリプションはありません。",
      en: "One purchase, forever: ① Multi-district management (home + work / parents) ② Medium & Lock Screen widgets (7-day overview + one-tap check-in) ③ Dynamic Island & Lock Screen live countdown. No subscription.",
      "zh-Hans": "一次买断永久解锁：① 多地区管理（自宅 + 公司 / 父母家）② 中号与锁屏小组件（7日全览 + 一键打卡）③ 灵动岛与锁屏实时倒计时。无订阅。",
      ko: "한 번 구매로 영구: ① 다중 지역 관리(자택+회사/본가) ② 중형·잠금화면 위젯(7일 전체 보기+원탭 체크인) ③ 다이나믹 아일랜드·잠금화면 실시간 카운트다운. 구독 없음.",
      vi: "Mua một lần, mãi mãi: ① Quản lý đa khu vực (nhà + công ty / nhà bố mẹ) ② Widget vừa & khóa (tóm tắt 7 ngày + check-in một chạm) ③ Đếm ngược Live trên Dynamic Island & màn hình khóa. Không đăng ký.",
    },
    support_h2: { ja: "サポートとよくある質問", en: "Support & FAQ", "zh-Hans": "支持与常见问题", ko: "지원·FAQ", vi: "Hỗ trợ & FAQ" },
    support_contact: {
      ja: "お問い合わせ：",
      en: "Contact:",
      "zh-Hans": "联系：",
      ko: "문의:",
      vi: "Liên hệ:",
    },
    faq1_q: {
      ja: "1. 位置情報はどのように使われますか？",
      en: "1. How is location used?",
      "zh-Hans": "1. 位置信息如何使用？",
      ko: "1. 위치 정보는 어떻게 쓰이나요?",
      vi: "1. Vị trí dùng thế nào?",
    },
    faq1_a: {
      ja: "市区町村の収集ルールをその場でマッチするためだけに、現在地を一度取得します。位置の履歴保存・追跡・第三者提供はありません。",
      en: "We read your location once only to match municipal rules. No location history, tracking, or sharing with third parties.",
      "zh-Hans": "仅用于当场匹配市区町村收集规则，读取一次当前位置。不保存位置历史、不追踪、不向第三方提供。",
      ko: "시구정촌 규칙을 즉시 매칭하려고 위치를 한 번만 읽습니다. 기록·추적·제3자 제공 없음.",
      vi: "Chỉ đọc vị trí một lần để khớp quy tắc đô thị. Không lưu lịch sử, không theo dõi, không chia sẻ bên thứ ba.",
    },
    faq2_q: {
      ja: "2. 無料と Pro の違いは？",
      en: "2. Free vs Pro?",
      "zh-Hans": "2. 免费与 Pro 有何不同？",
      ko: "2. 무료와 Pro 차이는?",
      vi: "2. Miễn phí và Pro khác gì?",
    },
    faq2_a: {
      ja: "収集カレンダー・収集日カスタム・粗大ごみツール・基本リマインダーは無料。Pro（買い切り・永久解放）は次を解放します：① 多地区管理（自宅＋会社／実家）② 中サイズ／ロック画面ウィジェット（7日一覧＋ワンタップ打刻）③ ダイナミックアイランド＆ロック画面のリアルタイムカウントダウン。サブスクリプションはありません。価格は App Store 表示に従います。",
      en: "Calendar, custom schedules, bulky tools, and basic reminders are free. Pro (one-time purchase · forever) unlocks: ① multi-district management (home + work / parents) ② medium & Lock Screen widgets (7-day overview + one-tap check-in) ③ Dynamic Island & Lock Screen live countdown. No subscription. Price is shown live in the App Store.",
      "zh-Hans": "收集日历、自定义收集日、粗大垃圾工具与基础提醒免费。Pro（一次性买断・永久解锁）：① 多地区管理（自宅 + 公司 / 父母家）② 中号与锁屏小组件（7日全览 + 一键打卡）③ 灵动岛与锁屏实时倒计时。无订阅。具体价格以 App Store 实时显示为准。",
      ko: "캘린더·맞춤 수거일·대형쓰레기 도구·기본 알림은 무료. Pro(일회 구매 · 영구 해제): ① 다중 지역 관리(자택+회사/본가) ② 중형·잠금화면 위젯(7일 전체 보기+원탭 체크인) ③ 다이나믹 아일랜드·잠금화면 실시간 카운트다운. 구독 없음. 가격은 App Store 실시간 표시를 따릅니다.",
      vi: "Lịch, lịch tùy chỉnh, công cụ rác cồng kềnh và nhắc cơ bản miễn phí. Pro (mua một lần · mở khóa vĩnh viễn): ① quản lý đa khu vực (nhà + công ty / nhà bố mẹ) ② widget vừa & khóa (tóm tắt 7 ngày + check-in một chạm) ③ đếm ngược Live trên Dynamic Island & màn hình khóa. Không đăng ký. Giá theo App Store.",
    },
    faq3_q: {
      ja: "3. 購入を復元するには？",
      en: "3. How do I restore purchases?",
      "zh-Hans": "3. 如何恢复购买？",
      ko: "3. 구입 복원은?",
      vi: "3. Khôi phục giao dịch?",
    },
    faq3_a: {
      ja: "アプリ内の Pro 画面で「購入を復元」をタップしてください。Apple StoreKit が Apple ID の権利を確認します。",
      en: "In the app Pro screen, tap Restore Purchases. StoreKit checks entitlements for your Apple ID.",
      "zh-Hans": "在 App 的 Pro 页面点击「恢复购买」。Apple StoreKit 会核验您 Apple ID 的权益。",
      ko: "앱 Pro 화면에서 구입 항목 복원을 탭하세요. StoreKit이 Apple ID 권한을 확인합니다.",
      vi: "Trong màn Pro của app, chạm Khôi phục giao dịch. StoreKit kiểm tra quyền Apple ID.",
    },
    privacy_h2: { ja: "プライバシー（概要）", en: "Privacy (summary)", "zh-Hans": "隐私（摘要）", ko: "개인정보 (요약)", vi: "Quyền riêng tư (tóm tắt)" },
    privacy_lead: {
      ja: "ゴミログはローカルファースト（Local-First）です。地区設定・カスタム収集日・メモは端末と、お客様個人の iCloud 同期領域にのみ保存され、業務サーバーへのアップロードや個人身元の追跡はありません。",
      en: "GomiLog is Local-First. District settings, custom schedules, and memos stay on your device and your personal iCloud sync space—never uploaded to our servers, with no identity tracking.",
      "zh-Hans": "ゴミログ采用本地优先（Local-First）。地区设置、自定义收集日与备忘仅保存在本机与您个人的 iCloud 同步空间，不会上传到开发者服务器，也不做个人身份追踪。",
      ko: "ゴミ로그는 Local-First입니다. 지역·맞춤 일정·메모는 기기와 개인 iCloud 동기화 영역에만 저장되며, 개발자 서버 업로드·신원 추적이 없습니다.",
      vi: "GomiLog là Local-First. Cài đặt khu vực, lịch tùy chỉnh và ghi chú chỉ trên máy và iCloud cá nhân—không tải lên máy chủ của chúng tôi, không theo dõi danh tính.",
    },
    privacy_li1: {
      ja: "位置情報は市区町村マッチングの一瞬のみ。保存・追跡しません。",
      en: "Location is used only briefly for city matching—never stored or tracked.",
      "zh-Hans": "位置信息仅用于市区町村匹配的瞬间，不保存、不追踪。",
      ko: "위치는 시구정촌 매칭 순간에만 사용. 저장·추적 없음.",
      vi: "Vị trí chỉ dùng thoáng qua để khớp đô thị—không lưu, không theo dõi.",
    },
    privacy_li2: {
      ja: "広告・分析・トラッキング SDK は一切埋め込みません。個人識別データの収集はありません。",
      en: "No ads, analytics, or tracking SDKs. We collect no personal identity data.",
      "zh-Hans": "不嵌入广告、分析或追踪 SDK，不收集个人身份数据。",
      ko: "광고·분석·추적 SDK 없음. 개인 식별 데이터 수집 없음.",
      vi: "Không SDK quảng cáo/phân tích/theo dõi. Không thu thập dữ liệu định danh.",
    },
    privacy_li3: {
      ja: "アプリ内課金は Apple StoreKit が処理し、決済情報は Apple が管理します。",
      en: "In-app purchases go through Apple StoreKit; Apple handles payment details.",
      "zh-Hans": "应用内购买由 Apple StoreKit 处理，支付信息由 Apple 管理。",
      ko: "인앱 결제는 Apple StoreKit이 처리하며 결제 정보는 Apple이 관리합니다.",
      vi: "Mua trong app qua Apple StoreKit; Apple quản lý thông tin thanh toán.",
    },
    privacy_link: {
      ja: "プライバシーポリシー全文を見る →",
      en: "Read the full privacy policy →",
      "zh-Hans": "查看完整隐私政策 →",
      ko: "개인정보 처리방침 전문 보기 →",
      vi: "Xem chính sách quyền riêng tư đầy đủ →",
    },
    footer: {
      ja: "© 2026 KitSpark Studio · ゴミログ · ",
      en: "© 2026 KitSpark Studio · GomiLog · ",
      "zh-Hans": "© 2026 KitSpark Studio · ゴミログ · ",
      ko: "© 2026 KitSpark Studio · ゴミ로그 · ",
      vi: "© 2026 KitSpark Studio · GomiLog · ",
    },
  };

  // ——— privacy.html ———
  const PRIVACY = {
    title: {
      ja: "プライバシーポリシー · ゴミログ · KitSpark Studio",
      en: "Privacy Policy · GomiLog · KitSpark Studio",
      "zh-Hans": "隐私政策 · ゴミログ · KitSpark Studio",
      ko: "개인정보 처리방침 · ゴミ로그 · KitSpark Studio",
      vi: "Chính sách quyền riêng tư · GomiLog · KitSpark Studio",
    },
    desc: {
      ja: "ゴミログのプライバシーポリシー — Local-First。端末と個人 iCloud のみに保存。個人識別・追跡データは収集しません。",
      en: "GomiLog Privacy Policy — Local-First. Data on device & personal iCloud only. No identity tracking.",
      "zh-Hans": "ゴミログ隐私政策 — Local-First。仅本机与个人 iCloud。不收集身份追踪数据。",
      ko: "ゴミ로그 개인정보 처리방침 — Local-First. 기기·개인 iCloud만. 신원 추적 없음.",
      vi: "Chính sách GomiLog — Local-First. Chỉ máy & iCloud cá nhân. Không theo dõi danh tính.",
    },
    nav_home: { ja: "ホームへ戻る", en: "Back to home", "zh-Hans": "返回首页", ko: "홈으로", vi: "Về trang chủ" },
    h1: {
      ja: "ゴミログ プライバシーポリシー",
      en: "GomiLog Privacy Policy",
      "zh-Hans": "ゴミログ 隐私政策",
      ko: "ゴミ로그 개인정보 처리방침",
      vi: "Chính sách quyền riêng tư GomiLog",
    },
    updated: {
      ja: "最終更新：2026-11-21 · 対象：iOS（ウィジェット・ライブアクティビティを含む）",
      en: "Last updated: 2026-11-21 · iOS (including widgets & Live Activities)",
      "zh-Hans": "最后更新：2026-11-21 · 适用于 iOS（含小组件与实时活动）",
      ko: "최종 업데이트: 2026-11-21 · iOS (위젯·라이브 액티비티 포함)",
      vi: "Cập nhật: 2026-11-21 · iOS (gồm widget & Live Activity)",
    },
    s1_t: {
      ja: "1. 概要（Local-First）",
      en: "1. Overview (Local-First)",
      "zh-Hans": "1. 概述（Local-First）",
      ko: "1. 개요 (Local-First)",
      vi: "1. Tổng quan (Local-First)",
    },
    s1_p: {
      ja: "ゴミログ（GomiLog）は KitSpark Studio が開発するローカルファースト（Local-First）のごみ収集カレンダーです。地区設定・カスタム収集日・通知設定・粗大ごみメモなどのデータは、お客様の端末（および App Group）と、お客様個人の Apple ID に紐づく iCloud 私有領域（NSUbiquitousKeyValueStore による軽量同期）にのみ保存されます。当社は外部の業務サーバーを運営せず、個人を識別・追跡するためのデータを一切収集・送信・分析しません。",
      en: "GomiLog by KitSpark Studio is a Local-First trash calendar. District settings, custom schedules, notifications, and bulky memos stay on your device (and App Group) and your personal Apple ID iCloud space (lightweight NSUbiquitousKeyValueStore sync). We run no backend servers and never collect, transmit, or analyze personal identity or tracking data.",
      "zh-Hans": "ゴミログ（GomiLog）由 KitSpark Studio 开发，采用本地优先（Local-First）架构。地区设置、自定义收集日、通知与粗大垃圾备忘仅保存在您的设备（及 App Group）以及绑定个人 Apple ID 的 iCloud 私有区域（NSUbiquitousKeyValueStore 轻量同步）。我们不运营业务服务器，绝不收集、发送或分析任何用于识别或追踪个人的数据。",
      ko: "KitSpark Studio의 ゴミ로그는 Local-First 쓰레기 캘린더입니다. 지역·맞춤 일정·알림·대형쓰레기 메모는 기기(및 App Group)와 개인 Apple ID iCloud(NSUbiquitousKeyValueStore 경량 동기화)에만 저장됩니다. 백엔드 서버를 운영하지 않으며 신원·추적 데이터를 수집·전송·분석하지 않습니다.",
      vi: "GomiLog của KitSpark Studio là lịch thu rác Local-First. Cài đặt khu vực, lịch tùy chỉnh, thông báo và ghi chú rác cồng kềnh chỉ lưu trên máy (và App Group) cùng vùng iCloud gắn Apple ID cá nhân (đồng bộ nhẹ NSUbiquitousKeyValueStore). Chúng tôi không vận hành máy chủ nghiệp vụ và không thu thập/gửi/phân tích dữ liệu định danh hay theo dõi.",
    },
    s2_t: {
      ja: "2. 位置情報の取り扱い",
      en: "2. Location",
      "zh-Hans": "2. 位置信息",
      ko: "2. 위치 정보",
      vi: "2. Vị trí",
    },
    s2_p: {
      ja: "「現在地から自動設定」機能では、お住まいの都道府県・市区町村の収集ルールをその場でマッチするために、端末の位置情報を一度だけ取得し、日本語ロケール（ja_JP）で行政区画名を解決します。",
      en: "Auto-locate reads your device location once to match prefecture/city collection rules using Japanese locale (ja_JP) geocoding.",
      "zh-Hans": "「按当前位置自动设定」仅读取一次设备位置，用日语区域（ja_JP）解析行政区划，以当场匹配都道府县/市区町村收集规则。",
      ko: "현재 위치 자동 설정은 도도부현·시구정촌 규칙을 즉시 매칭하려고 위치를 한 번만 읽고 ja_JP로 행정구역을 해석합니다.",
      vi: "Tự định vị đọc vị trí một lần để khớp quy tắc tỉnh/thành bằng địa lý ja_JP.",
    },
    s2_li1: {
      ja: "位置情報は市区町村マッチングの瞬間にのみ使用します。",
      en: "Location is used only at the moment of city matching.",
      "zh-Hans": "位置信息仅在匹配市区町村的瞬间使用。",
      ko: "위치는 시구정촌 매칭 순간에만 사용합니다.",
      vi: "Vị trí chỉ dùng lúc khớp đô thị.",
    },
    s2_li2: {
      ja: "位置の履歴・軌跡・座標を保存・追跡・第三者へ提供することはありません。",
      en: "We never store, track, or share location history, trails, or coordinates.",
      "zh-Hans": "绝不保存、追踪或向第三方提供位置历史、轨迹或坐标。",
      ko: "위치 기록·경로·좌표를 저장·추적·제3자 제공하지 않습니다.",
      vi: "Không lưu/theo dõi/chia sẻ lịch sử, lộ trình hay tọa độ.",
    },
    s2_li3: {
      ja: "マッチ結果として残るのは、お客様が選択・保存した市区町村名などの地区設定のみです。",
      en: "Only the district settings you choose (e.g. city name) remain on device.",
      "zh-Hans": "最终仅保留您选择并保存的市区町村等地区设置。",
      ko: "남는 것은 선택한 시구정촌 등 지역 설정뿐입니다.",
      vi: "Chỉ còn cài đặt khu vực bạn chọn (ví dụ tên thành phố).",
    },
    s2_li4: {
      ja: "位置情報へのアクセスはいつでも iOS の設定から拒否できます（手動で地区を選ぶことも可能です）。",
      en: "You can deny location access anytime in iOS Settings and pick a city manually.",
      "zh-Hans": "可随时在 iOS 设置中拒绝位置权限，也可手动选择地区。",
      ko: "iOS 설정에서 위치 권한을 언제든 거부하고 수동으로 지역을 선택할 수 있습니다.",
      vi: "Có thể từ chối quyền vị trí trong Cài đặt iOS và chọn thành phố thủ công.",
    },
    s3_t: {
      ja: "3. 収集しないデータ（個人識別・追跡なし）",
      en: "3. Data we do not collect (no identity tracking)",
      "zh-Hans": "3. 不收集的数据（无个人身份追踪）",
      ko: "3. 수집하지 않는 데이터 (신원 추적 없음)",
      vi: "3. Dữ liệu không thu thập (không theo dõi danh tính)",
    },
    s3_p: {
      ja: "当社は次の情報を収集・保管しません。本アプリは個人の身元追跡（Identity Tracking）を行いません。",
      en: "We do not collect or store the following. This app performs no personal identity tracking.",
      "zh-Hans": "我们不收集或保存下列信息。本应用不做个人身份追踪（Identity Tracking）。",
      ko: "다음 정보를 수집·보관하지 않습니다. 신원 추적(Identity Tracking)을 하지 않습니다.",
      vi: "Chúng tôi không thu thập/lưu các thông tin sau. Ứng dụng không theo dõi danh tính cá nhân.",
    },
    s3_li1: {
      ja: "氏名、メールアドレス、電話番号などの個人識別情報（サポートメールへの任意連絡を除く）",
      en: "Names, emails, phone numbers, or other PII (except optional support emails you send us)",
      "zh-Hans": "姓名、邮箱、电话等个人识别信息（您主动发往支持邮箱的除外）",
      ko: "이름·이메일·전화 등 개인식별정보(지원 메일 임의 연락 제외)",
      vi: "Họ tên, email, SĐT hay PII khác (trừ email hỗ trợ bạn chủ động gửi)",
    },
    s3_li2: {
      ja: "位置座標のログ、広告 ID（IDFA）、端末横断トラッキング、プロファイリング",
      en: "Location coordinate logs, advertising IDs (IDFA), cross-device tracking, or profiling",
      "zh-Hans": "位置坐标日志、广告标识符（IDFA）、跨设备追踪或画像",
      ko: "좌표 로그, 광고 ID(IDFA), 기기 간 추적, 프로파일링",
      vi: "Nhật ký tọa độ, ID quảng cáo (IDFA), theo dõi đa thiết bị, lập hồ sơ",
    },
    s3_li3: {
      ja: "第三者広告・分析・行動計測 SDK による利用データ",
      en: "Usage data from third-party ads, analytics, or behavioral SDKs",
      "zh-Hans": "第三方广告、分析或行为 SDK 产生的使用数据",
      ko: "제3자 광고·분석·행동 SDK 이용 데이터",
      vi: "Dữ liệu từ SDK quảng cáo/phân tích/hành vi bên thứ ba",
    },
    s4_t: {
      ja: "4. 端末と個人 iCloud に保存されるデータ",
      en: "4. Data on device & personal iCloud",
      "zh-Hans": "4. 保存在本机与个人 iCloud 的数据",
      ko: "4. 기기·개인 iCloud에 저장되는 데이터",
      vi: "4. Dữ liệu trên máy & iCloud cá nhân",
    },
    s4_li1: {
      ja: "ローカル／App Group：選択中の地区、よく使う地区、カスタム収集日、通知設定、言語、Pro 権利状態など。",
      en: "Local / App Group: selected districts, saved places, custom schedules, notification prefs, language, Pro entitlement, etc.",
      "zh-Hans": "本地／App Group：当前地区、常用地区、自定义收集日、通知设置、语言、Pro 权益状态等。",
      ko: "로컬/App Group: 선택 지역, 저장 장소, 맞춤 일정, 알림, 언어, Pro 권한 등.",
      vi: "Local/App Group: khu vực đang chọn, địa điểm đã lưu, lịch tùy chỉnh, thông báo, ngôn ngữ, quyền Pro, v.v.",
    },
    s4_li2: {
      ja: "個人 iCloud（NSUbiquitousKeyValueStore）：上記設定の軽量同期。お客様の Apple ID にのみ可視です。",
      en: "Personal iCloud (NSUbiquitousKeyValueStore): lightweight sync of those settings, visible only to your Apple ID.",
      "zh-Hans": "个人 iCloud（NSUbiquitousKeyValueStore）：上述设置的轻量同步，仅对您的 Apple ID 可见。",
      ko: "개인 iCloud(NSUbiquitousKeyValueStore): 위 설정의 경량 동기화. Apple ID에만 보입니다.",
      vi: "iCloud cá nhân (NSUbiquitousKeyValueStore): đồng bộ nhẹ các cài đặt trên, chỉ Apple ID của bạn thấy.",
    },
    s4_li3: {
      ja: "ウィジェット／ライブアクティビティ：同一のローカル・App Group データを参照し、当社サーバーへ送信しません。",
      en: "Widgets / Live Activities read the same local App Group data and never send it to our servers.",
      "zh-Hans": "小组件／实时活动读取同一套本地 App Group 数据，不会发往开发者服务器。",
      ko: "위젯/라이브 액티비티는 동일 로컬 App Group 데이터를 읽으며 서버로 보내지 않습니다.",
      vi: "Widget/Live Activity đọc cùng dữ liệu App Group cục bộ, không gửi lên máy chủ của chúng tôi.",
    },
    s5_t: { ja: "5. アプリ内課金", en: "5. In-app purchases", "zh-Hans": "5. 应用内购买", ko: "5. 인앱 결제", vi: "5. Mua trong ứng dụng" },
    s5_p: {
      ja: "ゴミログ Pro は買い切り（非消耗型・永久解放）のみです。決済は Apple StoreKit が処理し、クレジットカード等の情報は Apple が管理します。当社は権利検証の結果のみを受け取り、支払明細を保管しません。自動更新サブスクリプションはありません。表示価格は App Store がストアフロントに応じて提供します。Pro の永久解放内容：① 多地区管理（自宅＋会社／実家）② 中サイズ／ロック画面ウィジェット（7日一覧＋ワンタップ打刻）③ ダイナミックアイランド＆ロック画面のリアルタイムカウントダウン。",
      en: "GomiLog Pro is a non-consumable one-time unlock (forever). Apple StoreKit processes payment; Apple holds card details. We only receive entitlement results and do not store payment records. No auto-renewing subscription. The price shown is provided by the App Store for your storefront. Pro forever includes: ① multi-district management (home + work / parents) ② medium & Lock Screen widgets (7-day overview + one-tap check-in) ③ Dynamic Island & Lock Screen live countdown.",
      "zh-Hans": "ゴミログ Pro 为非消耗型一次买断（永久解锁）。支付由 Apple StoreKit 处理，卡片信息由 Apple 保管。我们只接收权益校验结果，不保存支付明细。无自动续费订阅。显示价格由 App Store 按您的店面提供。Pro 永久权益：① 多地区管理（自宅 + 公司 / 父母家）② 中号与锁屏小组件（7日全览 + 一键打卡）③ 灵动岛与锁屏实时倒计时。",
      ko: "ゴミ로그 Pro는 비소모성 일회 구매(영구 해제)입니다. 결제는 Apple StoreKit, 카드 정보는 Apple이 관리합니다. 권한 결과만 받으며 결제 내역을 보관하지 않습니다. 자동 갱신 구독 없음. 표시 가격은 App Store가 스토어프론트에 맞게 제공합니다. Pro 영구 혜택: ① 다중 지역 관리(자택+회사/본가) ② 중형·잠금화면 위젯(7일 전체 보기+원탭 체크인) ③ 다이나믹 아일랜드·잠금화면 실시간 카운트다운.",
      vi: "GomiLog Pro là mua một lần không tiêu hao (mở khóa vĩnh viễn). StoreKit xử lý thanh toán; Apple giữ thông tin thẻ. Chúng tôi chỉ nhận kết quả entitlement, không lưu biên lai. Không đăng ký tự gia hạn. Giá hiển thị do App Store cung cấp theo cửa hàng của bạn. Quyền Pro vĩnh viễn: ① quản lý đa khu vực (nhà + công ty / nhà bố mẹ) ② widget vừa & khóa (tóm tắt 7 ngày + check-in một chạm) ③ đếm ngược Live trên Dynamic Island & màn hình khóa.",
    },
    s6_t: { ja: "6. 第三者サービス", en: "6. Third parties", "zh-Hans": "6. 第三方服务", ko: "6. 제3자 서비스", vi: "6. Bên thứ ba" },
    s6_p: {
      ja: "Apple のシステム枠組み（StoreKit、iCloud、WidgetKit、ActivityKit、CoreLocation 等）以外に、広告・分析・トラッキング SDK は埋め込みません。",
      en: "Aside from Apple frameworks (StoreKit, iCloud, WidgetKit, ActivityKit, CoreLocation, etc.), we embed no ads, analytics, or tracking SDKs.",
      "zh-Hans": "除 Apple 系统框架（StoreKit、iCloud、WidgetKit、ActivityKit、CoreLocation 等）外，不嵌入任何广告、分析或追踪 SDK。",
      ko: "Apple 프레임워크(StoreKit, iCloud, WidgetKit, ActivityKit, CoreLocation 등) 외에 광고·분석·추적 SDK를 넣지 않습니다.",
      vi: "Ngoài khung Apple (StoreKit, iCloud, WidgetKit, ActivityKit, CoreLocation…), không nhúng SDK quảng cáo/phân tích/theo dõi.",
    },
    s7_t: { ja: "7. 児童のプライバシー", en: "7. Children’s privacy", "zh-Hans": "7. 儿童隐私", ko: "7. 아동 개인정보", vi: "7. Trẻ em" },
    s7_p: {
      ja: "ゴミログは 13 歳未満の児童を対象としておらず、意図的に児童の個人データを収集しません。",
      en: "GomiLog is not directed at children under 13 and does not knowingly collect their personal data.",
      "zh-Hans": "ゴミログ不以 13 岁以下儿童为目标用户，也不会故意收集其个人数据。",
      ko: "ゴミ로그는 13세 미만을 대상으로 하지 않으며 고의로 아동 개인정보를 수집하지 않습니다.",
      vi: "GomiLog không hướng tới trẻ dưới 13 và không cố ý thu thập dữ liệu của trẻ.",
    },
    s8_t: { ja: "8. お問い合わせ", en: "8. Contact", "zh-Hans": "8. 联系我们", ko: "8. 문의", vi: "8. Liên hệ" },
    s8_p: {
      ja: "本ポリシーに関するご質問は、次のメールアドレスまでご連絡ください。",
      en: "Questions about this policy: email us at the address below.",
      "zh-Hans": "如对本政策有疑问，请发送邮件至：",
      ko: "본 정책 관련 문의는 아래 이메일로 연락해 주세요.",
      vi: "Mọi câu hỏi về chính sách này, gửi email tới:",
    },
    footer: {
      ja: "© 2026 KitSpark Studio · ゴミログ · ",
      en: "© 2026 KitSpark Studio · GomiLog · ",
      "zh-Hans": "© 2026 KitSpark Studio · ゴミログ · ",
      ko: "© 2026 KitSpark Studio · ゴミ로그 · ",
      vi: "© 2026 KitSpark Studio · GomiLog · ",
    },
    footer_home: { ja: "Home", en: "Home", "zh-Hans": "首页", ko: "홈", vi: "Home" },
  };

  function applyPage(lang) {
    const page = document.body.getAttribute("data-page");
    const dict = page === "privacy" ? PRIVACY : INDEX;
    applyAttrs(document, dict, lang);
  }

  window.GomiDocsI18n = {
    detectLang,
    setLang,
    mountSwitcher,
    applyPage,
    highlightSwitcher,
  };

  document.addEventListener("DOMContentLoaded", () => {
    const lang = detectLang();
    mountSwitcher(document.getElementById("lang-switcher-root"));
    setLang(lang);
  });
})();
