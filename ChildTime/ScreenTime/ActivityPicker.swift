import SwiftUI
import FamilyControls

/// Apple's app picker used to open as a bare, wordless sheet: a system list of
/// every app on the device with no hint of what the parent is choosing, or why.
/// A parent opening it during setup had to guess — and guessing is where they
/// stopped. iOS 26.2 lets us put our own title and explanation *inside* Apple's
/// sheet, so every picker in Tofy now says which list it is filling.
///
/// One wrapper for every call site: below iOS 26.2 it falls back to the plain
/// picker, so nothing changes for older systems.
extension View {
    @ViewBuilder
    func tofyActivityPicker(
        title: String,
        header: String,
        footer: String,
        isPresented: Binding<Bool>,
        selection: Binding<FamilyActivitySelection>
    ) -> some View {
        if #available(iOS 26.2, *) {
            self.familyActivityPicker(title: title, headerText: header, footerText: footer,
                                      isPresented: isPresented, selection: selection)
        } else {
            self.familyActivityPicker(isPresented: isPresented, selection: selection)
        }
    }
}

/// The Hebrew shown inside Apple's picker, per list. Kept together so the four
/// lists stay distinguishable from one another — a parent who opens the wrong
/// one should notice immediately.
enum PickerCopy {
    /// The apps that stay locked until the child earns minutes.
    static let blocked = (
        title: "אֵילוּ אַפְלִיקַצְיוֹת לִנְעֹל",
        header: "אֵלֶּה יִנָּעֲלוּ עַד שֶׁהַיֶּלֶד יַרְוִיחַ דַּקּוֹת מִשְׂחָק.",
        footer: "אֶפְשָׁר לִבְחֹר קָטֵגוֹרְיָה שְׁלֵמָה (מִשְׂחָקִים, רְשָׁתוֹת חֶבְרָתִיּוֹת) אוֹ אַפְלִיקַצְיוֹת מְסֻיָּמוֹת. תָּמִיד אֶפְשָׁר לְשַׁנּוֹת."
    )
    /// Apps that are never locked, whatever else is blocked.
    static let alwaysAllowed = (
        title: "מָה תָּמִיד פָּתוּחַ",
        header: "אֵלֶּה לֹא יִנָּעֲלוּ אַף פַּעַם — גַּם אִם הַקָּטֵגוֹרְיָה שֶׁלָּהֶם חֲסוּמָה.",
        footer: "מַתְאִים לִשְׁעוֹן מְעוֹרֵר, מַצְלֵמָה, טֶלֶפוֹן אוֹ אַפְלִיקַצְיָה לִמּוּדִית שֶׁתָּמִיד מֻתֶּרֶת."
    )
    /// A one-off window for specific apps.
    static let temporaryAllow = (
        title: "לִפְתֹּחַ עַכְשָׁו לִזְמַן קָצוּב",
        header: "בַּחֲרוּ אֶת הָאַפְלִיקַצְיוֹת שֶׁיִּפָּתְחוּ עַכְשָׁו, וְאַחַר כָּךְ אֶת מֶשֶׁךְ הַזְּמַן.",
        footer: "כָּל הַשְּׁאָר נִשְׁאָר נָעוּל. בְּתֹם הַזְּמַן הֵן נִנְעָלוֹת בַּחֲזָרָה לְבַד."
    )
    /// The "block everything except these" model on a child's device.
    static let allowList = (
        title: "מָה נִשְׁאָר פָּתוּחַ",
        header: "בַּמַּצָּב הַזֶּה הַכֹּל נָעוּל חוּץ מִמָּה שֶׁתִּבְחֲרוּ כָּאן.",
        footer: "כְּדַאי לִכְלֹל טֶלֶפוֹן, הוֹדָעוֹת וּמַצְלֵמָה — וְאֶת טוֹפִי עַצְמָהּ."
    )
    /// Kid Mode on a parent's own phone — an allow-list, the inverse.
    static let kidMode = (
        title: "מָה מֻתָּר בְּמַצַּב יֶלֶד",
        header: "רַק מָה שֶׁתִּבְחֲרוּ יִשָּׁאֵר פָּתוּחַ בַּמַּכְשִׁיר שֶׁלָּכֶם. כָּל הַשְּׁאָר נִנְעָל.",
        footer: "כְּדַאי לִכְלֹל אֶת טוֹפִי עַצְמָהּ, כְּדֵי שֶׁהַיֶּלֶד תָּמִיד יוּכַל לַחֲזֹר אֵלֶיהָ."
    )
}
