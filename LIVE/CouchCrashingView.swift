//
//  CouchCrashingView.swift
//  LIVE
//

import SwiftUI

struct CouchListing: Identifiable, Codable {
    let id: UUID
    var explorerName: String
    var explorerHandle: String
    var isOffering: Bool // true: offering couch, false: needing couch
    var locationName: String
    var pricePerNight: Double
    var description: String
    var contactInfo: String
}

struct CouchCrashingView: View {
    let onDismiss: () -> Void

    @State private var selectedTab = 0 // 0: Offering, 1: Needing
    @State private var listings: [CouchListing] = []
    @State private var isPremiumUnlocked = false
    
    // Create new listing state
    @State private var isShowingCreateSheet = false
    @State private var newLocation = ""
    @State private var newPrice: Double = 10.0
    @State private var newDescription = ""
    @State private var newContact = ""
    @State private var isOfferingOption = true

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Subscription Premium Map Promo Banner
                premiumPromoBanner

                if !isPremiumUnlocked {
                    lockedPremiumPanel
                    Spacer()
                } else {
                    Picker("Mode", selection: $selectedTab) {
                        Text("Offers").tag(0)
                        Text("Needs").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    ScrollView {
                        VStack(spacing: 12) {
                            let filtered = listings.filter { $0.isOffering == (selectedTab == 0) }

                            if filtered.isEmpty {
                                EmptyStateBlock(
                                    symbolName: "bed.double.fill",
                                    title: "No listings yet",
                                    message: selectedTab == 0
                                    ? "Be the first to offer a couch nearby!"
                                    : "No current travelers looking for a couch."
                                )
                                .padding(.top, 40)
                            } else {
                                ForEach(filtered) { listing in
                                    listingCard(for: listing)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 20)
                    }
                }
            }
            .background(Color.liveCanvas)
            .navigationTitle("Couch Crashing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close", action: onDismiss)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.liveInk)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { isShowingCreateSheet = true }) {
                        Image(systemName: isPremiumUnlocked ? "plus.circle.fill" : "lock.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(isPremiumUnlocked ? Color.liveInk : Color.liveMuted)
                    }
                    .disabled(!isPremiumUnlocked)
                }
            }
            .sheet(isPresented: $isShowingCreateSheet) {
                createListingSheet
            }
            .onAppear {
                seedMockListings()
            }
        }
    }

    private var premiumPromoBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("⭐ TRAVELER PREMIUM PACK")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.liveCoral, in: Capsule())
                
                Spacer()
            }

            Text("Unlock Local Spots Tourists Miss")
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(Color.white)

            Text("Subscribe to the premium pack to get scenic views, abandoned aesthetics, and dining secrets fully curated and backed by actual locals directly on your map!")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.86))
                .lineSpacing(3)
        }
        .padding(14)
        .background(
            LinearGradient(
                colors: [Color.liveSky, Color.liveLavender, Color.liveCoral.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.24), lineWidth: 1)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .shadow(color: Color.liveLavender.opacity(0.18), radius: 12, y: 6)
    }

    private var lockedPremiumPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Premium travel pack locked", systemImage: "lock.fill")
                .font(.system(size: 17, weight: .black, design: .rounded))
                .foregroundStyle(Color.liveInk)

            Text("Couch crashing, premium scenic maps, host payouts, and verified 18+ trust badges need real Stripe Billing, Stripe Connect payouts, and ID verification before going live.")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Color.liveMuted)
                .lineSpacing(4)

            VStack(alignment: .leading, spacing: 8) {
                Label("$36/year subscription through Stripe Billing", systemImage: "creditcard.fill")
                Label("18+ identity verification before buying/hosting", systemImage: "checkmark.shield.fill")
                Label("Host payouts through Stripe Connect, not PayPal in-app", systemImage: "banknote.fill")
                Label("Safety check-ins before couch meetups go live", systemImage: "sos.circle.fill")
            }
            .font(.system(size: 12, weight: .black, design: .rounded))
            .foregroundStyle(Color.liveInk)

            Button {
                // Keep locked until server-side Stripe products, Identity, Connect accounts,
                // webhook persistence, and App Store review decisions are configured.
            } label: {
                Label("Coming after secure Stripe + ID setup", systemImage: "sparkles")
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(Color.liveOnInk)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.liveInk.opacity(0.38), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(true)
        }
        .padding(16)
        .background(Color.liveSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.liveStroke, lineWidth: 1)
        }
        .padding(16)
    }

    private func listingCard(for listing: CouchListing) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(listing.explorerName)
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(Color.liveInk)
                    Text("@\(listing.explorerHandle)")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(Color.liveMuted)
                }
                
                Spacer()
                
                Text(String(format: "$%.0f/night", listing.pricePerNight))
                    .font(.system(size: 16, weight: .black, design: .monospaced))
                    .foregroundStyle(Color.liveMint)
            }
            
            Text(listing.description)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Color.liveInk.opacity(0.82))
                .lineLimit(4)
                .lineSpacing(3)

            HStack {
                Label(listing.locationName, systemImage: "mappin.and.ellipse")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.liveMuted)
                
                Spacer()
                
                Text("Contact: \(listing.contactInfo)")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.liveInk, in: Capsule())
            }
        }
        .padding(14)
        .background(Color.liveSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.liveStroke, lineWidth: 1.2)
        }
        .shadow(color: Color.black.opacity(0.04), radius: 8, y: 4)
    }

    private var createListingSheet: some View {
        NavigationStack {
            Form {
                Section("Listing Type") {
                    Picker("Options", selection: $isOfferingOption) {
                        Text("Offering Couch").tag(true)
                        Text("Needing Couch").tag(false)
                    }
                    .pickerStyle(.segmented)
                }

                Section("Details") {
                    TextField("Location (e.g. Venice Beach, CA)", text: $newLocation)
                    HStack {
                        Text("Price Per Night")
                        Spacer()
                        Slider(value: $newPrice, in: 0...100, step: 5)
                        Text(String(format: "$%.0f", newPrice))
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                    }
                    TextField("Description (e.g. Comfy futon, clean sheets, close to metro)", text: $newDescription)
                    TextField("Contact info (e.g. Instagram/Email)", text: $newContact)
                }
            }
            .navigationTitle("Create Listing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { isShowingCreateSheet = false }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveNewListing()
                    }
                    .disabled(newLocation.isEmpty || newDescription.isEmpty || newContact.isEmpty)
                }
            }
        }
    }

    private func seedMockListings() {
        guard listings.isEmpty else { return }
        listings = [
            CouchListing(
                id: UUID(),
                explorerName: "laptcv",
                explorerHandle: "laptcv",
                isOffering: true,
                locationName: "Venice, Los Angeles",
                pricePerNight: 10,
                description: "Have a clean foldout couch in my studio apartment, 3 blocks away from the beach. Access to wifi and kitchen. Traveler friendly!",
                contactInfo: "IG: @laptcv"
            ),
            CouchListing(
                id: UUID(),
                explorerName: "Sarah Green",
                explorerHandle: "sarahg",
                isOffering: false,
                locationName: "Downtown Austin, TX",
                pricePerNight: 15,
                description: "Digital nomad visiting Austin for a tech week. Clean, quiet, and willing to pay up to $15/night. Just need a place to crash.",
                contactInfo: "sarahg@mail.com"
            ),
            CouchListing(
                id: UUID(),
                explorerName: "Alex Mercer",
                explorerHandle: "alex_merc",
                isOffering: true,
                locationName: "Brooklyn, New York",
                pricePerNight: 20,
                description: "Air mattress available in spacious Williamsburg loft. Cat friendly, rooftop access, coffee maker is all yours.",
                contactInfo: "@alex_merc"
            )
        ]
    }

    private func saveNewListing() {
        let list = CouchListing(
            id: UUID(),
            explorerName: "You",
            explorerHandle: "me",
            isOffering: isOfferingOption,
            locationName: newLocation,
            pricePerNight: newPrice,
            description: newDescription,
            contactInfo: newContact
        )
        listings.append(list)
        
        // Reset state
        newLocation = ""
        newPrice = 10.0
        newDescription = ""
        newContact = ""
        isShowingCreateSheet = false
    }
}
