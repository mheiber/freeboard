import Foundation
import Carbon

enum Lang: String, CaseIterable {
    case en, zh, hi, es, fr, ar, bn, pt, ru, ja

    var nativeName: String {
        switch self {
        case .en: return "English"
        case .zh: return "中文"
        case .hi: return "हिन्दी"
        case .es: return "Español"
        case .fr: return "Français"
        case .ar: return "العربية"
        case .bn: return "বাংলা"
        case .pt: return "Português"
        case .ru: return "Русский"
        case .ja: return "日本語"
        }
    }

    var usesSystemFont: Bool {
        switch self {
        case .zh, .ja, .hi, .ar, .bn: return true
        case .en, .es, .fr, .pt, .ru: return false
        }
    }

    static func fromLocaleIdentifier(_ identifier: String) -> Lang? {
        let prefix = String(identifier.prefix(2))
        return Lang(rawValue: prefix)
    }
}

enum HotkeyChoice: String, CaseIterable {
    case c, x, v

    var keyCode: Int {
        switch self {
        case .c: return kVK_ANSI_C
        case .x: return kVK_ANSI_X
        case .v: return kVK_ANSI_V
        }
    }

    var displayName: String {
        switch self {
        case .c: return "Cmd-Shift-C"
        case .x: return "Cmd-Shift-X"
        case .v: return "Cmd-Shift-V"
        }
    }

    private static let hotkeyKey = "freeboard_hotkey"

    static var current: HotkeyChoice {
        get {
            if let raw = UserDefaults.standard.string(forKey: hotkeyKey),
               let choice = HotkeyChoice(rawValue: raw) {
                return choice
            }
            return .c
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: hotkeyKey)
        }
    }
}

struct L {
    private static let langKey = "freeboard_language"

    static var current: Lang {
        get {
            if let raw = UserDefaults.standard.string(forKey: langKey),
               let lang = Lang(rawValue: raw) {
                return lang
            }
            for identifier in Locale.preferredLanguages {
                if let lang = Lang.fromLocaleIdentifier(identifier) {
                    return lang
                }
            }
            return .en
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: langKey)
        }
    }

    private static func tr(_ key: String) -> String {
        strings[key]?[current] ?? strings[key]?[.en] ?? key
    }

    static var language: String { tr("language") }
    static var open: String { tr("open") }
    static var shortcut: String { tr("shortcut") }
    static var searchPlaceholder: String { tr("searchPlaceholder") }
    static var navigate: String { tr("navigate") }
    static var paste: String { tr("paste") }
    static var close: String { tr("close") }
    static var expand: String { tr("expand") }
    static var edit: String { tr("edit") }
    static var star: String { tr("star") }
    static var quit: String { tr("quit") }
    static var quitFreeboard: String { tr("quitFreeboard") }
    static var justNow: String { tr("justNow") }
    static var emptyHint: String { tr("emptyHint") }
    static var openClose: String { tr("openClose") }
    static var quickSelect: String { tr("quickSelect") }
    static var noMatchesFound: String { tr("noMatchesFound") }
    static var clearSearch: String { tr("clearSearch") }
    static var pasteNth: String { tr("pasteNth") }
    static var select: String { tr("select") }
    static var help: String { tr("help") }
    static var helpTitle: String { tr("helpTitle") }
    static var helpStep1: String { tr("helpStep1") }
    static var helpStep2Suffix: String { tr("helpStep2Suffix") }
    static var helpStep3a: String { tr("helpStep3a") }
    static var helpStep3b: String { tr("helpStep3b") }
    static var helpDismiss: String { tr("helpDismiss") }
    static var helpAccessibility: String { tr("helpAccessibility") }
    static var helpAccessibilityLink: String { tr("helpAccessibilityLink") }
    static var helpAccessibilitySteps: String { tr("helpAccessibilitySteps") }
    static var accessibilityStarred: String { tr("accessibilityStarred") }
    static var accessibilityStar: String { tr("accessibilityStar") }
    static var accessibilityDelete: String { tr("accessibilityDelete") }
    static var accessibilityPasswordHidden: String { tr("accessibilityPasswordHidden") }
    static var accessibilitySearchField: String { tr("accessibilitySearchField") }
    static var delete: String { tr("delete") }
    static var imageEntry: String { tr("imageEntry") }
    static var permissionWarningLabel: String { tr("permissionWarningLabel") }
    static var permissionWarningTooltip: String { tr("permissionWarningTooltip") }

    static func accessibleMinutesAgo(_ n: Int) -> String {
        String(format: tr("accessibleMinutesAgo"), n)
    }
    static func accessibleHoursAgo(_ n: Int) -> String {
        String(format: tr("accessibleHoursAgo"), n)
    }
    static func accessibleDaysAgo(_ n: Int) -> String {
        String(format: tr("accessibleDaysAgo"), n)
    }

    static func minutesAgo(_ n: Int) -> String {
        String(format: tr("minutesAgo"), n)
    }
    static func hoursAgo(_ n: Int) -> String {
        String(format: tr("hoursAgo"), n)
    }
    static func daysAgo(_ n: Int) -> String {
        String(format: tr("daysAgo"), n)
    }

    // MARK: - Translation dictionary

    private static let strings: [String: [Lang: String]] = [
        "open": [
            .en: "Open", .zh: "打开", .hi: "खोलें", .es: "Abrir", .fr: "Ouvrir",
            .ar: "فتح", .bn: "খুলুন", .pt: "Abrir", .ru: "Открыть", .ja: "開く"
        ],
        "shortcut": [
            .en: "Shortcut", .zh: "快捷键", .hi: "शॉर्टकट", .es: "Atajo", .fr: "Raccourci",
            .ar: "اختصار", .bn: "শর্টকাট", .pt: "Atalho", .ru: "Сочетание клавиш", .ja: "ショートカット"
        ],
        "searchPlaceholder": [
            .en: "▌ Search clipboard history...", .zh: "▌ 搜索剪贴板历史...", .hi: "▌ क्लिपबोर्ड हिस्ट्री खोजें...",
            .es: "▌ Buscar en historial...", .fr: "▌ Rechercher dans l'historique du presse-papiers...",
            .ar: "▌ ابحث في سجل الحافظة...", .bn: "▌ ক্লিপবোর্ড ইতিহাস অনুসন্ধান...",
            .pt: "▌ Pesquisar histórico...", .ru: "▌ Поиск в буфере обмена...", .ja: "▌ クリップボード履歴を検索..."
        ],
        "navigate": [
            .en: "navigate", .zh: "导航", .hi: "नेविगेट करें", .es: "navegar", .fr: "naviguer",
            .ar: "التنقل", .bn: "নেভিগেট", .pt: "navegar", .ru: "переход", .ja: "移動"
        ],
        "paste": [
            .en: "paste", .zh: "粘贴", .hi: "पेस्ट करें", .es: "pegar", .fr: "coller",
            .ar: "لصق", .bn: "পেস্ট", .pt: "colar", .ru: "вставить", .ja: "貼り付け"
        ],
        "close": [
            .en: "close", .zh: "关闭", .hi: "बंद करें", .es: "cerrar", .fr: "fermer",
            .ar: "إغلاق", .bn: "বন্ধ", .pt: "fechar", .ru: "закрыть", .ja: "閉じる"
        ],
        "expand": [
            .en: "expand", .zh: "展开", .hi: "विस्तार करें", .es: "ampliar", .fr: "étendre",
            .ar: "توسيع", .bn: "প্রসারিত", .pt: "expandir", .ru: "развернуть", .ja: "展開"
        ],
        "edit": [
            .en: "edit", .zh: "编辑", .hi: "संपादित करें", .es: "editar", .fr: "modifier",
            .ar: "تحرير", .bn: "সম্পাদনা", .pt: "editar", .ru: "править", .ja: "編集"
        ],
        "star": [
            .en: "star", .zh: "收藏", .hi: "स्टार करें", .es: "destacar", .fr: "favori",
            .ar: "تمييز", .bn: "তারকা", .pt: "favoritar", .ru: "отметить", .ja: "スター"
        ],
        "quit": [
            .en: "Quit", .zh: "退出", .hi: "छोड़ें", .es: "Salir", .fr: "Quitter",
            .ar: "إنهاء", .bn: "প্রস্থান", .pt: "Sair", .ru: "Выход", .ja: "終了"
        ],
        "quitFreeboard": [
            .en: "Quit Freeboard", .zh: "退出 Freeboard", .hi: "Freeboard छोड़ें", .es: "Salir de Freeboard",
            .fr: "Quitter Freeboard", .ar: "إنهاء Freeboard", .bn: "Freeboard বন্ধ করুন",
            .pt: "Sair do Freeboard", .ru: "Выйти из Freeboard", .ja: "Freeboard を終了"
        ],
        "justNow": [
            .en: "just now", .zh: "刚刚", .hi: "अभी", .es: "ahora mismo", .fr: "à l'instant",
            .ar: "الآن", .bn: "এইমাত্র", .pt: "agora mesmo", .ru: "только что", .ja: "今"
        ],
        "emptyHint": [
            .en: "Text you copy will show up here", .zh: "复制的文本将显示在这里", .hi: "कॉपी किया गया टेक्स्ट यहाँ दिखेगा",
            .es: "El texto que copies aparecerá aquí", .fr: "Le texte copié apparaîtra ici",
            .ar: "سيظهر النص المنسوخ هنا", .bn: "কপি করা টেক্সট এখানে দেখা যাবে",
            .pt: "O texto copiado aparecerá aqui", .ru: "Скопированный текст появится здесь",
            .ja: "コピーしたテキストがここに表示されます"
        ],
        "openClose": [
            .en: "open/close", .zh: "打开/关闭此窗口", .hi: "खोलें/बंद करें", .es: "abrir/cerrar",
            .fr: "ouvrir/fermer", .ar: "فتح/إغلاق", .bn: "খুলুন/বন্ধ", .pt: "abrir/fechar",
            .ru: "открыть/закрыть", .ja: "開く/閉じる"
        ],
        "pasteNth": [
            .en: "paste Nth", .zh: "粘贴第N项", .hi: "N वां पेस्ट", .es: "pegar N.º",
            .fr: "coller Nième", .ar: "لصق رقم N", .bn: "N নং পেস্ট",
            .pt: "colar Nº", .ru: "вставить N-й", .ja: "N番を貼り付け"
        ],
        "quickSelect": [
            .en: "quick select", .zh: "快速选择", .hi: "त्वरित चयन", .es: "selección rápida",
            .fr: "sélection rapide", .ar: "اختيار سريع", .bn: "দ্রুত নির্বাচন", .pt: "seleção rápida",
            .ru: "быстрый выбор", .ja: "クイック選択"
        ],
        "select": [
            .en: "select", .zh: "选择", .hi: "चुनें", .es: "seleccionar",
            .fr: "sélectionner", .ar: "تحديد", .bn: "নির্বাচন",
            .pt: "selecionar", .ru: "выбрать", .ja: "選択"
        ],
        "noMatchesFound": [
            .en: "No matches found.", .zh: "未找到匹配项。", .hi: "कोई मिलान नहीं मिला।",
            .es: "No se encontraron coincidencias.", .fr: "Aucun résultat trouvé.",
            .ar: "لا توجد نتائج.", .bn: "কোনো মিল পাওয়া যায়নি।",
            .pt: "Nenhum resultado encontrado.", .ru: "Совпадений не найдено.",
            .ja: "一致する項目がありません"
        ],
        "clearSearch": [
            .en: "Clear Search (Esc)", .zh: "清除搜索 (Esc)", .hi: "खोज साफ़ करें (Esc)",
            .es: "Limpiar búsqueda (Esc)", .fr: "Effacer la recherche (Esc)",
            .ar: "مسح البحث (Esc)", .bn: "অনুসন্ধান মুছুন (Esc)",
            .pt: "Limpar pesquisa (Esc)", .ru: "Очистить поиск (Esc)", .ja: "検索をクリア (Esc)"
        ],
        "language": [
            .en: "Language", .zh: "语言", .hi: "भाषा", .es: "Idioma", .fr: "Langue",
            .ar: "اللغة", .bn: "ভাষা", .pt: "Idioma", .ru: "Язык", .ja: "言語"
        ],
        "help": [
            .en: "Help", .zh: "帮助", .hi: "सहायता", .es: "Ayuda", .fr: "Aide",
            .ar: "مساعدة", .bn: "সাহায্য", .pt: "Ajuda", .ru: "Справка", .ja: "ヘルプ"
        ],
        "helpTitle": [
            .en: "FREEBOARD HELP", .zh: "FREEBOARD 帮助", .hi: "FREEBOARD सहायता",
            .es: "AYUDA FREEBOARD", .fr: "AIDE FREEBOARD", .ar: "مساعدة FREEBOARD",
            .bn: "FREEBOARD সাহায্য", .pt: "AJUDA FREEBOARD", .ru: "СПРАВКА FREEBOARD",
            .ja: "FREEBOARD ヘルプ"
        ],
        "helpStep1": [
            .en: "Copy text from any application with ⌘c", .zh: "从任何应用程序复制文本，使用 ⌘c",
            .hi: "किसी भी ऐप से ⌘c से टेक्स्ट कॉपी करें", .es: "Copia texto de cualquier aplicación con ⌘c",
            .fr: "Copiez du texte depuis n'importe quelle application avec ⌘c",
            .ar: "انسخ النص من أي تطبيق باستخدام ⌘c", .bn: "যেকোনো অ্যাপ থেকে ⌘c দিয়ে টেক্সট কপি করুন",
            .pt: "Copie texto de qualquer aplicativo com ⌘c", .ru: "Скопируйте текст из любого приложения с ⌘c",
            .ja: "任意のアプリで ⌘c でテキストをコピー"
        ],
        "helpStep2Suffix": [
            .en: "to open Freeboard", .zh: "打开 Freeboard", .hi: "Freeboard खोलने के लिए",
            .es: "para abrir Freeboard", .fr: "pour ouvrir Freeboard",
            .ar: "لفتح Freeboard", .bn: "Freeboard খুলতে",
            .pt: "para abrir o Freeboard", .ru: "чтобы открыть Freeboard",
            .ja: "で Freeboard を開く"
        ],
        "helpStep3a": [
            .en: "Press a number (1-9) to paste", .zh: "按数字键 (1-9) 粘贴",
            .hi: "पेस्ट करने के लिए नंबर (1-9) दबाएं", .es: "Presiona un número (1-9) para pegar",
            .fr: "Appuyez sur un chiffre (1-9) pour coller", .ar: "اضغط رقم (1-9) للصق",
            .bn: "পেস্ট করতে একটি নম্বর (1-9) চাপুন", .pt: "Pressione um número (1-9) para colar",
            .ru: "Нажмите цифру (1-9) для вставки", .ja: "数字 (1-9) を押して貼り付け"
        ],
        "helpStep3b": [
            .en: "OR type to search, then Enter", .zh: "或输入搜索，然后按 Enter",
            .hi: "या खोजने के लिए टाइप करें, फिर Enter", .es: "O escribe para buscar, luego Enter",
            .fr: "OU tapez pour chercher, puis Entrée", .ar: "أو اكتب للبحث ثم Enter",
            .bn: "অথবা অনুসন্ধান করতে টাইপ করুন, তারপর Enter", .pt: "OU digite para pesquisar, depois Enter",
            .ru: "ИЛИ введите для поиска, затем Enter", .ja: "または検索して Enter"
        ],
        "helpDismiss": [
            .en: "? to close help", .zh: "? 关闭帮助", .hi: "? सहायता बंद करें",
            .es: "? para cerrar ayuda", .fr: "? pour fermer l'aide",
            .ar: "? لإغلاق المساعدة", .bn: "? সাহায্য বন্ধ করুন",
            .pt: "? para fechar ajuda", .ru: "? закрыть справку", .ja: "? でヘルプを閉じる"
        ],
        "helpAccessibility": [
            .en: "To paste into apps, Freeboard needs permission.\nPlease go to",
            .zh: "要粘贴到其他应用，Freeboard 需要辅助功能权限。\n请前往",
            .hi: "ऐप्स में पेस्ट करने के लिए Freeboard को अनुमति चाहिए।\nकृपया जाएं",
            .es: "Para pegar en aplicaciones, Freeboard necesita permiso.\nPor favor ve a",
            .fr: "Pour coller dans les applications, Freeboard a besoin de permission.\nVeuillez aller à",
            .ar: "للصق في التطبيقات، يحتاج Freeboard إلى إذن.\nيرجى الانتقال إلى",
            .bn: "অ্যাপে পেস্ট করতে Freeboard-এর অনুমতি দরকার।\nযান",
            .pt: "Para colar em aplicativos, o Freeboard precisa de permissão.\nPor favor vá para",
            .ru: "Для вставки в приложения Freeboard нужно разрешение.\nПерейдите в",
            .ja: "アプリに貼り付けるには、Freeboard にアクセス許可が必要です。\n次へ進んでください"
        ],
        "helpAccessibilityLink": [
            .en: "Accessibility Permissions", .zh: "系统设置 → 辅助功能",
            .hi: "सुलभता अनुमतियाँ", .es: "Permisos de Accesibilidad",
            .fr: "Autorisations d'accessibilité", .ar: "أذونات إمكانية الوصول",
            .bn: "অ্যাক্সেসিবিলিটি অনুমতি", .pt: "Permissões de Acessibilidade",
            .ru: "Настройки доступности", .ja: "アクセシビリティの許可"
        ],
        "helpAccessibilitySteps": [
            .en: "click [+], add Freeboard, and make sure it is enabled [✓]",
            .zh: "点击 [+]，添加 Freeboard，并确保已启用 [✓]",
            .hi: "[+] क्लिक करें, Freeboard जोड़ें, और सुनिश्चित करें कि सक्षम है [✓]",
            .es: "haz clic en [+], añade Freeboard y asegúrate de que esté activado [✓]",
            .fr: "cliquez sur [+], ajoutez Freeboard et assurez-vous qu'il est activé [✓]",
            .ar: "انقر [+]، أضف Freeboard، وتأكد من تفعيله [✓]",
            .bn: "[+] ক্লিক করুন, Freeboard যোগ করুন এবং সক্রিয় আছে নিশ্চিত করুন [✓]",
            .pt: "clique em [+], adicione o Freeboard e certifique-se de que está ativado [✓]",
            .ru: "нажмите [+], добавьте Freeboard и убедитесь, что включено [✓]",
            .ja: "[+] をクリックし、Freeboard を追加して有効になっていることを確認 [✓]"
        ],
        "minutesAgo": [
            .en: "%dm ago", .zh: "%d分钟前", .hi: "%d मि॰ पहले", .es: "hace %dm",
            .fr: "il y a %d min", .ar: "منذ %d د", .bn: "%d মিনিট আগে",
            .pt: "há %d min", .ru: "%d мин", .ja: "%d分前"
        ],
        "hoursAgo": [
            .en: "%dh ago", .zh: "%d小时前", .hi: "%d घं॰ पहले", .es: "hace %dh",
            .fr: "il y a %d h", .ar: "منذ %d س", .bn: "%d ঘণ্টা আগে",
            .pt: "há %d h", .ru: "%d ч", .ja: "%d時間前"
        ],
        "daysAgo": [
            .en: "%dd ago", .zh: "%d天前", .hi: "%d दिन पहले", .es: "hace %dd",
            .fr: "il y a %d j", .ar: "منذ %d ي", .bn: "%d দিন আগে",
            .pt: "há %d d", .ru: "%d д", .ja: "%d日前"
        ],
        "accessibilityStarred": [
            .en: "Starred", .zh: "已收藏", .hi: "स्टार किया गया", .es: "Destacado",
            .fr: "Favori", .ar: "مميز", .bn: "তারকা দেওয়া", .pt: "Favoritado",
            .ru: "Отмечено", .ja: "スター付き"
        ],
        "accessibilityStar": [
            .en: "Star", .zh: "收藏", .hi: "स्टार करें", .es: "Destacar",
            .fr: "Ajouter aux favoris", .ar: "تمييز", .bn: "তারকা দিন", .pt: "Favoritar",
            .ru: "Отметить", .ja: "スターを付ける"
        ],
        "accessibilityDelete": [
            .en: "Delete clipboard entry", .zh: "删除剪贴板条目", .hi: "क्लिपबोर्ड प्रविष्टि हटाएं",
            .es: "Eliminar entrada del portapapeles", .fr: "Supprimer l'entrée du presse-papiers",
            .ar: "حذف عنصر الحافظة", .bn: "ক্লিপবোর্ড এন্ট্রি মুছুন",
            .pt: "Excluir entrada da área de transferência", .ru: "Удалить запись буфера обмена",
            .ja: "クリップボード項目を削除"
        ],
        "accessibilityPasswordHidden": [
            .en: "Password (hidden)", .zh: "密码（已隐藏）", .hi: "पासवर्ड (छिपा हुआ)",
            .es: "Contraseña (oculta)", .fr: "Mot de passe (masqué)",
            .ar: "كلمة المرور (مخفية)", .bn: "পাসওয়ার্ড (লুকানো)",
            .pt: "Senha (oculta)", .ru: "Пароль (скрыт)", .ja: "パスワード（非表示）"
        ],
        "accessibilitySearchField": [
            .en: "Search clipboard history", .zh: "搜索剪贴板历史", .hi: "क्लिपबोर्ड हिस्ट्री खोजें",
            .es: "Buscar en historial del portapapeles", .fr: "Rechercher dans l'historique du presse-papiers",
            .ar: "البحث في سجل الحافظة", .bn: "ক্লিপবোর্ড ইতিহাস অনুসন্ধান",
            .pt: "Pesquisar histórico da área de transferência", .ru: "Поиск в буфере обмена",
            .ja: "クリップボード履歴を検索"
        ],
        "delete": [
            .en: "delete", .zh: "删除", .hi: "हटाएं", .es: "eliminar",
            .fr: "supprimer", .ar: "حذف", .bn: "মুছুন", .pt: "excluir",
            .ru: "удалить", .ja: "削除"
        ],
        "accessibleMinutesAgo": [
            .en: "%d minutes ago", .zh: "%d分钟前", .hi: "%d मिनट पहले",
            .es: "hace %d minutos", .fr: "il y a %d minutes", .ar: "منذ %d دقائق",
            .bn: "%d মিনিট আগে", .pt: "há %d minutos", .ru: "%d минут назад",
            .ja: "%d分前"
        ],
        "accessibleHoursAgo": [
            .en: "%d hours ago", .zh: "%d小时前", .hi: "%d घंटे पहले",
            .es: "hace %d horas", .fr: "il y a %d heures", .ar: "منذ %d ساعات",
            .bn: "%d ঘণ্টা আগে", .pt: "há %d horas", .ru: "%d часов назад",
            .ja: "%d時間前"
        ],
        "accessibleDaysAgo": [
            .en: "%d days ago", .zh: "%d天前", .hi: "%d दिन पहले",
            .es: "hace %d días", .fr: "il y a %d jours", .ar: "منذ %d أيام",
            .bn: "%d দিন আগে", .pt: "há %d dias", .ru: "%d дней назад",
            .ja: "%d日前"
        ],
        "imageEntry": [
            .en: "Image", .zh: "图片", .hi: "चित्र", .es: "Imagen",
            .fr: "Image", .ar: "صورة", .bn: "ছবি", .pt: "Imagem",
            .ru: "Изображение", .ja: "画像"
        ],
        "permissionWarningLabel": [
            .en: "Accessibility Permission needed to paste",
            .zh: "需要辅助功能权限才能粘贴",
            .hi: "पेस्ट करने के लिए सुलभता अनुमति चाहिए",
            .es: "Se necesita permiso de accesibilidad para pegar",
            .fr: "Permission d'accessibilité requise pour coller",
            .ar: "يلزم إذن إمكانية الوصول للصق",
            .bn: "পেস্ট করতে অ্যাক্সেসিবিলিটি অনুমতি দরকার",
            .pt: "Permissão de acessibilidade necessária para colar",
            .ru: "Для вставки нужно разрешение Универсального доступа",
            .ja: "貼り付けにはアクセシビリティの許可が必要です"
        ],
        "permissionWarningTooltip": [
            .en: "Go to System Settings → Privacy & Security → Accessibility,\nclick [+], add Freeboard, and make sure it is enabled [✓]",
            .zh: "前往系统设置 → 隐私与安全性 → 辅助功能，\n点击 [+]，添加 Freeboard，并确保已启用 [✓]",
            .hi: "सिस्टम सेटिंग्स → गोपनीयता → सुलभता पर जाएं，\n[+] क्लिक करें, Freeboard जोड़ें, सक्षम करें [✓]",
            .es: "Ve a Ajustes del Sistema → Privacidad → Accesibilidad,\nhaz clic en [+], añade Freeboard y actívalo [✓]",
            .fr: "Allez dans Réglages Système → Confidentialité → Accessibilité,\ncliquez sur [+], ajoutez Freeboard et activez-le [✓]",
            .ar: "انتقل إلى إعدادات النظام ← الخصوصية ← إمكانية الوصول،\nانقر [+]، أضف Freeboard، وفعّله [✓]",
            .bn: "সিস্টেম সেটিংস → প্রাইভেসি → অ্যাক্সেসিবিলিটি-তে যান，\n[+] ক্লিক করুন, Freeboard যোগ করুন, সক্রিয় করুন [✓]",
            .pt: "Vá para Ajustes do Sistema → Privacidade → Acessibilidade,\nclique em [+], adicione o Freeboard e ative-o [✓]",
            .ru: "Откройте Системные настройки → Конфиденциальность → Универсальный доступ,\nнажмите [+], добавьте Freeboard и включите [✓]",
            .ja: "システム設定 → プライバシー → アクセシビリティを開き、\n[+] をクリックして Freeboard を追加し、有効にしてください [✓]"
        ],
    ]
}
