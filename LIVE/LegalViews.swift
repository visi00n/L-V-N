//
//  LegalViews.swift
//  LIVE
//

import SwiftUI

struct TermsOfUseView: View {
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerSection(title: "Terms of Use", subtitle: "Last Updated: July 2026")

                    Group {
                        sectionCard(title: "1. Acceptance of Terms", text: "By downloading, accessing, or using the L!V!N mobile application (the 'App'), you agree to be bound by these Terms of Use. If you do not agree to these terms, do not use the App.")

                        sectionCard(title: "2. Eligibility & User Accounts", text: "You must be at least 13 years old to use the App. You are responsible for maintaining the confidentiality of your account credentials and for all activities that occur under your account.")

                        sectionCard(title: "3. Location Sharing & Privacy", text: "L!V!N is a real-time location sharing social application. By posting 'Snaps' or creating 'Events', you consent to sharing location data as configured. You may enable 'Safe Zones' in your settings to obfuscate specific locations (like your home or workplace) up to 1.5 miles.")

                        sectionCard(title: "4. Prohibited Conduct", text: "You agree not to post any content that is unlawful, harmful, threatening, abusive, harassing, defamatory, vulgar, obscene, invasive of another's privacy, or hateful. Harassment or tracking of other users is strictly prohibited.")

                        sectionCard(title: "5. Termination", text: "We reserve the right to suspend or terminate your access to the App at our sole discretion, without notice, for conduct that we believe violates these Terms of Use or is harmful to other users.")
                    }
                }
                .padding(.vertical, 20)
                .padding(.horizontal, 16)
            }
            .background(Color.liveCanvas)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close", action: onDismiss)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.liveInk)
                }
            }
        }
    }
}

struct PrivacyPolicyView: View {
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerSection(title: "Privacy Policy", subtitle: "Last Updated: July 2026")

                    Group {
                        sectionCard(title: "1. Information We Collect", text: "We collect information you provide directly, including username, display name, profile bio, social media handles, and profile picture avatar. We also collect precise location coordinates when you publish a Snap or host an Event.")

                        sectionCard(title: "2. How We Use Location Data", text: "Your location data is used to render Snaps and Events on the public map. Pinned 'Safe Zones' are obfuscated client-side with a randomized 1.5-mile shift before publication to safeguard your exact coordinates.")

                        sectionCard(title: "3. Data Sharing & Third Parties", text: "We do not sell, rent, or trade your personal information or precise location data to third parties. Data is stored securely on Supabase servers.")

                        sectionCard(title: "4. Data Retention & Deletion", text: "You can delete your Snaps or your Events at any time. If you wish to delete your account and all associated profile records, you may submit a request in the Legal/Support menu.")
                    }
                }
                .padding(.vertical, 20)
                .padding(.horizontal, 16)
            }
            .background(Color.liveCanvas)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close", action: onDismiss)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.liveInk)
                }
            }
        }
    }
}

struct AboutView: View {
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 12) {
                        Text("L!V!N")
                            .font(.system(size: 48, weight: .black, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.liveSky, Color.liveLavender, Color.liveCoral],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )

                        Text("Version 1.0.0 (Beta)")
                            .font(.system(size: 14, weight: .black, design: .monospaced))
                            .foregroundStyle(Color.liveMuted)
                    }
                    .padding(.top, 40)

                    VStack(alignment: .leading, spacing: 14) {
                        Text("Our Mission")
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .foregroundStyle(Color.liveInk)

                        Text("L!V!N is designed to reconnect people in real life. By sharing moments, hosting live events, and communicating with nearby explorers, we build vibrant, active, and safe local communities.")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.liveMuted)
                            .lineSpacing(4)
                    }
                    .padding(16)
                    .background(Color.liveSurface, in: RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 16)

                    VStack(alignment: .leading, spacing: 14) {
                        Text("The Team")
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .foregroundStyle(Color.liveInk)

                        Text("Built with passion by a distributed team of developers who believe that technology should bring us closer together in the real world, not keep us isolated behind screens.")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.liveMuted)
                            .lineSpacing(4)
                    }
                    .padding(16)
                    .background(Color.liveSurface, in: RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 16)
                }
            }
            .background(Color.liveCanvas)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close", action: onDismiss)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.liveInk)
                }
            }
        }
    }
}

struct SupportView: View {
    let onDismiss: () -> Void

    @State private var email = ""
    @State private var category = "Bug Report"
    @State private var message = ""
    @State private var isSending = false
    @State private var showingAlert = false

    private let categories = ["Bug Report", "Feature Request", "Account Help", "General Feedback"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    headerSection(title: "Legal & Support", subtitle: "We're here to help keep L!V!N safe.")

                    VStack(alignment: .leading, spacing: 12) {
                        Text("CONTACT SUPPORT")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundStyle(Color.liveMuted)

                        TextField("Your email address", text: $email)
                            .textFieldStyle(.plain)
                            .padding(12)
                            .background(Color.liveSurfaceElevated, in: RoundedRectangle(cornerRadius: 10))
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .keyboardType(.emailAddress)

                        Picker("Category", selection: $category) {
                            ForEach(categories, id: \.self) { cat in
                                Text(cat).tag(cat)
                            }
                        }
                        .pickerStyle(.menu)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.liveSurfaceElevated, in: RoundedRectangle(cornerRadius: 10))

                        TextEditor(text: $message)
                            .frame(minHeight: 120)
                            .padding(8)
                            .scrollContentBackground(.hidden)
                            .background(Color.liveSurfaceElevated, in: RoundedRectangle(cornerRadius: 10))
                            .font(.system(size: 14, weight: .medium, design: .rounded))

                        Button(action: sendSupportTicket) {
                            HStack {
                                if isSending {
                                    ProgressView().tint(Color.liveOnInk)
                                } else {
                                    Text("Send Support Ticket")
                                }
                            }
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .foregroundStyle(Color.liveOnInk)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(email.isEmpty || message.isEmpty ? Color.liveInk.opacity(0.3) : Color.liveInk, in: RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(email.isEmpty || message.isEmpty || isSending)
                        .buttonStyle(.plain)
                    }
                    .padding(16)
                    .background(Color.liveSurface, in: RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 16)
                }
                .padding(.vertical, 20)
            }
            .background(Color.liveCanvas)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close", action: onDismiss)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.liveInk)
                }
            }
            .alert("Ticket Sent", isPresented: $showingAlert) {
                Button("OK", action: { onDismiss() })
            } message: {
                Text("Thank you! Our support team has received your request and will get back to you shortly.")
            }
        }
    }

    private func sendSupportTicket() {
        isSending = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            isSending = false
            showingAlert = true
        }
    }
}

// MARK: - View Helpers
private func headerSection(title: String, subtitle: String) -> some View {
    VStack(alignment: .leading, spacing: 6) {
        Text(title)
            .font(.system(size: 28, weight: .black, design: .rounded))
            .foregroundStyle(Color.liveInk)

        Text(subtitle)
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(Color.liveMuted)
    }
    .padding(.horizontal, 16)
}

private func sectionCard(title: String, text: String) -> some View {
    VStack(alignment: .leading, spacing: 10) {
        Text(title)
            .font(.system(size: 15, weight: .black, design: .rounded))
            .foregroundStyle(Color.liveInk)

        Text(text)
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(Color.liveMuted)
            .lineSpacing(4)
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.liveSurface, in: RoundedRectangle(cornerRadius: 14))
    .padding(.horizontal, 16)
}
