import SwiftUI
import CoreLocation

func formattedDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter.string(from: date)
}

struct IncidentRow: View {
    let incident: UserIncident
    let index: Int
    @Binding var incidents: [UserIncident]
    let deleteAction: (IndexSet) -> Void

    var body: some View {
        HStack {
            Circle()
                .fill(getIncidentColor(for: incident.type))
                .frame(width: 20, height: 20)
                .padding(.leading)

            VStack(alignment: .leading) {
                Text(incident.type)
                    .font(.headline)
                Text("Coordinates: \(incident.coordinate.latitude), \(incident.coordinate.longitude)")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                Text("Reported: \(formattedDate(incident.timestamp))")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                Toggle("Receive Notifications", isOn: Binding(
                    get: {
                        if index < incidents.count {
                            return incidents[index].receiveNotifications
                        } else {
                            return false
                        }
                    },
                    set: { newValue in
                        if index < incidents.count {
                            var updatedIncidents = incidents
                            updatedIncidents[index].receiveNotifications = newValue
                            incidents = updatedIncidents
                            saveIncidents(incidents, to: "storedPrivateIncidents")
                        }
                    }
                ))
            }
            .padding(.leading)

            Spacer()

            Button(action: {
                deleteAction(IndexSet([index]))
            }) {
                Image(systemName: "xmark.circle.fill")
                    .resizable()
                    .frame(width: 30, height: 30)
                    .foregroundColor(.red)
                    .padding(.trailing)
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(10)
        .shadow(color: .gray.opacity(0.4), radius: 5, x: 0, y: 2)
        .padding(.horizontal)
        .padding(.vertical, 5)
    }
}

struct DeletePrivateIncident: View {
    @State private var incidents: [UserIncident] = loadIncidents(from: "storedPrivateIncidents")
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""
    @State private var alertColor: Color = .red

    var body: some View {
        ZStack(alignment: .top) {
            VStack {
                Spacer().frame(height: 60)
                if incidents.isEmpty {
                    Spacer()
                    Text("No private incidents to display.")
                        .foregroundColor(.gray)
                        .padding()
                    Spacer()
                } else {
                    ScrollView {
                        ForEach(incidents.indices, id: \.self) { index in
                            if index < incidents.count { 
                                IncidentRow(
                                    incident: incidents[index],
                                    index: index,
                                    incidents: $incidents,
                                    deleteAction: deleteIncident
                                )
                            }
                        }
                    }
                }
            }
            .padding(.top, 60)

            DeletePrivateHeaderView()
                .frame(height: 60)
        }
        .overlay(
            CustomAlertView(message: alertMessage, color: alertColor, showAlert: $showAlert)
        )
    }

    func deleteIncident(at offsets: IndexSet) {
        guard let index = offsets.first, index < incidents.count else { return }
        incidents.remove(atOffsets: offsets)
        saveIncidents(incidents, to: "storedPrivateIncidents")
    }
}
