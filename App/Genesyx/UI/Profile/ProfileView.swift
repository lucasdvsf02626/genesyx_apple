import SwiftUI
import GenesyxCore

/// Profile — account, focus toggle, partner linking, preferences (theme/push), and about.
/// Ported from the Android `ProfileScreen` + `ProfileViewModel`.
struct ProfileView: View {

    private static let privacyPolicyURL = URL(string: "https://genesyx.co.uk/policies/privacy-policy")!
    private static let supportURL = URL(string: "https://genesyx.co.uk")!

    @EnvironmentObject private var session: SessionRepository
    @EnvironmentObject private var prefs: PreferencesRepository
    @EnvironmentObject private var notifications: NotificationService
    @EnvironmentObject private var cycle: CycleRepository

    @State private var personalOpen = false
    @State private var healthOpen = false
    @State private var trackingPrefsOpen = false
    @State private var detail: String?
    @State private var deleteOpen = false
    @State private var deleteError: String?
    @State private var resetConfirm = false
    @State private var resetResult: String?
    @State private var showAuth = false
    @State private var showPregnancy = false
    @State private var showReminderPrompt = false

    /// Hydration display unit (local, display-only — stored water values are always ml).
    @AppStorage(HydrationPrefs.unitKey) private var hydrationUnitRaw = HydrationUnit.glasses.rawValue

    /// Her own glass size in ml (T23). 0 means she never set one, which resolves to the 250 ml
    /// default. Display-only, exactly like the unit above: resizing the glass re-describes her
    /// logged water, it never rewrites it.
    @AppStorage(HydrationPrefs.glassMlKey) private var hydrationGlassMlRaw = 0
    /// Held as text so a half-typed "3" is not read as a 3 ml glass on the way to 300.
    @State private var glassSizeField = ""
    /// Losing focus is when a half-typed size stops being half-typed and becomes her answer.
    @FocusState private var glassSizeFocused: Bool

    private var name: String { session.displayName ?? "Guest" }

    private static let detailCopy: [String: String] = [
        "Privacy & Data": "Your saved data is private to your account. You can log out or delete your account from Profile.",
        "Help & Support": "For best results, complete cycle setup, log today, and use the pH tab to add pH readings.",
        "Medical Disclaimer": "Genesyx provides educational fertility and wellness information only. It is not a medical device and does not provide medical advice, diagnosis, or treatment. Always consult a qualified healthcare professional about your health, fertility, or any medical concerns. Do not rely on this app for contraception.",
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    userCard
                    focusSection
                    PartnerSectionView(showAuth: $showAuth)
                    accountGroup
                    trackingGroup
                    remindersSection
                    hydrationSection
                    themeSection
                    aboutGroup
                    signOutButton
                    if session.isSignedIn { deleteButton }
                }
                .padding(.horizontal, 20).padding(.vertical, 16)
            }
            .frame(maxWidth: .infinity)
            .gxPageBackground()
            .navigationTitle("Profile")
        }
        .sheet(isPresented: $showReminderPrompt) { reminderPromptSheet }
        .sheet(isPresented: $showAuth) { AuthView() }
        .sheet(isPresented: $showPregnancy) { PregnancyView() }
        .sheet(isPresented: $personalOpen) {
            PersonalDetailsSheet(initial: session.displayName, email: session.email) { session.updateDisplayName($0) }
        }
        // Her cycle is the health profile the app actually holds, and until now it could only be
        // changed from the Home setup card — which disappears once it has been filled in.
        .sheet(isPresented: $healthOpen) {
            CycleSettingsSheet(current: cycle.settings) { cycle.upsert($0) }
        }
        .sheet(isPresented: $trackingPrefsOpen) {
            TrackingPreferencesSheet(current: prefs.quizAnswers) { prefs.recordQuizAnswers($0) }
        }
        .alert(detail ?? "", isPresented: Binding(get: { detail != nil }, set: { if !$0 { detail = nil } })) {
            Button("Done") { detail = nil }
        } message: {
            Text(detail.flatMap { Self.detailCopy[$0] } ?? "This section is ready for your saved app settings.")
        }
        .alert("Delete your account?", isPresented: $deleteOpen) {
            Button("Delete", role: .destructive) {
                Task {
                    do { try await session.deleteAccount() }
                    catch { deleteError = "We couldn't delete your account. Please try again." }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete your account and all your data. This cannot be undone.")
        }
        .alert("Deletion failed", isPresented: Binding(get: { deleteError != nil }, set: { if !$0 { deleteError = nil } })) {
            Button("OK") { deleteError = nil }
        } message: {
            Text(deleteError ?? "")
        }
        .alert("Change password", isPresented: $resetConfirm) {
            Button("Send reset link") {
                Task {
                    do { try await session.resetPassword(); resetResult = "Check your inbox — we've emailed you a link to reset your password." }
                    catch { resetResult = "We couldn't send the reset email. Please try again." }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("We'll email a password-reset link to \(session.email ?? "your account").")
        }
        .alert("Password reset", isPresented: Binding(get: { resetResult != nil }, set: { if !$0 { resetResult = nil } })) {
            Button("OK") { resetResult = nil }
        } message: {
            Text(resetResult ?? "")
        }
    }

    // MARK: User card

    private var userCard: some View {
        HStack(spacing: 16) {
            Text(name.first.map { String($0).uppercased() } ?? "G")
                .font(.system(size: 18, weight: .semibold)).foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(LinearGradient(colors: [GenesyxColor.babyLavender, GenesyxColor.electricPink], startPoint: .topLeading, endPoint: .bottomTrailing))
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.gxCardHeading).foregroundStyle(GenesyxColor.foreground)
                Text(session.email ?? "Sign in to sync your data").font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground)
            }
            Spacer()
        }
        .padding(20).background(GenesyxColor.card).clipShape(RoundedRectangle(cornerRadius: 24))
    }

    // MARK: Focus

    private var focusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            groupLabel("Current focus")
            HStack(spacing: 6) {
                focusSeg("Fertility Prep", id: "focus.prep", selected: prefs.focusMode == .prep) {
                    prefs.focusMode = .prep
                }
                // Shows the "coming soon" teaser and changes nothing else, because there is nothing
                // else to change: no screen in the app behaves differently in pregnancy mode. It
                // used to store `.pregnancy` and sync it, which left the segment reading Pregnancy
                // for good — on this phone, on the server and on Android — while every screen went
                // on doing fertility prep, and while the sheet's own button said "Keep tracking".
                focusSeg("Pregnancy", id: "focus.pregnancy", selected: prefs.focusMode == .pregnancy) {
                    showPregnancy = true
                }
            }
            .padding(4).background(GenesyxColor.muted).clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private func focusSeg(_ label: String, id: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Text(label).font(.system(size: 13, weight: .medium))
            .foregroundStyle(selected ? GenesyxColor.foreground : GenesyxColor.mutedForeground)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(selected ? GenesyxColor.card : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .onTapGesture(perform: action)
            .accessibilityIdentifier(id)
            // Which segment is chosen was said in colour and background alone, so VoiceOver read
            // both of them the same way and nothing outside the view could tell them apart either.
            .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: Groups

    private var accountGroup: some View {
        VStack(alignment: .leading, spacing: 8) {
            groupLabel("Account")
            cardGroup {
                rowItem("Personal Details") { session.isSignedIn ? (personalOpen = true) : (showAuth = true) }
                divider
                rowItem("Change password") {
                    guard session.isSignedIn else { showAuth = true; return }
                    // A social sign-in can leave us without an address. Offering to email a link
                    // there anyway ended in "please try again" on a call that could never succeed.
                    if session.email?.isEmpty == false {
                        resetConfirm = true
                    } else {
                        resetResult = "We don't have an email address for this account. Get in touch through Help & Support and we'll reset your password for you."
                    }
                }
            }
        }
    }

    private var trackingGroup: some View {
        VStack(alignment: .leading, spacing: 8) {
            groupLabel("Tracking")
            cardGroup {
                rowItem("Health Profile") { healthOpen = true }
                divider
                rowItem("Tracking Preferences") { trackingPrefsOpen = true }
            }
        }
    }

    /// Reminders. Turning this on opens a sheet that says what she'll get BEFORE iOS asks for
    /// permission — the system dialog only appears once, so it should never be spent on a user who
    /// doesn't yet know what she's agreeing to. Nothing is requested at launch.
    private var remindersSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            groupLabel("Notifications")
            cardGroup {
                // "All", not "Weekly". This is the master switch — `NotificationService.isActive`
                // gates every category on `pushEnabled`, and turning it off cancels the lot: the
                // daily supplement reminders, the evening check-in, and the fertile-window nudge
                // she is here for. A woman declining a weekly digest was silently declining that.
                Toggle("All reminders", isOn: Binding(
                    get: { notifications.isOn },           // she asked for them AND iOS agreed
                    set: { on in
                        if on && notifications.authorizationStatus == .notDetermined {
                            showReminderPrompt = true      // explain first, then ask
                        } else {
                            notifications.setEnabled(on)
                        }
                    }
                ))
                .tint(GenesyxColor.primary)
                .foregroundStyle(GenesyxColor.foreground)
                .padding(.horizontal, 14).padding(.vertical, 8)

                if notifications.isOn {
                    divider
                    HStack {
                        Text("Reminder time").font(.system(size: 14.5)).foregroundStyle(GenesyxColor.foreground)
                        Spacer()
                        Picker("", selection: Binding(
                            get: { prefs.reminderHour },
                            set: { prefs.reminderHour = $0 }
                        )) {
                            ForEach(0..<24, id: \.self) { h in Text(gxHourLabel(h)).tag(h) }
                        }
                        .labelsHidden()
                        .tint(GenesyxColor.primary)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 8)

                    ForEach(NotificationCategory.allCases, id: \.self) { category in
                        divider
                        Toggle(category.title, isOn: Binding(
                            get: { !prefs.mutedNotifications.contains(category) },
                            set: { on in
                                if on { prefs.mutedNotifications.remove(category) }
                                else { prefs.mutedNotifications.insert(category) }
                            }
                        ))
                        .tint(GenesyxColor.primary)
                        .font(.system(size: 14.5))
                        .foregroundStyle(GenesyxColor.foreground)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .accessibilityIdentifier("notifCategory.\(category.rawValue)")
                    }
                }
            }
            if notifications.isSystemDenied && prefs.pushEnabled {
                Button {
                    #if canImport(UIKit)
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    #endif
                } label: {
                    Text("Notifications are off for Genesyx — enable them in Settings")
                        .font(.gxBodySmall).foregroundStyle(GenesyxColor.primary)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 4)
                }
            }
        }
    }

    private var reminderPromptSheet: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Gentle reminders").font(.gxCardHeading).foregroundStyle(GenesyxColor.foreground)
            Text("An evening check-in on days you haven't logged, a weekly pH reminder, a note when your cycle reaches its predicted window, and a Sunday read. Just one a day at most, and never a word about a streak you've missed.")
                .font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground)
            Text("You can switch the lot off, or any one of them on its own, whenever you like.")
                .font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground)
            Spacer()
            GxPrimaryButton(title: "Turn on reminders") {
                showReminderPrompt = false
                notifications.setEnabled(true)
            }
            Button("Not now") { showReminderPrompt = false }
                .font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground)
                .frame(maxWidth: .infinity)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(GenesyxColor.background)
        .presentationDetents([.height(320)])
    }

    private var hydrationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            groupLabel("Hydration")
            HStack {
                Text("Unit").font(.system(size: 14.5)).foregroundStyle(GenesyxColor.foreground)
                Spacer()
                Menu {
                    Picker("Unit", selection: $hydrationUnitRaw) {
                        ForEach(HydrationUnit.allCases) { unit in
                            Text(unit.settingsLabel).tag(unit.rawValue)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(HydrationUnit(rawValue: hydrationUnitRaw)?.settingsLabel ?? "Glasses")
                            .font(.system(size: 14.5, weight: .medium))
                        Image(systemName: "chevron.up.chevron.down").font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(GenesyxColor.primary)
                }
                .accessibilityIdentifier("hydrationUnitMenu")
            }
            .padding(.horizontal, 16).frame(minHeight: 52)
            .background(GenesyxColor.card).clipShape(RoundedRectangle(cornerRadius: 16))

            // Only glasses. A cup is a recipe measure at a fixed 240 ml, and millilitres are the
            // storage unit itself — neither is hers to resize, so offering it there would be a
            // control that does nothing.
            if HydrationUnit(rawValue: hydrationUnitRaw) == .glasses {
                HStack {
                    Text("Glass size").font(.system(size: 14.5)).foregroundStyle(GenesyxColor.foreground)
                    Spacer()
                    TextField(String(HydrationUnit.mlPerGlass), text: $glassSizeField)
                        .keyboardType(.numberPad)
                        .focused($glassSizeFocused)
                        .gxKeyboardDoneToolbar()
                        .multilineTextAlignment(.trailing)
                        .font(.system(size: 14.5, weight: .medium))
                        .foregroundStyle(GenesyxColor.primary)
                        .frame(width: 56)
                        .accessibilityIdentifier("hydrationGlassSizeField")
                        .accessibilityLabel("Glass size in millilitres")
                    Text("ml").font(.system(size: 14.5)).foregroundStyle(GenesyxColor.mutedForeground)
                }
                .padding(.horizontal, 16).frame(minHeight: 52)
                .background(GenesyxColor.card).clipShape(RoundedRectangle(cornerRadius: 16))
            }

            Text("A glass is yours to size — anything from \(HydrationUnit.glassRangeMl.lowerBound) to \(HydrationUnit.glassRangeMl.upperBound) ml. A cup stays 240 ml. This changes how amounts are shown; your logged totals are unchanged.")
                .font(.caption2).foregroundStyle(GenesyxColor.mutedForeground)
        }
        .onAppear { glassSizeField = String(HydrationPrefs.glassMl(from: hydrationGlassMlRaw)) }
        // Stored only once what she has typed is a usable size, so a half-typed "3" on the way to
        // "300" leaves her previous glass in place rather than briefly redefining it.
        .onChange(of: glassSizeField) { new in
            if let ml = Int(new), HydrationUnit.glassRangeMl.contains(ml) { hydrationGlassMlRaw = ml }
        }
        // Put the field back to what was actually saved, so an abandoned "3000" does not sit on
        // screen looking like the setting took.
        .onChange(of: hydrationUnitRaw) { _ in
            glassSizeField = String(HydrationPrefs.glassMl(from: hydrationGlassMlRaw))
        }
        // Leaving the field is when a half-typed size becomes her answer, so it is also where an
        // unusable one has to be dealt with. Until now it was dealt with in silence: the rule above
        // stores nothing outside 50–1000, so "3000" sat in the field reading exactly like a setting
        // that had taken while her glass was still 250, and the only thing that ever put the field
        // right was switching units — which nobody does to check a number they believe they saved.
        // Corrected to the nearest size she may actually have rather than reverted, because
        // reverting answers a woman who typed 3000 with a number she neither typed nor had.
        .onChange(of: glassSizeFocused) { focused in
            guard !focused else { return }
            let corrected = Int(glassSizeField).map {
                min(max($0, HydrationUnit.glassRangeMl.lowerBound), HydrationUnit.glassRangeMl.upperBound)
            } ?? HydrationPrefs.glassMl(from: hydrationGlassMlRaw)
            hydrationGlassMlRaw = corrected
            glassSizeField = String(corrected)
        }
    }

    private var themeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            groupLabel("Theme")
            HStack(spacing: 6) {
                themeSeg("System", .system)
                themeSeg("Light", .light)
                themeSeg("Dark", .dark)
            }
            .padding(4).background(GenesyxColor.muted).clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private func themeSeg(_ label: String, _ mode: ThemeMode) -> some View {
        let selected = prefs.themeMode == mode
        return Text(label).font(.system(size: 13, weight: .medium))
            .foregroundStyle(selected ? GenesyxColor.foreground : GenesyxColor.mutedForeground)
            .frame(maxWidth: .infinity, minHeight: 40)
            .background(selected ? GenesyxColor.card : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .onTapGesture { prefs.themeMode = mode }
    }

    private var aboutGroup: some View {
        VStack(alignment: .leading, spacing: 8) {
            groupLabel("About")
            cardGroup {
                rowItem("Privacy & Data") { detail = "Privacy & Data" }
                divider
                linkItem("Privacy Policy", destination: Self.privacyPolicyURL)
                divider
                linkItem("Help & Support", destination: Self.supportURL)
                divider
                rowItem("Medical Disclaimer") { detail = "Medical Disclaimer" }
                divider
                navRow("Medical Sources & Disclaimer") { MedicalSourcesView() }
            }
        }
    }

    private var signOutButton: some View {
        Button { session.isSignedIn ? session.signOut() : (showAuth = true) } label: {
            HStack(spacing: 8) {
                Image(systemName: session.isSignedIn ? "rectangle.portrait.and.arrow.right" : "person.crop.circle")
                Text(session.isSignedIn ? "Log out" : "Sign in").fontWeight(.semibold)
            }
            .foregroundStyle(GenesyxColor.destructive)
            .frame(maxWidth: .infinity).padding(.vertical, 16)
            .background(GenesyxColor.card).clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    private var deleteButton: some View {
        Button { deleteOpen = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "trash")
                Text("Delete account").fontWeight(.semibold)
            }
            .foregroundStyle(GenesyxColor.destructive)
            .frame(maxWidth: .infinity).padding(.vertical, 16)
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(GenesyxColor.destructive.opacity(0.4), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: Reusable bits

    private func groupLabel(_ text: String) -> some View {
        Eyebrow(text, color: GenesyxColor.mutedForeground).padding(.leading, 4)
    }

    private func cardGroup<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .background(GenesyxColor.card).clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func rowItem(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(label).font(.system(size: 14.5)).foregroundStyle(GenesyxColor.foreground)
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 14)).foregroundStyle(GenesyxColor.mutedForeground)
            }
            .padding(.horizontal, 16).frame(minHeight: 52)
        }
        .buttonStyle(.plain)
    }

    private func navRow<Destination: View>(_ label: String, @ViewBuilder destination: @escaping () -> Destination) -> some View {
        NavigationLink(destination: destination) {
            HStack {
                Text(label).font(.system(size: 14.5)).foregroundStyle(GenesyxColor.foreground)
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 14)).foregroundStyle(GenesyxColor.mutedForeground)
            }
            .padding(.horizontal, 16).frame(minHeight: 52)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(label)
    }

    private func linkItem(_ label: String, destination: URL) -> some View {
        Link(destination: destination) {
            HStack {
                Text(label).font(.system(size: 14.5)).foregroundStyle(GenesyxColor.foreground)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(GenesyxColor.mutedForeground)
            }
            .padding(.horizontal, 16).frame(minHeight: 52)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(label)
    }

    private var divider: some View {
        Rectangle().fill(GenesyxColor.border.opacity(0.5)).frame(height: 1).padding(.horizontal, 16)
    }
}

// MARK: - Partner section

private struct PartnerSectionView: View {
    @Binding var showAuth: Bool
    @EnvironmentObject private var session: SessionRepository
    @EnvironmentObject private var partner: PartnerRepository

    @State private var email = ""
    @State private var err: String?
    @State private var sending = false
    /// The invite just created, carrying the code the database issued — this is what she shares.
    @State private var justCreated: PartnerInvite?

    private var pending: [PartnerInvite] { partner.invites.filter { $0.status == .pending } }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow("Partner", color: GenesyxColor.mutedForeground).padding(.leading, 4)
            VStack(alignment: .leading, spacing: 0) {
                if !session.isSignedIn {
                    notSignedIn
                } else if let p = partner.partner {
                    linked(p)
                } else {
                    inviteForm
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20).background(GenesyxColor.card).clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private var notSignedIn: some View {
        VStack(spacing: 8) {
            Image(systemName: "heart.fill").font(.system(size: 24)).foregroundStyle(GenesyxColor.primary)
            Text("Add your partner").font(.gxCardHeadingSmall).foregroundStyle(GenesyxColor.foreground)
            Text("Sign in to invite a partner to join your journey.")
                .font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground).multilineTextAlignment(.center)
            Button("Sign in") { showAuth = true }
                .font(.gxBody.weight(.semibold)).foregroundStyle(GenesyxColor.primary).padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
    }

    private func linked(_ p: Partner) -> some View {
        HStack(spacing: 12) {
            Text(p.name.first.map { String($0).uppercased() } ?? "P")
                .font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(LinearGradient(colors: [GenesyxColor.babyLavender, GenesyxColor.electricPink], startPoint: .topLeading, endPoint: .bottomTrailing))
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(p.name).font(.gxBody.weight(.semibold)).foregroundStyle(GenesyxColor.foreground)
                Text("Linked partner").font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground)
            }
            Spacer()
            Button("Remove") {
                Task {
                    do { try await partner.unlink() }
                    catch { err = "Couldn't remove your partner. Please try again." }
                }
            }
            .foregroundStyle(GenesyxColor.destructive)
        }
    }

    private var inviteForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "heart.fill").font(.system(size: 14)).foregroundStyle(GenesyxColor.primary)
                Text("Add your partner").font(.gxCardHeadingSmall).foregroundStyle(GenesyxColor.foreground)
            }
            Text("Send an invite — when they accept, your accounts are linked. Your logs and readings stay private to you.")
                .font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground)
            TextField("partner@example.com", text: $email)
                .textInputAutocapitalization(.never).keyboardType(.emailAddress).autocorrectionDisabled()
                .padding(.horizontal, 14).frame(height: 52)
                .background(GenesyxColor.card).clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(err == nil ? GenesyxColor.border : GenesyxColor.destructive, lineWidth: 1))
                .onChange(of: email) { _ in err = nil }
            if let err { Text(err).font(.gxBodySmall).foregroundStyle(GenesyxColor.destructive) }
            Button {
                createInvite()
            } label: {
                HStack(spacing: 8) {
                    if sending { ProgressView().controlSize(.small) } else { Image(systemName: "envelope") }
                    Text(sending ? "Creating invite…" : "Create invite").fontWeight(.semibold)
                }
                .foregroundStyle(GenesyxColor.primary).frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .disabled(sending)

            if !pending.isEmpty {
                divider
                Eyebrow("Pending invites", color: GenesyxColor.mutedForeground)
                Text("An invite only works for the address it was sent to — she has to sign in with that email to accept.")
                    .font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground)
                ForEach(pending) { invite in
                    HStack(spacing: 12) {
                        Text(invite.email).font(.gxBodySmall).foregroundStyle(GenesyxColor.foreground)
                        Spacer()
                        // The step that was missing: creating a row invited nobody. This is how the
                        // link actually reaches her partner.
                        ShareLink(item: DeepLink.inviteShareText(code: invite.code, from: session.displayName)) {
                            Image(systemName: "square.and.arrow.up").font(.system(size: 14))
                                .foregroundStyle(GenesyxColor.primary)
                        }
                        Image(systemName: "xmark").font(.system(size: 13)).foregroundStyle(GenesyxColor.destructive)
                            .onTapGesture { revoke(invite) }
                    }
                    .padding(.top, 8)
                }
            }
        }
        // Straight into the share sheet once the database has issued the code — the invite is
        // useless until it reaches her.
        .sheet(item: $justCreated) { invite in
            InviteShareSheet(invite: invite, senderName: session.displayName,
                             emailed: partner.lastInviteEmailed)
        }
    }

    private func createInvite() {
        let address = email.trimmingCharacters(in: .whitespaces)
        guard EmailValidator.isValid(address) else { err = "Enter a valid email"; return }
        sending = true
        Task {
            do {
                justCreated = try await partner.sendInvite(email: address)
                email = ""
            } catch {
                err = "Couldn't create the invite. Check your connection and try again."
            }
            sending = false
        }
    }

    private func revoke(_ invite: PartnerInvite) {
        Task {
            do { try await partner.revoke(id: invite.id) }
            catch { err = "Couldn't revoke that invite. Please try again." }
        }
    }

    private var divider: some View {
        Rectangle().fill(GenesyxColor.border.opacity(0.5)).frame(height: 1)
    }
}

// MARK: - Personal details sheet

private struct PersonalDetailsSheet: View {
    /// Her stored name, not the "Guest" placeholder the Profile card falls back to for display —
    /// prefilling that made Save write the literal word "Guest" over her real name.
    let initial: String?
    let email: String?
    let onSave: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name: String

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    init(initial: String?, email: String?, onSave: @escaping (String) -> Void) {
        self.initial = initial
        self.email = email
        self.onSave = onSave
        _name = State(initialValue: initial ?? "")
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("This is how you'll appear across the app.")
                    .font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground)
                TextField("Display name", text: $name)
                    .padding(.horizontal, 14).frame(height: 52)
                    .background(GenesyxColor.card).clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(GenesyxColor.border, lineWidth: 1))
                    .accessibilityIdentifier("displayNameField")
                    .onChange(of: name) { if $0.count > 80 { name = String($0.prefix(80)) } }

                // Shown but not editable: the address is the credential she signs in with, so
                // changing it is a re-verification flow rather than a text field. Left off the
                // screen entirely, "which account am I in?" had no answer anywhere in the app.
                if let email {
                    Eyebrow("Email", color: GenesyxColor.mutedForeground).padding(.top, 12)
                    Text(email).font(.gxBody).foregroundStyle(GenesyxColor.foreground)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14).frame(height: 52)
                        .background(GenesyxColor.muted).clipShape(RoundedRectangle(cornerRadius: 12))
                    Text("You sign in with this address. Get in touch through Help & Support to change it.")
                        .font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground)
                }
                Spacer()
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(GenesyxColor.background)
            .navigationTitle("Personal details").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(trimmedName)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    // Disabled rather than silently ignored: the old guard closed the sheet with no
                    // error and no change, which reads as the app having lost the edit.
                    .disabled(trimmedName.isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
    }
}

// MARK: - Tracking preferences sheet

/// The onboarding answers, re-opened. They shape her plan, guidance and insights, but were asked
/// once and then frozen — someone who answered "just starting to think about it" a year ago had no
/// way to say she is trying now, and kept being guided as if she weren't.
private struct TrackingPreferencesSheet: View {
    let current: [String: String]
    let onSave: ([String: String]) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var answers: [String: String]

    init(current: [String: String], onSave: @escaping ([String: String]) -> Void) {
        self.current = current
        self.onSave = onSave
        _answers = State(initialValue: current)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("These are the answers you gave when you joined. They shape your plan and the guidance you see — change them whenever things change.")
                        .font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground)

                    ForEach(QuizContent.questions, id: \.id) { question in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(question.question)
                                .font(.gxCardHeadingSmall).foregroundStyle(GenesyxColor.foreground)
                            VStack(spacing: 0) {
                                ForEach(Array(question.options.enumerated()), id: \.element.id) { index, option in
                                    if index > 0 {
                                        Rectangle().fill(GenesyxColor.border.opacity(0.5))
                                            .frame(height: 1).padding(.horizontal, 16)
                                    }
                                    optionRow(question: question, option: option)
                                }
                            }
                            .background(GenesyxColor.card).clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                    }
                }
                .padding(20)
            }
            .background(GenesyxColor.background)
            .navigationTitle("Tracking preferences").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave(answers); dismiss() }.fontWeight(.semibold)
                }
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
    }

    /// Tapping the chosen option again clears it, but only where the question is optional. Without
    /// that, the first tap here is a one-way door: a question she was allowed to skip in onboarding
    /// would become permanently answered the moment she opened this editor and touched it.
    private func optionRow(question: QuizQuestion, option: QuizOption) -> some View {
        let selected = answers[question.id] == option.id
        let clears = selected && question.isOptional
        return Button {
            if clears { answers.removeValue(forKey: question.id) } else { answers[question.id] = option.id }
        } label: {
            HStack {
                Text(option.label).font(.system(size: 14.5)).foregroundStyle(GenesyxColor.foreground)
                    .multilineTextAlignment(.leading)
                Spacer()
                if selected {
                    Image(systemName: "checkmark").font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(GenesyxColor.primary)
                }
            }
            .padding(.horizontal, 16).frame(minHeight: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("quizOption.\(question.id).\(option.id)")
        .accessibilityAddTraits(selected ? [.isSelected] : [])
        .accessibilityHint(clears ? "Tap again to leave this question unanswered" : "")
    }
}
