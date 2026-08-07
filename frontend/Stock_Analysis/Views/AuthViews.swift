import SwiftUI

struct AuthContainerView: View {
    @State private var selection = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                brandHeader
                    .padding(.top, Spacing.xxl)
                    .padding(.bottom, Spacing.xl)

                modeSwitch
                    .padding(.horizontal, Spacing.xl)
                    .padding(.bottom, Spacing.sm)

                TabView(selection: $selection) {
                    LoginView().tag(0)
                    SignupView().tag(1)
                }
                .authPagerStyle()
            }
            .screenBackground()
            .authNavigationChromeHidden()
        }
    }

    private var brandHeader: some View {
        VStack(spacing: Spacing.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.brandPrimary)
                    .frame(width: 58, height: 58)
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 25, weight: .bold))
                    .foregroundStyle(.white)
            }
            Text("Vantage")
                .font(.system(size: 27, weight: .bold, design: .rounded))
                .foregroundStyle(Color.textPrimary)
            Text("Markets, holdings, and signal — in one place.")
                .font(.system(size: 14))
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    private var modeSwitch: some View {
        HStack(spacing: 2) {
            modeButton(title: "Log In", index: 0)
            modeButton(title: "Sign Up", index: 1)
        }
        .padding(3)
        .background(Color.appSurfaceSecondary, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
    }

    private func modeButton(title: String, index: Int) -> some View {
        Button {
            Haptic.selection()
            withAnimation(.easeOut(duration: 0.2)) { selection = index }
        } label: {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(selection == index ? Color.white : Color.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    selection == index ? Color.brandPrimary : Color.clear,
                    in: RoundedRectangle(cornerRadius: Radius.md - 3, style: .continuous)
                )
        }
        .buttonStyle(.plain)
    }
}

struct LoginView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = LoginViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                AppTextField(title: "Email", text: $viewModel.email, icon: "envelope", autocapitalizationDisabled: true, submitLabel: .next)

                AppTextField(title: "Password", text: $viewModel.password, icon: "lock", isSecure: true, submitLabel: .go, onSubmit: submit)

                if let errorMessage = viewModel.errorMessage {
                    inlineError(errorMessage)
                }

                Button {
                    submit()
                } label: {
                    HStack(spacing: 8) {
                        if viewModel.isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text("Log In")
                            Image(systemName: "arrow.right")
                                .font(.system(size: 14, weight: .bold))
                        }
                    }
                }
                .buttonStyle(.appPrimary(isDisabled: viewModel.isLoading))
                .disabled(viewModel.isLoading)
                .padding(.top, Spacing.xs)

                disclosureNote(text: "Your session stays securely stored on this device.")
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.top, Spacing.sm)
            .padding(.bottom, Spacing.xxl)
        }
    }

    private func submit() {
        Task { await viewModel.login(appState: appState) }
    }
}

struct SignupView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = SignupViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack(spacing: Spacing.sm) {
                    AppTextField(title: "First name", text: $viewModel.firstName, submitLabel: .next)
                    AppTextField(title: "Last name", text: $viewModel.lastName, submitLabel: .next)
                }

                AppTextField(title: "Email", text: $viewModel.email, icon: "envelope", autocapitalizationDisabled: true, submitLabel: .next)

                AppTextField(title: "Phone", text: $viewModel.phoneNumber, icon: "phone", submitLabel: .next)

                AppTextField(title: "Password", text: $viewModel.password, icon: "lock", isSecure: true, submitLabel: .go, onSubmit: submit)

                if let resultMessage = viewModel.resultMessage {
                    Label(resultMessage, systemImage: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.positive)
                }

                if let errorMessage = viewModel.errorMessage {
                    inlineError(errorMessage)
                }

                Button {
                    submit()
                } label: {
                    HStack(spacing: 8) {
                        if viewModel.isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text("Create Account")
                        }
                    }
                }
                .buttonStyle(.appPrimary(isDisabled: viewModel.isLoading))
                .disabled(viewModel.isLoading)
                .padding(.top, Spacing.xs)

                disclosureNote(text: "By continuing you agree to our Terms of Service and Privacy Policy.")
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.top, Spacing.sm)
            .padding(.bottom, Spacing.xxl)
        }
    }

    private func submit() {
        Task { await viewModel.signup(appState: appState) }
    }
}

@ViewBuilder
private func inlineError(_ message: String) -> some View {
    Label(message, systemImage: "exclamationmark.triangle.fill")
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(Color.negative)
}

@ViewBuilder
private func disclosureNote(text: String) -> some View {
    HStack(alignment: .top, spacing: 5) {
        Image(systemName: "lock.shield")
        Text(text)
    }
    .font(.system(size: 11))
    .foregroundStyle(Color.textTertiary)
    .padding(.top, Spacing.xxs)
}

private extension View {
    @ViewBuilder
    func authPagerStyle() -> some View {
#if os(iOS)
        tabViewStyle(.page(indexDisplayMode: .never))
#else
        tabViewStyle(.automatic)
#endif
    }

    @ViewBuilder
    func authNavigationChromeHidden() -> some View {
#if os(iOS)
        toolbar(.hidden, for: .navigationBar)
#else
        self
#endif
    }
}
