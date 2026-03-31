import SwiftUI

struct GroupsView: View {
    @Environment(AuthManager.self) var auth
    @State private var vm = GroupsViewModel()
    @State private var showCreate = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(vm.groups) { group in
                    NavigationLink(destination: GroupDetailView(group: group)) {
                        HStack(spacing: 14) {
                            Text(group.emoji)
                                .font(.title2)
                                .frame(width: 44, height: 44)
                                .background(Color(hex: group.colour).opacity(0.2))
                                .clipShape(RoundedRectangle(cornerRadius: 10))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(group.name)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.white)
                                Text("Tap to view expenses")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(Color(hex: "#1C1C1E"))
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color(hex: "#0A0A0A"))
            .navigationTitle("Groups")
            .toolbarBackground(Color(hex: "#1C1C1E"), for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showCreate = true }) {
                        Image(systemName: "plus")
                            .foregroundStyle(Color(hex: "#F97316"))
                    }
                }
            }
            .task {
                if let id = auth.currentUser?.id { await vm.load(userId: id) }
            }
            .sheet(isPresented: $showCreate) {
                CreateGroupSheet { name, emoji, colour in
                    if let id = auth.currentUser?.id {
                        await vm.createGroup(name: name, emoji: emoji, colour: colour, userId: id)
                    }
                }
            }
        }
    }
}

struct CreateGroupSheet: View {
    let onCreate: (String, String, String) async -> Void
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var emoji = "👥"
    @State private var colour = "#F97316"

    private let colours = ["#F97316", "#3B82F6", "#10B981", "#8B5CF6", "#EC4899"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Group Details") {
                    HStack {
                        Text("Icon").foregroundStyle(.secondary)
                        Spacer()
                        TextField("", text: $emoji)
                            .multilineTextAlignment(.center)
                            .frame(width: 44)
                    }
                    TextField("Group name", text: $name)
                }
                Section("Colour") {
                    HStack(spacing: 16) {
                        ForEach(colours, id: \.self) { c in
                            Circle()
                                .fill(Color(hex: c))
                                .frame(width: 32, height: 32)
                                .overlay(Circle().stroke(.white, lineWidth: colour == c ? 3 : 0))
                                .onTapGesture { colour = c }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("New Group")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task {
                            await onCreate(name, emoji, colour)
                            dismiss()
                        }
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}
