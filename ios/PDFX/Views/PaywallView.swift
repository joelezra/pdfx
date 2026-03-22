import SwiftUI

struct PaywallView: View {
    @Environment(PaywallManager.self) private var paywallManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPlan: Plan = .yearly
    @State private var appeared: Bool = false

    enum Plan {
        case monthly, yearly

        var title: String {
            switch self {
            case .monthly: "Monthly"
            case .yearly: "Yearly"
            }
        }

        var price: String {
            switch self {
            case .monthly: "$9.99"
            case .yearly: "$59.99"
            }
        }

        var period: String {
            switch self {
            case .monthly: "/month"
            case .yearly: "/year"
            }
        }

        var savings: String? {
            switch self {
            case .monthly: nil
            case .yearly: "Save 50%"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.offWhite.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 32) {
                        headerSection
                        featuresSection
                        plansSection
                        ctaButton
                        termsSection
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(Theme.warmGray)
                    }
                }
            }
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    appeared = true
                }
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Theme.electricBlue, Theme.electricBlue.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)

                Image(systemName: "crown.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.white)
            }
            .scaleEffect(appeared ? 1 : 0.5)
            .opacity(appeared ? 1 : 0)

            Text("Unlock PDFX Pro")
                .font(.title.weight(.bold))
                .foregroundStyle(Theme.navy)

            Text("Edit unlimited documents with\nfont-matched precision")
                .font(.body)
                .foregroundStyle(Theme.warmGray)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
        }
    }

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            FeatureRow(icon: "pencil.and.outline", text: "Unlimited text editing")
            FeatureRow(icon: "doc.on.doc", text: "Unlimited document scans")
            FeatureRow(icon: "square.and.arrow.up", text: "Export as PDF or image")
            FeatureRow(icon: "textformat", text: "Font-matched text replacement")
            FeatureRow(icon: "sparkles", text: "Priority support & future features")
        }
        .padding(20)
        .background(.white, in: .rect(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 12, y: 4)
    }

    private var plansSection: some View {
        HStack(spacing: 12) {
            PlanCard(plan: .yearly, isSelected: selectedPlan == .yearly) {
                selectedPlan = .yearly
            }
            PlanCard(plan: .monthly, isSelected: selectedPlan == .monthly) {
                selectedPlan = .monthly
            }
        }
    }

    private var ctaButton: some View {
        VStack(spacing: 12) {
            Button {
                paywallManager.simulatePurchase()
                dismiss()
            } label: {
                VStack(spacing: 4) {
                    Text("Start Free Trial")
                        .font(.headline)
                    Text("7 days free, then \(selectedPlan.price)\(selectedPlan.period)")
                        .font(.caption)
                        .opacity(0.8)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [Theme.electricBlue, Color(red: 0.1, green: 0.3, blue: 0.85)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    in: .rect(cornerRadius: 14)
                )
                .shadow(color: Theme.electricBlue.opacity(0.3), radius: 12, y: 6)
            }

            Button("Restore Purchases") {
                paywallManager.simulatePurchase()
                dismiss()
            }
            .font(.subheadline)
            .foregroundStyle(Theme.warmGray)
        }
    }

    private var termsSection: some View {
        Text("Cancel anytime. Payment charged after trial ends.\nTerms of Service · Privacy Policy")
            .font(.caption2)
            .foregroundStyle(Theme.warmGray.opacity(0.7))
            .multilineTextAlignment(.center)
            .lineSpacing(3)
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.body.weight(.medium))
                .foregroundStyle(Theme.electricBlue)
                .frame(width: 28)

            Text(text)
                .font(.subheadline)
                .foregroundStyle(Theme.navy)
        }
    }
}

struct PlanCard: View {
    let plan: PaywallView.Plan
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            VStack(spacing: 8) {
                if let savings = plan.savings {
                    Text(savings)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Theme.electricBlue, in: .capsule)
                } else {
                    Text(" ")
                        .font(.caption.weight(.bold))
                        .padding(.vertical, 4)
                }

                Text(plan.price)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Theme.navy)

                Text(plan.period)
                    .font(.caption)
                    .foregroundStyle(Theme.warmGray)

                Text(plan.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.navy)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                isSelected ? Theme.electricBlue.opacity(0.05) : .white,
                in: .rect(cornerRadius: 14)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(
                        isSelected ? Theme.electricBlue : Theme.lightGray,
                        lineWidth: isSelected ? 2 : 1
                    )
            }
        }
        .buttonStyle(.plain)
        .animation(.snappy, value: isSelected)
    }
}
