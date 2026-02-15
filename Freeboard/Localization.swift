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
    static var view: String { tr("view") }
    static var star: String { tr("star") }
    static var unstar: String { tr("unstar") }
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
    static var permissionWarningButtonTitle: String { tr("permissionWarningButtonTitle") }
    static var launchAtLogin: String { tr("launchAtLogin") }
    static var vimStyleEditing: String { tr("vimStyleEditing") }
    static var saveAndClose: String { tr("saveAndClose") }
    static var accessibilityTextEditor: String { tr("accessibilityTextEditor") }
    static var vimInsertMode: String { tr("vimInsertMode") }
    static var vimNormalMode: String { tr("vimNormalMode") }
    static var vimGoBack: String { tr("vimGoBack") }
    static var move: String { tr("move") }
    static var richPaste: String { tr("richPaste") }
    static var accessibilityMarkdownText: String { tr("accessibilityMarkdownText") }
    static var markdownSupport: String { tr("markdownSupport") }
    static var helpDismissEsc: String { tr("helpDismissEsc") }
    static var helpCloseHelp: String { tr("helpCloseHelp") }
    static var helpNavHint: String { tr("helpNavHint") }
    static var helpNavHintBack: String { tr("helpNavHintBack") }
    static var helpPowerFeatures: String { tr("helpPowerFeatures") }
    static var helpMarkdownLink: String { tr("helpMarkdownLink") }
    static var markdownHelpBack: String { tr("markdownHelpBack") }
    static var markdownHelpBindings: String { tr("markdownHelpBindings") }
    static var markdownHelpShiftEnterRich: String { tr("markdownHelpShiftEnterRich") }
    static var markdownHelpShiftEnterPlain: String { tr("markdownHelpShiftEnterPlain") }
    static var markdownHelpCheatSheet: String { tr("markdownHelpCheatSheet") }
    static var markdownHelpHeadings: String { tr("markdownHelpHeadings") }
    static var markdownHelpBold: String { tr("markdownHelpBold") }
    static var markdownHelpItalic: String { tr("markdownHelpItalic") }
    static var markdownHelpCode: String { tr("markdownHelpCode") }
    static var markdownHelpCodeBlock: String { tr("markdownHelpCodeBlock") }
    static var markdownHelpLink: String { tr("markdownHelpLink") }
    static var markdownHelpList: String { tr("markdownHelpList") }
    static var markdownHelpOrderedList: String { tr("markdownHelpOrderedList") }
    static var markdownHelpBlockquote: String { tr("markdownHelpBlockquote") }
    static var markdownHelpHr: String { tr("markdownHelpHr") }
    static var editing: String { tr("editing") }
    static var helpEditingLink: String { tr("helpEditingLink") }
    static var editingHelpCtrlEText: String { tr("editingHelpCtrlEText") }
    static var editingHelpCtrlEMultimedia: String { tr("editingHelpCtrlEMultimedia") }
    static var editingHelpSeeAlsoMarkdown: String { tr("editingHelpSeeAlsoMarkdown") }
    static var editingHelpVimEnable: String { tr("editingHelpVimEnable") }
    static var editingHelpVimDisable: String { tr("editingHelpVimDisable") }
    static var settings: String { tr("settings") }
    static var helpSettingsLink: String { tr("helpSettingsLink") }
    static var settingsHelpRightClick: String { tr("settingsHelpRightClick") }
    static var settingsHelpAvailable: String { tr("settingsHelpAvailable") }
    static var contextPaste: String { tr("contextPaste") }
    static var contextPasteAsPlainText: String { tr("contextPasteAsPlainText") }
    static var contextPasteAsRichText: String { tr("contextPasteAsRichText") }
    static var contextPasteAsMarkdown: String { tr("contextPasteAsMarkdown") }
    static var formattedPaste: String { tr("formattedPaste") }
    static var accessibilityCodeText: String { tr("accessibilityCodeText") }
    static var contextPasteFormatted: String { tr("contextPasteFormatted") }
    static var contextEdit: String { tr("contextEdit") }
    static var contextView: String { tr("contextView") }
    static var contextExpand: String { tr("contextExpand") }
    static var contextCollapse: String { tr("contextCollapse") }
    static var contextStar: String { tr("contextStar") }
    static var contextUnstar: String { tr("contextUnstar") }
    static var contextDelete: String { tr("contextDelete") }
    static var contextRevealInFinder: String { tr("contextRevealInFinder") }
    static var focusMode: String { tr("focusMode") }
    static var regularSize: String { tr("regularSize") }

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
        "view": [
            .en: "view", .zh: "查看", .hi: "देखें", .es: "ver", .fr: "voir",
            .ar: "عرض", .bn: "দেখুন", .pt: "ver", .ru: "просмотр", .ja: "表示"
        ],
        "star": [
            .en: "star", .zh: "收藏", .hi: "स्टार करें", .es: "destacar", .fr: "favori",
            .ar: "تمييز", .bn: "তারকা", .pt: "favoritar", .ru: "отметить", .ja: "スター"
        ],
        "unstar": [
            .en: "unstar", .zh: "取消收藏", .hi: "स्टार हटाएं", .es: "quitar destacado", .fr: "retirer favori",
            .ar: "إلغاء التمييز", .bn: "তারকা সরান", .pt: "remover favorito", .ru: "снять отметку", .ja: "スターを外す"
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
        "permissionWarningButtonTitle": [
            .en: "Needs Permissions",
            .zh: "需要权限",
            .hi: "अनुमति चाहिए",
            .es: "Necesita permisos",
            .fr: "Permissions requises",
            .ar: "يلزم إذن",
            .bn: "অনুমতি দরকার",
            .pt: "Precisa de permissões",
            .ru: "Нужны разрешения",
            .ja: "許可が必要"
        ],
        "launchAtLogin": [
            .en: "Launch at Login", .zh: "登录时启动", .hi: "लॉगिन पर शुरू करें",
            .es: "Iniciar al acceder", .fr: "Ouvrir au démarrage",
            .ar: "التشغيل عند تسجيل الدخول", .bn: "লগইনে চালু করুন",
            .pt: "Abrir ao iniciar sessão", .ru: "Запускать при входе", .ja: "ログイン時に起動"
        ],
        "vimStyleEditing": [
            .en: "Vim-style Editing", .zh: "Vim 风格编辑", .hi: "Vim शैली संपादन",
            .es: "Edición estilo Vim", .fr: "Édition style Vim",
            .ar: "تحرير بأسلوب Vim", .bn: "Vim স্টাইল সম্পাদনা",
            .pt: "Edição estilo Vim", .ru: "Редактирование в стиле Vim", .ja: "Vim スタイル編集"
        ],
        "saveAndClose": [
            .en: "save+close", .zh: "保存并关闭", .hi: "सहेजें+बंद",
            .es: "guardar+cerrar", .fr: "enregistrer+fermer",
            .ar: "حفظ+إغلاق", .bn: "সংরক্ষণ+বন্ধ",
            .pt: "salvar+fechar", .ru: "сохранить+закрыть", .ja: "保存+閉じる"
        ],
        "accessibilityTextEditor": [
            .en: "Text editor", .zh: "文本编辑器", .hi: "टेक्स्ट संपादक",
            .es: "Editor de texto", .fr: "Éditeur de texte",
            .ar: "محرر النصوص", .bn: "টেক্সট সম্পাদক",
            .pt: "Editor de texto", .ru: "Текстовый редактор", .ja: "テキストエディタ"
        ],
        "vimInsertMode": [
            .en: "insert mode", .zh: "插入模式", .hi: "इन्सर्ट मोड",
            .es: "modo inserción", .fr: "mode insertion",
            .ar: "وضع الإدراج", .bn: "ইনসার্ট মোড",
            .pt: "modo inserção", .ru: "режим вставки", .ja: "挿入モード"
        ],
        "vimNormalMode": [
            .en: "normal mode", .zh: "普通模式", .hi: "नॉर्मल मोड",
            .es: "modo normal", .fr: "mode normal",
            .ar: "الوضع العادي", .bn: "নরমাল মোড",
            .pt: "modo normal", .ru: "обычный режим", .ja: "ノーマルモード"
        ],
        "vimGoBack": [
            .en: "go back", .zh: "返回", .hi: "वापस जाएं",
            .es: "volver", .fr: "retour",
            .ar: "رجوع", .bn: "ফিরে যান",
            .pt: "voltar", .ru: "назад", .ja: "戻る"
        ],
        "move": [
            .en: "move", .zh: "移动", .hi: "चलाएं",
            .es: "mover", .fr: "déplacer",
            .ar: "تحريك", .bn: "সরান",
            .pt: "mover", .ru: "двигаться", .ja: "移動"
        ],
        "richPaste": [
            .en: "rich paste", .zh: "富文本粘贴", .hi: "रिच पेस्ट",
            .es: "pegar formato", .fr: "coller riche",
            .ar: "لصق منسق", .bn: "রিচ পেস্ট",
            .pt: "colar formatado", .ru: "вставить формат", .ja: "リッチ貼り付け"
        ],
        "accessibilityMarkdownText": [
            .en: "Markdown text, Shift Enter to paste as formatted text",
            .zh: "Markdown 文本，Shift Enter 粘贴为格式化文本",
            .hi: "Markdown टेक्स्ट, Shift Enter से स्वरूपित टेक्स्ट पेस्ट करें",
            .es: "Texto Markdown, Shift Enter para pegar como texto formateado",
            .fr: "Texte Markdown, Shift Entrée pour coller en texte formaté",
            .ar: "نص Markdown، Shift Enter للصق كنص منسق",
            .bn: "Markdown টেক্সট, Shift Enter ফরম্যাটেড টেক্সট হিসেবে পেস্ট করুন",
            .pt: "Texto Markdown, Shift Enter para colar como texto formatado",
            .ru: "Текст Markdown, Shift Enter для вставки с форматированием",
            .ja: "Markdownテキスト、Shift Enterで書式付きテキストとして貼り付け"
        ],
        "markdownSupport": [
            .en: "Markdown Support", .zh: "Markdown 支持", .hi: "Markdown सहायता",
            .es: "Soporte Markdown", .fr: "Support Markdown",
            .ar: "دعم Markdown", .bn: "Markdown সমর্থন",
            .pt: "Suporte Markdown", .ru: "Поддержка Markdown", .ja: "Markdown サポート"
        ],
        "helpDismissEsc": [
            .en: "Esc to close help", .zh: "Esc 关闭帮助", .hi: "Esc सहायता बंद करें",
            .es: "Esc para cerrar ayuda", .fr: "Esc pour fermer l'aide",
            .ar: "Esc لإغلاق المساعدة", .bn: "Esc সাহায্য বন্ধ করুন",
            .pt: "Esc para fechar ajuda", .ru: "Esc закрыть справку", .ja: "Esc でヘルプを閉じる"
        ],
        "helpCloseHelp": [
            .en: "\u{2190} Close help", .zh: "\u{2190} 关闭帮助", .hi: "\u{2190} सहायता बंद करें",
            .es: "\u{2190} Cerrar ayuda", .fr: "\u{2190} Fermer l'aide",
            .ar: "إغلاق المساعدة \u{2192}", .bn: "\u{2190} সাহায্য বন্ধ করুন",
            .pt: "\u{2190} Fechar ajuda", .ru: "\u{2190} Закрыть справку", .ja: "\u{2190} ヘルプを閉じる"
        ],
        "helpNavHint": [
            .en: "j/k navigate  Enter follow  Esc close help",
            .zh: "j/k 导航  Enter 跟随  Esc 关闭帮助",
            .hi: "j/k नेविगेट  Enter अनुसरण  Esc सहायता बंद",
            .es: "j/k navegar  Enter seguir  Esc cerrar ayuda",
            .fr: "j/k naviguer  Enter suivre  Esc fermer l'aide",
            .ar: "j/k تنقل  Enter متابعة  Esc إغلاق المساعدة",
            .bn: "j/k নেভিগেট  Enter অনুসরণ  Esc সাহায্য বন্ধ",
            .pt: "j/k navegar  Enter seguir  Esc fechar ajuda",
            .ru: "j/k навигация  Enter перейти  Esc закрыть справку",
            .ja: "j/k 移動  Enter 開く  Esc ヘルプを閉じる"
        ],
        "helpNavHintBack": [
            .en: "j/k navigate  Enter follow  Backspace back  Esc close help",
            .zh: "j/k 导航  Enter 跟随  Backspace 返回  Esc 关闭帮助",
            .hi: "j/k नेविगेट  Enter अनुसरण  Backspace वापस  Esc सहायता बंद",
            .es: "j/k navegar  Enter seguir  Backspace volver  Esc cerrar ayuda",
            .fr: "j/k naviguer  Enter suivre  Backspace retour  Esc fermer l'aide",
            .ar: "j/k تنقل  Enter متابعة  Backspace رجوع  Esc إغلاق المساعدة",
            .bn: "j/k নেভিগেট  Enter অনুসরণ  Backspace পিছনে  Esc সাহায্য বন্ধ",
            .pt: "j/k navegar  Enter seguir  Backspace voltar  Esc fechar ajuda",
            .ru: "j/k навигация  Enter перейти  Backspace назад  Esc закрыть справку",
            .ja: "j/k 移動  Enter 開く  Backspace 戻る  Esc ヘルプを閉じる"
        ],
        "helpPowerFeatures": [
            .en: "POWER FEATURES", .zh: "高级功能", .hi: "पावर सुविधाएं",
            .es: "FUNCIONES AVANZADAS", .fr: "FONCTIONS AVANCÉES",
            .ar: "ميزات متقدمة", .bn: "পাওয়ার ফিচার",
            .pt: "RECURSOS AVANÇADOS", .ru: "РАСШИРЕННЫЕ ФУНКЦИИ", .ja: "パワー機能"
        ],
        "helpMarkdownLink": [
            .en: "Markdown Support →", .zh: "Markdown 支持 →", .hi: "Markdown सहायता →",
            .es: "Soporte Markdown →", .fr: "Support Markdown →",
            .ar: "→ دعم Markdown", .bn: "Markdown সমর্থন →",
            .pt: "Suporte Markdown →", .ru: "Поддержка Markdown →", .ja: "Markdown サポート →"
        ],
        "markdownHelpBack": [
            .en: "← Help", .zh: "← 帮助", .hi: "← सहायता",
            .es: "← Ayuda", .fr: "← Aide",
            .ar: "مساعدة ←", .bn: "← সাহায্য",
            .pt: "← Ajuda", .ru: "← Справка", .ja: "← ヘルプ"
        ],
        "markdownHelpBindings": [
            .en: "KEYBINDINGS", .zh: "快捷键", .hi: "कुंजी बाइंडिंग",
            .es: "ATAJOS DE TECLADO", .fr: "RACCOURCIS CLAVIER",
            .ar: "اختصارات لوحة المفاتيح", .bn: "কী বাইন্ডিং",
            .pt: "ATALHOS DE TECLADO", .ru: "СОЧЕТАНИЯ КЛАВИШ", .ja: "キーバインド"
        ],
        "markdownHelpShiftEnterRich": [
            .en: "Shift+Enter on markdown text → paste as rich text",
            .zh: "Shift+Enter 在 markdown 文本上 → 粘贴为富文本",
            .hi: "Shift+Enter markdown टेक्स्ट पर → रिच टेक्स्ट के रूप में पेस्ट करें",
            .es: "Shift+Enter en texto markdown → pegar como texto enriquecido",
            .fr: "Shift+Enter sur texte markdown → coller en texte enrichi",
            .ar: "Shift+Enter على نص markdown → لصق كنص منسق",
            .bn: "Shift+Enter markdown টেক্সটে → রিচ টেক্সট হিসেবে পেস্ট করুন",
            .pt: "Shift+Enter em texto markdown → colar como texto formatado",
            .ru: "Shift+Enter на тексте markdown → вставить как форматированный текст",
            .ja: "Shift+Enter markdownテキスト → リッチテキストとして貼り付け"
        ],
        "markdownHelpShiftEnterPlain": [
            .en: "Shift+Enter on formatted text → paste as plain text",
            .zh: "Shift+Enter 在格式化文本上 → 粘贴为纯文本",
            .hi: "Shift+Enter स्वरूपित टेक्स्ट पर → सादा टेक्स्ट के रूप में पेस्ट करें",
            .es: "Shift+Enter en texto formateado → pegar como texto plano",
            .fr: "Shift+Enter sur texte formaté → coller en texte brut",
            .ar: "Shift+Enter على نص منسق → لصق كنص عادي",
            .bn: "Shift+Enter ফরম্যাটেড টেক্সটে → সাধারণ টেক্সট হিসেবে পেস্ট করুন",
            .pt: "Shift+Enter em texto formatado → colar como texto simples",
            .ru: "Shift+Enter на форматированном тексте → вставить как обычный текст",
            .ja: "Shift+Enter 書式付きテキスト → テキストとして貼り付け"
        ],
        "markdownHelpCheatSheet": [
            .en: "CHEAT SHEET", .zh: "速查表", .hi: "चीट शीट",
            .es: "HOJA DE REFERENCIA", .fr: "AIDE-MÉMOIRE",
            .ar: "ورقة مرجعية", .bn: "চিট শিট",
            .pt: "FOLHA DE REFERÊNCIA", .ru: "ШПАРГАЛКА", .ja: "チートシート"
        ],
        "markdownHelpHeadings": [
            .en: "# Heading 1  ## Heading 2  ### Heading 3",
            .zh: "# Heading 1  ## Heading 2  ### Heading 3",
            .hi: "# Heading 1  ## Heading 2  ### Heading 3",
            .es: "# Heading 1  ## Heading 2  ### Heading 3",
            .fr: "# Heading 1  ## Heading 2  ### Heading 3",
            .ar: "# Heading 1  ## Heading 2  ### Heading 3",
            .bn: "# Heading 1  ## Heading 2  ### Heading 3",
            .pt: "# Heading 1  ## Heading 2  ### Heading 3",
            .ru: "# Heading 1  ## Heading 2  ### Heading 3",
            .ja: "# Heading 1  ## Heading 2  ### Heading 3"
        ],
        "markdownHelpBold": [
            .en: "**bold**", .zh: "**bold**", .hi: "**bold**", .es: "**bold**",
            .fr: "**bold**", .ar: "**bold**", .bn: "**bold**", .pt: "**bold**",
            .ru: "**bold**", .ja: "**bold**"
        ],
        "markdownHelpItalic": [
            .en: "*italic*", .zh: "*italic*", .hi: "*italic*", .es: "*italic*",
            .fr: "*italic*", .ar: "*italic*", .bn: "*italic*", .pt: "*italic*",
            .ru: "*italic*", .ja: "*italic*"
        ],
        "markdownHelpCode": [
            .en: "`inline code`", .zh: "`inline code`", .hi: "`inline code`", .es: "`inline code`",
            .fr: "`inline code`", .ar: "`inline code`", .bn: "`inline code`", .pt: "`inline code`",
            .ru: "`inline code`", .ja: "`inline code`"
        ],
        "markdownHelpCodeBlock": [
            .en: "```code block```", .zh: "```code block```", .hi: "```code block```",
            .es: "```code block```", .fr: "```code block```", .ar: "```code block```",
            .bn: "```code block```", .pt: "```code block```",
            .ru: "```code block```", .ja: "```code block```"
        ],
        "markdownHelpLink": [
            .en: "[text](url)", .zh: "[text](url)", .hi: "[text](url)", .es: "[text](url)",
            .fr: "[text](url)", .ar: "[text](url)", .bn: "[text](url)", .pt: "[text](url)",
            .ru: "[text](url)", .ja: "[text](url)"
        ],
        "markdownHelpList": [
            .en: "- unordered list", .zh: "- unordered list", .hi: "- unordered list",
            .es: "- unordered list", .fr: "- unordered list", .ar: "- unordered list",
            .bn: "- unordered list", .pt: "- unordered list",
            .ru: "- unordered list", .ja: "- unordered list"
        ],
        "markdownHelpOrderedList": [
            .en: "1. ordered list", .zh: "1. ordered list", .hi: "1. ordered list",
            .es: "1. ordered list", .fr: "1. ordered list", .ar: "1. ordered list",
            .bn: "1. ordered list", .pt: "1. ordered list",
            .ru: "1. ordered list", .ja: "1. ordered list"
        ],
        "markdownHelpBlockquote": [
            .en: "> blockquote", .zh: "> blockquote", .hi: "> blockquote",
            .es: "> blockquote", .fr: "> blockquote", .ar: "> blockquote",
            .bn: "> blockquote", .pt: "> blockquote",
            .ru: "> blockquote", .ja: "> blockquote"
        ],
        "markdownHelpHr": [
            .en: "--- horizontal rule", .zh: "--- 水平分割线", .hi: "--- क्षैतिज रेखा",
            .es: "--- línea horizontal", .fr: "--- ligne horizontale",
            .ar: "--- خط أفقي", .bn: "--- অনুভূমিক রেখা",
            .pt: "--- linha horizontal", .ru: "--- горизонтальная линия", .ja: "--- 水平線"
        ],
        "editing": [
            .en: "Editing", .zh: "编辑", .hi: "संपादन", .es: "Edición", .fr: "Édition",
            .ar: "تحرير", .bn: "সম্পাদনা", .pt: "Edição", .ru: "Редактирование", .ja: "編集"
        ],
        "helpEditingLink": [
            .en: "Editing →", .zh: "编辑 →", .hi: "संपादन →", .es: "Edición →", .fr: "Édition →",
            .ar: "→ تحرير", .bn: "সম্পাদনা →", .pt: "Edição →", .ru: "Редактирование →", .ja: "編集 →"
        ],
        "editingHelpCtrlEText": [
            .en: "Ctrl+E  Edit text items",
            .zh: "Ctrl+E  编辑文本条目",
            .hi: "Ctrl+E  टेक्स्ट आइटम संपादित करें",
            .es: "Ctrl+E  Editar elementos de texto",
            .fr: "Ctrl+E  Modifier les éléments texte",
            .ar: "Ctrl+E  تحرير العناصر النصية",
            .bn: "Ctrl+E  টেক্সট আইটেম সম্পাদনা করুন",
            .pt: "Ctrl+E  Editar itens de texto",
            .ru: "Ctrl+E  Редактировать текстовые элементы",
            .ja: "Ctrl+E  テキスト項目を編集"
        ],
        "editingHelpCtrlEMultimedia": [
            .en: "Ctrl+E  View images and file URLs",
            .zh: "Ctrl+E  查看图片和文件 URL",
            .hi: "Ctrl+E  चित्र और फ़ाइल URL देखें",
            .es: "Ctrl+E  Ver imágenes y URL de archivos",
            .fr: "Ctrl+E  Afficher les images et URL de fichiers",
            .ar: "Ctrl+E  عرض الصور وعناوين الملفات",
            .bn: "Ctrl+E  ছবি এবং ফাইল URL দেখুন",
            .pt: "Ctrl+E  Ver imagens e URLs de arquivos",
            .ru: "Ctrl+E  Просмотр изображений и URL файлов",
            .ja: "Ctrl+E  画像とファイルURLを表示"
        ],
        "editingHelpSeeAlsoMarkdown": [
            .en: "See also: Markdown Support →",
            .zh: "另见：Markdown 支持 →",
            .hi: "यह भी देखें: Markdown सहायता →",
            .es: "Ver también: Soporte Markdown →",
            .fr: "Voir aussi : Support Markdown →",
            .ar: "→ انظر أيضاً: دعم Markdown",
            .bn: "আরও দেখুন: Markdown সমর্থন →",
            .pt: "Veja também: Suporte Markdown →",
            .ru: "См. также: Поддержка Markdown →",
            .ja: "関連項目: Markdown サポート →"
        ],
        "editingHelpVimEnable": [
            .en: "Click here to enable vim-style editing",
            .zh: "点击此处启用 Vim 风格编辑",
            .hi: "Vim शैली संपादन सक्षम करने के लिए यहां क्लिक करें",
            .es: "Haz clic aquí para activar la edición estilo Vim",
            .fr: "Cliquez ici pour activer l'édition style Vim",
            .ar: "انقر هنا لتفعيل تحرير بأسلوب Vim",
            .bn: "Vim স্টাইল সম্পাদনা সক্ষম করতে এখানে ক্লিক করুন",
            .pt: "Clique aqui para ativar edição estilo Vim",
            .ru: "Нажмите, чтобы включить редактирование в стиле Vim",
            .ja: "クリックして Vim スタイル編集を有効にする"
        ],
        "editingHelpVimDisable": [
            .en: "Click here to disable vim-style editing",
            .zh: "点击此处禁用 Vim 风格编辑",
            .hi: "Vim शैली संपादन अक्षम करने के लिए यहां क्लिक करें",
            .es: "Haz clic aquí para desactivar la edición estilo Vim",
            .fr: "Cliquez ici pour désactiver l'édition style Vim",
            .ar: "انقر هنا لتعطيل تحرير بأسلوب Vim",
            .bn: "Vim স্টাইল সম্পাদনা নিষ্ক্রিয় করতে এখানে ক্লিক করুন",
            .pt: "Clique aqui para desativar edição estilo Vim",
            .ru: "Нажмите, чтобы отключить редактирование в стиле Vim",
            .ja: "クリックして Vim スタイル編集を無効にする"
        ],
        "settings": [
            .en: "Settings", .zh: "设置", .hi: "सेटिंग्स", .es: "Ajustes", .fr: "Réglages",
            .ar: "الإعدادات", .bn: "সেটিংস", .pt: "Configurações", .ru: "Настройки", .ja: "設定"
        ],
        "helpSettingsLink": [
            .en: "Settings →", .zh: "设置 →", .hi: "सेटिंग्स →", .es: "Ajustes →", .fr: "Réglages →",
            .ar: "→ الإعدادات", .bn: "সেটিংস →", .pt: "Configurações →", .ru: "Настройки →", .ja: "設定 →"
        ],
        "settingsHelpRightClick": [
            .en: "Right-click the [F] menu bar icon",
            .zh: "右键点击菜单栏的 [F] 图标",
            .hi: "मेनू बार में [F] आइकन पर राइट-क्लिक करें",
            .es: "Haz clic derecho en el icono [F] de la barra de menú",
            .fr: "Faites un clic droit sur l'icône [F] dans la barre de menus",
            .ar: "انقر بزر الماوس الأيمن على أيقونة [F] في شريط القوائم",
            .bn: "মেনু বারে [F] আইকনে ডান-ক্লিক করুন",
            .pt: "Clique com o botão direito no ícone [F] na barra de menus",
            .ru: "Нажмите правой кнопкой на значок [F] в строке меню",
            .ja: "メニューバーの [F] アイコンを右クリック"
        ],
        "settingsHelpAvailable": [
            .en: "Language, keyboard shortcut, launch at login, vim mode",
            .zh: "语言、快捷键、登录时启动、Vim 模式",
            .hi: "भाषा, कीबोर्ड शॉर्टकट, लॉगिन पर शुरू, Vim मोड",
            .es: "Idioma, atajo de teclado, iniciar al acceder, modo Vim",
            .fr: "Langue, raccourci clavier, ouvrir au démarrage, mode Vim",
            .ar: "اللغة، اختصار لوحة المفاتيح، التشغيل عند الدخول، وضع Vim",
            .bn: "ভাষা, কীবোর্ড শর্টকাট, লগইনে চালু, Vim মোড",
            .pt: "Idioma, atalho de teclado, abrir ao iniciar, modo Vim",
            .ru: "Язык, сочетание клавиш, запуск при входе, режим Vim",
            .ja: "言語、キーボードショートカット、ログイン時起動、Vimモード"
        ],
        "contextPaste": [
            .en: "Paste", .zh: "粘贴", .hi: "पेस्ट करें", .es: "Pegar", .fr: "Coller",
            .ar: "لصق", .bn: "পেস্ট", .pt: "Colar", .ru: "Вставить", .ja: "貼り付け"
        ],
        "contextPasteAsPlainText": [
            .en: "Paste as Plain Text", .zh: "粘贴为纯文本", .hi: "सादा टेक्स्ट के रूप में पेस्ट करें",
            .es: "Pegar como texto plano", .fr: "Coller en texte brut",
            .ar: "لصق كنص عادي", .bn: "সাধারণ টেক্সট হিসেবে পেস্ট",
            .pt: "Colar como texto simples", .ru: "Вставить как текст", .ja: "テキストとして貼り付け"
        ],
        "contextPasteAsRichText": [
            .en: "Paste as Rich Text", .zh: "粘贴为富文本", .hi: "रिच टेक्स्ट के रूप में पेस्ट करें",
            .es: "Pegar como texto enriquecido", .fr: "Coller en texte enrichi",
            .ar: "لصق كنص منسق", .bn: "রিচ টেক্সট হিসেবে পেস্ট",
            .pt: "Colar como texto formatado", .ru: "Вставить с форматированием", .ja: "リッチテキストとして貼り付け"
        ],
        "contextPasteAsMarkdown": [
            .en: "Paste as Markdown", .zh: "粘贴为 Markdown", .hi: "Markdown के रूप में पेस्ट करें",
            .es: "Pegar como Markdown", .fr: "Coller en Markdown",
            .ar: "لصق كـ Markdown", .bn: "Markdown হিসেবে পেস্ট",
            .pt: "Colar como Markdown", .ru: "Вставить как Markdown", .ja: "Markdownとして貼り付け"
        ],
        "contextEdit": [
            .en: "Edit", .zh: "编辑", .hi: "संपादित करें", .es: "Editar", .fr: "Modifier",
            .ar: "تحرير", .bn: "সম্পাদনা", .pt: "Editar", .ru: "Править", .ja: "編集"
        ],
        "contextView": [
            .en: "View", .zh: "查看", .hi: "देखें", .es: "Ver", .fr: "Voir",
            .ar: "عرض", .bn: "দেখুন", .pt: "Ver", .ru: "Просмотр", .ja: "表示"
        ],
        "contextExpand": [
            .en: "Expand", .zh: "展开", .hi: "विस्तार करें", .es: "Expandir", .fr: "Développer",
            .ar: "توسيع", .bn: "প্রসারিত", .pt: "Expandir", .ru: "Развернуть", .ja: "展開"
        ],
        "contextCollapse": [
            .en: "Collapse", .zh: "折叠", .hi: "संक्षिप्त करें", .es: "Contraer", .fr: "Réduire",
            .ar: "طي", .bn: "সঙ্কুচিত", .pt: "Recolher", .ru: "Свернуть", .ja: "折りたたむ"
        ],
        "contextStar": [
            .en: "Star", .zh: "收藏", .hi: "स्टार करें", .es: "Destacar", .fr: "Ajouter aux favoris",
            .ar: "تمييز", .bn: "তারকা দিন", .pt: "Favoritar", .ru: "Отметить", .ja: "スターを付ける"
        ],
        "contextUnstar": [
            .en: "Unstar", .zh: "取消收藏", .hi: "स्टार हटाएं", .es: "Quitar destacado", .fr: "Retirer des favoris",
            .ar: "إلغاء التمييز", .bn: "তারকা সরান", .pt: "Remover favorito", .ru: "Снять отметку", .ja: "スターを外す"
        ],
        "contextDelete": [
            .en: "Delete", .zh: "删除", .hi: "हटाएं", .es: "Eliminar", .fr: "Supprimer",
            .ar: "حذف", .bn: "মুছুন", .pt: "Excluir", .ru: "Удалить", .ja: "削除"
        ],
        "contextRevealInFinder": [
            .en: "Reveal in Finder", .zh: "在 Finder 中显示", .hi: "Finder में दिखाएं",
            .es: "Mostrar en Finder", .fr: "Afficher dans le Finder",
            .ar: "عرض في Finder", .bn: "Finder-এ দেখান",
            .pt: "Mostrar no Finder", .ru: "Показать в Finder", .ja: "Finderで表示"
        ],
        "formattedPaste": [
            .en: "formatted", .zh: "格式化", .hi: "स्वरूपित",
            .es: "formateado", .fr: "formaté",
            .ar: "منسق", .bn: "ফরম্যাটেড",
            .pt: "formatado", .ru: "формат", .ja: "整形"
        ],
        "accessibilityCodeText": [
            .en: "Code text, Shift Enter to paste with syntax highlighting",
            .zh: "代码文本，Shift Enter 粘贴并语法高亮",
            .hi: "कोड टेक्स्ट, Shift Enter सिंटैक्स हाइलाइटिंग के साथ पेस्ट करें",
            .es: "Texto de código, Shift Enter para pegar con resaltado de sintaxis",
            .fr: "Texte de code, Shift Entrée pour coller avec coloration syntaxique",
            .ar: "نص برمجي، Shift Enter للصق مع تلوين بناء الجملة",
            .bn: "কোড টেক্সট, Shift Enter সিনট্যাক্স হাইলাইটিং সহ পেস্ট করুন",
            .pt: "Texto de código, Shift Enter para colar com destaque de sintaxe",
            .ru: "Текст кода, Shift Enter для вставки с подсветкой синтаксиса",
            .ja: "コードテキスト、Shift Enterでシンタックスハイライト付きで貼り付け"
        ],
        "contextPasteFormatted": [
            .en: "Paste Formatted", .zh: "粘贴为格式化文本", .hi: "स्वरूपित पेस्ट करें",
            .es: "Pegar formateado", .fr: "Coller formaté",
            .ar: "لصق منسق", .bn: "ফরম্যাটেড পেস্ট",
            .pt: "Colar formatado", .ru: "Вставить с форматированием", .ja: "整形して貼り付け"
        ],
        "focusMode": [
            .en: "focus mode", .zh: "专注模式", .hi: "फोकस मोड",
            .es: "modo enfoque", .fr: "mode focus",
            .ar: "وضع التركيز", .bn: "ফোকাস মোড",
            .pt: "modo foco", .ru: "режим фокуса", .ja: "フォーカスモード"
        ],
        "regularSize": [
            .en: "regular size", .zh: "常规大小", .hi: "सामान्य आकार",
            .es: "tamaño normal", .fr: "taille normale",
            .ar: "الحجم العادي", .bn: "সাধারণ আকার",
            .pt: "tamanho normal", .ru: "обычный размер", .ja: "通常サイズ"
        ],
    ]
}
