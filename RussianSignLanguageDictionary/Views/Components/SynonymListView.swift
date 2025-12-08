import SwiftUI

struct SynonymListView: View {
    // MARK: - Properties
    
    let synonyms: [SignSynonym]
    let currentSignId: String
    let visitedSignIds: Set<String>
    let onSynonymTap: (String) -> Void
    
    // MARK: - Computed Properties
    
    private var filteredSynonyms: [SignSynonym] {
        synonyms.filter { synonym in
            guard synonym.id != currentSignId else { return false }
            return !visitedSignIds.contains(synonym.id)
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        if !filteredSynonyms.isEmpty {
            VStack(alignment: .leading, spacing: LayoutConstants.SignDetail.elementSpacing) {
                Text("Синонимы:")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                ForEach(filteredSynonyms) { synonym in
                    Button(action: { onSynonymTap(synonym.id) }) {
                        HStack {
                            Text(synonym.word)
                                .font(.body)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct SynonymListView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            SynonymListView(
                synonyms: [
                    SignSynonym(id: "sign_002", word: "здравствуй"),
                    SignSynonym(id: "sign_003", word: "приветствие")
                ],
                currentSignId: "sign_001",
                visitedSignIds: [],
                onSynonymTap: { id in
                    print("Tapped synonym: \(id)")
                }
            )
            .padding()
        }
    }
}
#endif
