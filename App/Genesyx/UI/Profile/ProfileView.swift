import SwiftUI
import GenesyxCore

/// Profile — account, focus toggle, partner linking, preferences (theme/push), and about.
/// Ported from the Android `ProfileScreen` + `ProfileViewModel`.
struct ProfileView: View {

    @EnvironmentObject private var session: SessionRepository
    @EnvironmentObject private var prefs: PreferencesRepository
    @EnvironmentObject private var partner: PartnerRepository

    @State private var nameOpen = false
    @State private var detail: String?
    @State private var deleteOpen = false
    @State private var showAuth = false
    @State private var showPregnancy = false

    private var name: String { session.displayName ?? "Guest" }

    private static let detailCopy: [String: String] = [
        "Personal Details": "Manage your display name, email sign-in, and account details from this screen.",
        "Health Profile": "Your cycle settings, daily logs, pH readings, and partner connection shape your personalised guidance.",
        "Tracking Preferences": "Keep notifications on and update your cycle settings any time your rhythm changes.",
        "Privacy & Data": "Your saved data is private to your account. You can log out or delete your account from Profile.",
        "Help & Support": "For best results, complete cycle setup, log today, and use the Track or Nutrition tabs to add pH readings.",
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
                    preferencesGroup
                    aboutGroup
                    signOutButton
                    if session.isSignedIn { deleteButton }
                }
                .padding(.horizontal, 20).padding(.vertical, 16)
            }
            .frame(maxWidth: .infinity)
            .background(GenesyxColor.background)
            .navigationTitle("Profile")
        }
        .sheet(isPresented: $showAuth) { AuthView() }
        .sheet(isPresented: $showPregnancy) { PregnancyView() }
        .sheet(isPresented: $nameOpen) { EditNameSheet(initial: name) { session.updateDisplayName($0) } }
        .alert(detail ?? "", isPresented: Binding(get: { detail != nil }, set: { if !$0 { detail = nil } })) {
            Button("Done") { detail = nil }
        } message: {
            Text(detail.flatMap { Self.detailCopy[$0] } ?? "This section is ready for your saved app settings.")
        }
        .alert("Delete your account?", isPresented: $deleteOpen) {
            Button("Delete", role: .destructive) { session.signOut() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete your account and all your data. This cannot be undone.")
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
            if session.isSignedIn {
                Text("PREMIUM").font(.system(size: 10.5, weight: .semibold)).foregroundStyle(GenesyxColor.primary)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(GenesyxColor.primary.opacity(0.10)).clipShape(Capsule())
            }
        }
        .padding(20).background(GenesyxColor.card).clipShape(RoundedRectangle(cornerRadius: 24))
    }

    // MARK: Focus

    private var focusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            groupLabel("Current focus")
            HStack(spacing: 6) {
                focusSeg("Fertility Prep", selected: prefs.focusMode == .prep) { prefs.focusMode = .prep }
                focusSeg("Pregnancy", selected: prefs.focusMode == .pregnancy) {
                    prefs.focusMode = .pregnancy
                    showPregnancy = true
                }
            }
            .padding(4).background(GenesyxColor.muted).clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private func focusSeg(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Text(label).font(.system(size: 13, weight: .medium))
            .foregroundStyle(selected ? GenesyxColor.foreground : GenesyxColor.mutedForeground)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(selected ? GenesyxColor.card : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .onTapGesture(perform: action)
    }

    // MARK: Groups

    private var accountGroup: some View {
        VStack(alignment: .leading, spacing: 8) {
            groupLabel("Account")
            cardGroup {
                rowItem("Edit name") { session.isSignedIn ? (nameOpen = true) : (showAuth = true) }
                divider
                rowItem("Change password") { session.isSignedIn ? (detail = "Personal Details") : (showAuth = true) }
            }
        }
    }

    private var trackingGroup: some View {
        VStack(alignment: .leading, spacing: 8) {
            groupLabel("Tracking")
            cardGroup {
                rowItem("Personal Details") { detail = "Personal Details" }
                divider
                rowItem("Health Profile") { detail = "Health Profile" }
                divider
                rowItem("Tracking Preferences") { detail = "Tracking Preferences" }
            }
        }
    }

    private var preferencesGroup: some View {
        VStack(alignment: .leading, spacing: 8) {
            groupLabel("Preferences")
            cardGroup {
                switchRow("Push Notifications", isOn: Binding(get: { prefs.pushEnabled }, set: { prefs.pushEnabled = $0 }))
                divider
                switchRow("Dark Mode", isOn: Binding(get: { prefs.themeMode == .dark }, set: { prefs.themeMode = $0 ? .dark : .system }))
            }
        }
    }

    private var aboutGroup: some View {
        VStack(alignment: .leading, spacing: 8) {
            groupLabel("About")
            cardGroup {
                rowItem("Privacy & Data") { detail = "Privacy & Data" }
                divider
                rowItem("Help & Support") { detail = "Help & Support" }
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

    private func switchRow(_ label: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Text(label).font(.system(size: 14.5)).foregroundStyle(GenesyxColor.foreground)
        }
        .tint(GenesyxColor.primary)
        .padding(.horizontal, 16).frame(minHeight: 52)
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
            Button("Remove") { partner.unlink() }.foregroundStyle(GenesyxColor.destructive)
        }
    }

    private var inviteForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "heart.fill").font(.system(size: 14)).foregroundStyle(GenesyxColor.primary)
                Text("Add your partner").font(.gxCardHeadingSmall).foregroundStyle(GenesyxColor.foreground)
            }
            Text("Send an invite — when they accept, you'll be linked and can share your journey.")
                .font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground)
            TextField("partner@example.com", text: $email)
                .textInputAutocapitalization(.never).keyboardType(.emailAddress).autocorrectionDisabled()
                .padding(.horizontal, 14).frame(height: 52)
                .background(GenesyxColor.card).clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(err == nil ? GenesyxColor.border : GenesyxColor.destructive, lineWidth: 1))
                .onChange(of: email) { _ in err = nil }
            if let err { Text(err).font(.gxBodySmall).foregroundStyle(GenesyxColor.destructive) }
            Button {
                if EmailValidator.isValid(email) { partner.sendInvite(email: email.trimmingCharacters(in: .whitespaces)); email = "" }
                else { err = "Enter a valid email" }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "envelope")
                    Text("Send invite").fontWeight(.semibold)
                }
                .foregroundStyle(GenesyxColor.primary).frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)

            if !pending.isEmpty {
                divider
                Eyebrow("Pending invites", color: GenesyxColor.mutedForeground)
                ForEach(pending) { inv in
                    HStack {
                        Text(inv.email).font(.gxBodySmall).foregroundStyle(GenesyxColor.foreground)
                        Spacer()
                        Image(systemName: "xmark").font(.system(size: 13)).foregroundStyle(GenesyxColor.destructive)
                            .onTapGesture { partner.revoke(id: inv.id) }
                    }
                    .padding(.top, 8)
                }
            }
        }
    }

    private var divider: some View {
        Rectangle().fill(GenesyxColor.border.opacity(0.5)).frame(height: 1)
    }
}

// MARK: - Edit name sheet

private struct EditNameSheet: View {
    let initial: String
    let onSave: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name: String

    init(initial: String, onSave: @escaping (String) -> Void) {
        self.initial = initial
        self.onSave = onSave
        _name = State(initialValue: initial)
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
                    .onChange(of: name) { if $0.count > 80 { name = String($0.prefix(80)) } }
                Spacer()
            }
            .padding(20)
            .background(GenesyxColor.background)
            .navigationTitle("Edit name").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if !name.trimmingCharacters(in: .whitespaces).isEmpty { onSave(name.trimmingCharacters(in: .whitespaces)) }
                        dismiss()
                    }.fontWeight(.semibold)
                }
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
    }
}
