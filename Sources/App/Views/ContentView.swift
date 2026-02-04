import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = TodoListViewModel()
    @State private var newTitle = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                TextField("New todo", text: $newTitle)
                    .textFieldStyle(.roundedBorder)
                Button("Add") {
                    viewModel.addItem(title: newTitle)
                    newTitle = ""
                }
                .keyboardShortcut(.defaultAction)
            }

            List {
                ForEach(viewModel.items) { item in
                    HStack {
                        Button {
                            viewModel.toggleCompletion(for: item)
                        } label: {
                            Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                        }
                        .buttonStyle(.plain)

                        Text(item.title)
                            .strikethrough(item.isCompleted, color: .secondary)
                            .foregroundStyle(item.isCompleted ? .secondary : .primary)
                    }
                    .padding(.vertical, 4)
                }
                .onDelete(perform: viewModel.deleteItems)
            }
            .listStyle(.inset)
        }
        .padding(24)
        .frame(minWidth: 480, minHeight: 360)
    }
}

#Preview {
    ContentView()
}
