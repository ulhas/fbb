import SwiftUI

struct ProfileView: View {
    @Environment(EntitlementsStore.self) private var entitlements
    @State private var vm: ProfileViewModel

    @State private var sheet: SheetKind?
    @State private var infoMessage: String?
    @State private var showInfo = false
    @State private var showLogoutConfirm = false

    enum SheetKind: Identifiable {
        case editTracks
        case editDOB
        case editHeight
        case editSex
        case editGoal
        case changePassword
        case aiPersonality

        var id: Int {
            switch self {
            case .editTracks: return 0
            case .editDOB: return 1
            case .editHeight: return 2
            case .editSex: return 3
            case .editGoal: return 4
            case .changePassword: return 5
            case .aiPersonality: return 6
            }
        }
    }

    init(api: APIClient, entitlements: EntitlementsStore) {
        _vm = State(wrappedValue: ProfileViewModel(api: api, entitlements: entitlements))
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Spacing.lg) {
                switch vm.profile {
                case .idle, .loading:
                    ProfileSkeleton()
                case .failed(let error):
                    ErrorCard(
                        title: "Couldn't load profile",
                        message: error.isRetryable ? "Pull to retry, or tap below." : nil,
                        isRetryable: error.isRetryable,
                        retry: { Task { await vm.refresh() } }
                    )
                case .loaded(let data):
                    loadedContent(data: data)
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.sm)
            .padding(.bottom, Spacing.xxl)
        }
        .scrollIndicators(.hidden)
        .background(Color.fbbBackground.ignoresSafeArea())
        .refreshable { await vm.refresh() }
        .task { await vm.onAppear() }
        .sheet(item: $sheet) { kind in
            sheetContent(for: kind)
        }
        .alert("Coming soon", isPresented: $showInfo, presenting: infoMessage) { _ in
            Button("OK", role: .cancel) {}
        } message: { msg in
            Text(msg)
        }
        .confirmationDialog(
            "Sign out?",
            isPresented: $showLogoutConfirm,
            titleVisibility: .visible
        ) {
            Button("Sign out", role: .destructive) {
                vm.logout()
                infoMessage = "Signed out (mock). Phase 2 will return you to the auth screen."
                showInfo = true
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You'll need to sign back in to keep training.")
        }
    }

    // MARK: - Content composition

    @ViewBuilder
    private func loadedContent(data: ProfileData) -> some View {
        ProfileHeroCard(user: data.user, tier: data.subscription.tier)

        SubscriptionCard(
            subscription: data.subscription,
            onManage: { open(data.subscription.storeManageURL) }
        )

        TracksCard(
            selectedTrackCodes: entitlements.selectedTrackCodes,
            onEdit: { sheet = .editTracks }
        )

        SettingsCard(title: "About me", subtitle: "Used for macro defaults and recovery models") {
            PreferenceRow(
                symbol: "calendar",
                title: "Date of birth",
                subtitle: ageSubtitle(for: data.body),
                onTap: { sheet = .editDOB }
            ) {
                PreferenceValue(text: dobLabel(data.body.dateOfBirth))
            }
            RowDivider()
            PreferenceRow(
                symbol: "ruler.fill",
                title: "Height",
                onTap: { sheet = .editHeight }
            ) {
                PreferenceValue(text: data.body.heightLabel)
            }
            RowDivider()
            PreferenceRow(
                symbol: "scalemass.fill",
                symbolTint: .fbbTeal,
                title: "Weight",
                subtitle: "Synced from Apple Health"
            ) {
                if let lb = data.body.weightLb {
                    PreferenceValue(text: String(format: "%.1f lb", lb))
                } else {
                    PreferenceValue(text: "—")
                }
            }
            RowDivider()
            PreferenceRow(
                symbol: "person.fill",
                title: "Sex",
                onTap: { sheet = .editSex }
            ) {
                PreferenceValue(text: data.body.sex.displayLabel)
            }
            RowDivider()
            PreferenceRow(
                symbol: "target",
                title: "Goal",
                onTap: { sheet = .editGoal }
            ) {
                PreferenceValue(text: data.body.goal.displayLabel)
            }
        }

        SettingsCard(title: "Account & security") {
            PreferenceRow(
                symbol: "envelope.fill",
                title: "Email",
                subtitle: data.account.email
            ) {
                PreferenceValue(text: "Edit")
            }
            RowDivider()
            PreferenceRow(
                symbol: "lock.fill",
                title: "Change password",
                subtitle: passwordSubtitle(data.account.lastPasswordChangeDays),
                onTap: { sheet = .changePassword }
            )
            RowDivider()
            PreferenceRow(
                symbol: "faceid",
                symbolTint: .fbbTeal,
                title: "Biometric login",
                subtitle: "Face ID unlock"
            ) {
                Toggle("", isOn: Binding(
                    get: { data.account.hasBiometricLogin },
                    set: { vm.setBiometric($0) }
                ))
                .labelsHidden()
                .tint(.fbbOrange)
            }
            RowDivider()
            PreferenceRow(
                symbol: "iphone.gen3",
                title: "Active sessions",
                onTap: { info("Session management arrives in Phase 2 with Supabase auth.") }
            ) {
                PreferenceValue(text: "\(data.account.activeSessions)")
            }
        }

        if let coach = data.coach {
            CoachCard(
                coach: coach,
                onMessage: { info("Coach messaging is coming soon — your coach reads your weekly summary today.") },
                onChangePersonality: { sheet = .aiPersonality }
            )
        }

        SettingsCard(
            title: "Notifications",
            subtitle: "Choose what reaches your phone"
        ) {
            notificationToggle(symbol: "bell.fill",     symbolTint: .fbbOrange, title: "Workout reminders",       keyPath: \.workoutReminders, prefs: data.notifications)
            RowDivider()
            notificationToggle(symbol: "sparkles",      symbolTint: .fbbTeal,   title: "Weekly coach insights",   keyPath: \.weeklyInsights,   prefs: data.notifications)
            RowDivider()
            notificationToggle(symbol: "trophy.fill",   symbolTint: .fbbOrange, title: "PR celebrations",         keyPath: \.prCelebrations,   prefs: data.notifications)
            RowDivider()
            notificationToggle(symbol: "envelope.fill", symbolTint: .fbbTeal,   title: "Coach messages",          keyPath: \.coachMessages,    prefs: data.notifications)
            RowDivider()
            notificationToggle(symbol: "tortoise.fill", symbolTint: .semanticWarning, title: "Bridge week heads-up", keyPath: \.bridgeWeekHeadsUp, prefs: data.notifications)
        }

        SettingsCard(
            title: "Privacy",
            subtitle: "Who reads your training and nutrition"
        ) {
            privacyToggle(symbol: "eye.fill",            symbolTint: .fbbTeal,     title: "Visible to your coach",   subtitle: "Coach Sarah", keyPath: \.shareWithCoach,  prefs: data.privacy)
            RowDivider()
            privacyToggle(symbol: "heart.text.square.fill", symbolTint: .fbbTeal,  title: "Sync with Apple Health",  subtitle: "Sleep, HRV, weight, steps", keyPath: \.shareWithHealth, prefs: data.privacy)
            RowDivider()
            PreferenceRow(
                symbol: "square.and.arrow.up.fill",
                title: "Export training data",
                onTap: { info("Export to CSV/JSON arrives in Phase 2.") }
            )
            RowDivider()
            PreferenceRow(
                symbol: "trash.fill",
                symbolTint: .semanticError,
                title: "Delete account",
                subtitle: "This cannot be undone",
                onTap: { info("Account deletion goes through support@fbb.training during Phase 1.") }
            )
        }

        SettingsCard(title: "About") {
            PreferenceRow(symbol: "info.circle.fill",  title: "Version", subtitle: data.appInfo.environment) {
                PreferenceValue(text: "\(data.appInfo.version) (\(data.appInfo.buildNumber))")
            }
            RowDivider()
            PreferenceRow(symbol: "doc.text.fill",     title: "Terms of service", onTap: { info("Terms link opens in Phase 2.") })
            RowDivider()
            PreferenceRow(symbol: "hand.raised.fill",  title: "Privacy policy",   onTap: { info("Privacy policy link opens in Phase 2.") })
            RowDivider()
            PreferenceRow(symbol: "questionmark.circle.fill", title: "Support",   onTap: { info("Support: support@fbb.training") })
        }

        LogoutFooter(
            appInfo: data.appInfo,
            onLogout: { showLogoutConfirm = true }
        )
        .padding(.top, Spacing.md)
    }

    // MARK: - Sheets

    @ViewBuilder
    private func sheetContent(for kind: SheetKind) -> some View {
        switch kind {
        case .editTracks:
            EditTracksSheet(
                selectedCodes: entitlements.selectedTrackCodes,
                onToggle: { entitlements.toggle($0) },
                onDone: { sheet = nil }
            )
        case .editDOB:
            if case .loaded(let data) = vm.profile {
                EditDOBSheet(
                    initial: data.body.dateOfBirth,
                    onSave: { newISO in
                        var body = data.body
                        body.dateOfBirth = newISO
                        vm.setBody(body)
                        sheet = nil
                    },
                    onCancel: { sheet = nil }
                )
            }
        case .editHeight:
            if case .loaded(let data) = vm.profile {
                EditHeightSheet(
                    initialInches: data.body.heightInches,
                    onSave: { inches in
                        var body = data.body
                        body.heightInches = inches
                        vm.setBody(body)
                        sheet = nil
                    },
                    onCancel: { sheet = nil }
                )
            }
        case .editSex:
            if case .loaded(let data) = vm.profile {
                EditSexSheet(
                    initial: data.body.sex,
                    onSave: { sex in
                        var body = data.body
                        body.sex = sex
                        vm.setBody(body)
                        sheet = nil
                    },
                    onCancel: { sheet = nil }
                )
            }
        case .editGoal:
            if case .loaded(let data) = vm.profile {
                EditGoalSheet(
                    initial: data.body.goal,
                    onSave: { goal in
                        var body = data.body
                        body.goal = goal
                        vm.setBody(body)
                        sheet = nil
                    },
                    onCancel: { sheet = nil }
                )
            }
        case .changePassword:
            ChangePasswordSheet(
                onSave: {
                    sheet = nil
                    infoMessage = "Password updated (mock)."
                    showInfo = true
                },
                onCancel: { sheet = nil }
            )
        case .aiPersonality:
            if case .loaded(let data) = vm.profile, let coach = data.coach {
                AIPersonalitySheet(
                    initial: coach.aiPersonality,
                    onSelect: { p in
                        vm.setAIPersonality(p)
                        sheet = nil
                    },
                    onCancel: { sheet = nil }
                )
            }
        }
    }

    // MARK: - Helpers

    private func notificationToggle(
        symbol: String,
        symbolTint: Color,
        title: String,
        keyPath: WritableKeyPath<NotificationPrefs, Bool>,
        prefs: NotificationPrefs
    ) -> some View {
        PreferenceRow(symbol: symbol, symbolTint: symbolTint, title: title) {
            Toggle("", isOn: Binding(
                get: { prefs[keyPath: keyPath] },
                set: { vm.setNotification(keyPath, to: $0) }
            ))
            .labelsHidden()
            .tint(.fbbOrange)
        }
    }

    private func privacyToggle(
        symbol: String,
        symbolTint: Color,
        title: String,
        subtitle: String,
        keyPath: WritableKeyPath<PrivacyPrefs, Bool>,
        prefs: PrivacyPrefs
    ) -> some View {
        PreferenceRow(symbol: symbol, symbolTint: symbolTint, title: title, subtitle: subtitle) {
            Toggle("", isOn: Binding(
                get: { prefs[keyPath: keyPath] },
                set: { vm.setPrivacy(keyPath, to: $0) }
            ))
            .labelsHidden()
            .tint(.fbbOrange)
        }
    }

    private func info(_ msg: String) {
        infoMessage = msg
        showInfo = true
    }

    private func open(_ url: URL?) {
        guard let url else {
            info("Subscription management opens here in Phase 2.")
            return
        }
        UIApplication.shared.open(url)
    }

    private func dobLabel(_ iso: String) -> String {
        guard let date = ISODate.parse(iso) else { return "—" }
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f.string(from: date)
    }

    private func ageSubtitle(for body: BodyProfile) -> String? {
        body.ageYears.map { "\($0) years old" }
    }

    private func passwordSubtitle(_ days: Int?) -> String? {
        guard let days else { return "Never changed" }
        return "Last changed \(days) days ago"
    }
}

// MARK: - Edit sheets

private struct EditDOBSheet: View {
    let initial: String
    let onSave: (String) -> Void
    let onCancel: () -> Void

    @State private var date: Date = Date()

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("Your date of birth feeds the macro target calculator and recovery model.")
                    .font(.fbb.caption)
                    .foregroundStyle(Color.inkSecondary)
                    .padding(.horizontal, Spacing.md)

                DatePicker(
                    "Date of birth",
                    selection: $date,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(maxWidth: .infinity)

                Spacer()
            }
            .padding(.top, Spacing.md)
            .background(Color.fbbBackground.ignoresSafeArea())
            .navigationTitle("Date of birth")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading)  { Button("Cancel", action: onCancel) }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { onSave(ISODate.string(date)) }
                        .font(.fbb.bodyBold)
                        .foregroundStyle(Color.fbbOrange)
                }
            }
            .onAppear {
                if let d = ISODate.parse(initial) { date = d }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

private struct EditHeightSheet: View {
    let initialInches: Int
    let onSave: (Int) -> Void
    let onCancel: () -> Void

    @State private var feet = 5
    @State private var inches = 10

    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.md) {
                HStack(spacing: 0) {
                    Picker("Feet", selection: $feet) {
                        ForEach(3...8, id: \.self) { Text("\($0) ft").tag($0) }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)

                    Picker("Inches", selection: $inches) {
                        ForEach(0...11, id: \.self) { Text("\($0) in").tag($0) }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, Spacing.md)

                Spacer()
            }
            .padding(.top, Spacing.md)
            .background(Color.fbbBackground.ignoresSafeArea())
            .navigationTitle("Height")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading)  { Button("Cancel", action: onCancel) }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { onSave(feet * 12 + inches) }
                        .font(.fbb.bodyBold)
                        .foregroundStyle(Color.fbbOrange)
                }
            }
            .onAppear {
                feet = initialInches / 12
                inches = initialInches % 12
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

private struct EditSexSheet: View {
    let initial: BodyProfile.Sex
    let onSave: (BodyProfile.Sex) -> Void
    let onCancel: () -> Void

    @State private var selection: BodyProfile.Sex = .undisclosed

    var body: some View {
        EditPickerSheet(
            title: "Sex",
            blurb: "Used for macro defaults — change anytime.",
            options: BodyProfile.Sex.allCases,
            initial: initial,
            selection: $selection,
            label: { $0.displayLabel },
            onSave: onSave,
            onCancel: onCancel
        )
    }
}

private struct EditGoalSheet: View {
    let initial: BodyProfile.Goal
    let onSave: (BodyProfile.Goal) -> Void
    let onCancel: () -> Void

    @State private var selection: BodyProfile.Goal = .maintain

    var body: some View {
        EditPickerSheet(
            title: "Goal",
            blurb: "Drives calorie target and macro split.",
            options: BodyProfile.Goal.allCases,
            initial: initial,
            selection: $selection,
            label: { $0.displayLabel },
            onSave: onSave,
            onCancel: onCancel
        )
    }
}

private struct AIPersonalitySheet: View {
    let initial: CoachAssignment.AIPersonality
    let onSelect: (CoachAssignment.AIPersonality) -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.sm) {
                    ForEach(CoachAssignment.AIPersonality.allCases, id: \.self) { p in
                        Button { onSelect(p) } label: {
                            HStack(alignment: .top, spacing: Spacing.md) {
                                Image(systemName: initial == p ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundStyle(initial == p ? Color.fbbOrange : Color.inkMuted)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(p.displayLabel)
                                        .font(.fbb.title3)
                                        .foregroundStyle(Color.inkPrimary)
                                    Text(p.detail)
                                        .font(.fbb.caption)
                                        .foregroundStyle(Color.inkSecondary)
                                        .lineSpacing(2)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer()
                            }
                            .padding(Spacing.md)
                            .background(Color.surfaceCard)
                            .clipShape(RoundedRectangle(cornerRadius: Spacing.cardCorner, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: Spacing.cardCorner)
                                    .strokeBorder(initial == p ? Color.fbbOrange.opacity(0.5) : .clear, lineWidth: 1.4)
                            )
                            .elevation(.card)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(Spacing.md)
            }
            .background(Color.fbbBackground.ignoresSafeArea())
            .navigationTitle("AI Coach personality")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Close", action: onCancel) }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

private struct EditPickerSheet<Option: Hashable>: View {
    let title: String
    let blurb: String
    let options: [Option]
    let initial: Option
    @Binding var selection: Option
    let label: (Option) -> String
    let onSave: (Option) -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    Text(blurb)
                        .font(.fbb.caption)
                        .foregroundStyle(Color.inkSecondary)
                        .padding(.horizontal, Spacing.md)

                    VStack(spacing: 0) {
                        ForEach(Array(options.enumerated()), id: \.offset) { (idx, option) in
                            Button { selection = option } label: {
                                HStack {
                                    Text(label(option))
                                        .font(.fbb.body)
                                        .foregroundStyle(Color.inkPrimary)
                                    Spacer()
                                    if selection == option {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundStyle(Color.fbbOrange)
                                    }
                                }
                                .padding(.vertical, Spacing.sm)
                                .padding(.horizontal, Spacing.md)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            if idx < options.count - 1 { RowDivider() }
                        }
                    }
                    .background(Color.surfaceCard)
                    .clipShape(RoundedRectangle(cornerRadius: Spacing.cardCorner, style: .continuous))
                    .elevation(.card)
                    .padding(.horizontal, Spacing.md)
                }
                .padding(.top, Spacing.md)
            }
            .background(Color.fbbBackground.ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading)  { Button("Cancel", action: onCancel) }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { onSave(selection) }
                        .font(.fbb.bodyBold)
                        .foregroundStyle(Color.fbbOrange)
                }
            }
            .onAppear { selection = initial }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

private struct ChangePasswordSheet: View {
    let onSave: () -> Void
    let onCancel: () -> Void

    @State private var current: String = ""
    @State private var next: String = ""
    @State private var confirm: String = ""

    private var canSave: Bool {
        !current.isEmpty && next.count >= 8 && next == confirm
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    Text("Use at least 8 characters. We'll sign you out of other devices.")
                        .font(.fbb.caption)
                        .foregroundStyle(Color.inkSecondary)
                        .padding(.horizontal, Spacing.md)

                    VStack(spacing: Spacing.sm) {
                        SecureField("Current password", text: $current)
                            .textContentType(.password)
                        SecureField("New password", text: $next)
                            .textContentType(.newPassword)
                        SecureField("Confirm new password", text: $confirm)
                            .textContentType(.newPassword)
                    }
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal, Spacing.md)

                    if !next.isEmpty && next.count < 8 {
                        Label("New password must be at least 8 characters.", systemImage: "exclamationmark.triangle.fill")
                            .font(.fbb.caption)
                            .foregroundStyle(Color.semanticWarning)
                            .padding(.horizontal, Spacing.md)
                    } else if !confirm.isEmpty && next != confirm {
                        Label("Passwords don't match.", systemImage: "exclamationmark.triangle.fill")
                            .font(.fbb.caption)
                            .foregroundStyle(Color.semanticWarning)
                            .padding(.horizontal, Spacing.md)
                    }

                    Spacer()
                }
                .padding(.top, Spacing.md)
            }
            .background(Color.fbbBackground.ignoresSafeArea())
            .navigationTitle("Change password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel", action: onCancel) }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save", action: onSave)
                        .font(.fbb.bodyBold)
                        .foregroundStyle(canSave ? Color.fbbOrange : Color.inkMuted)
                        .disabled(!canSave)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Loading skeleton

private struct ProfileSkeleton: View {
    var body: some View {
        VStack(spacing: Spacing.lg) {
            HStack(spacing: Spacing.md) {
                Circle()
                    .fill(Color.inkMuted.opacity(0.18))
                    .frame(width: 80, height: 80)
                VStack(alignment: .leading, spacing: 8) {
                    SkeletonBlock(width: 160, height: 22)
                    SkeletonBlock(width: 200, height: 14)
                    SkeletonBlock(width: 120, height: 12)
                }
                Spacer()
            }
            .padding(Spacing.md)
            .background(Color.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: Spacing.cardCorner))
            .elevation(.card)

            VStack(spacing: Spacing.sm) {
                ForEach(0..<5, id: \.self) { _ in
                    SkeletonBlock(height: 60)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
