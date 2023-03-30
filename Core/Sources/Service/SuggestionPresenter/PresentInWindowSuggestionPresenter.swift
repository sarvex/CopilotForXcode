import ChatService
import CopilotModel
import Foundation
import OpenAIService
import SuggestionWidget

struct PresentInWindowSuggestionPresenter {
    func presentSuggestion(
        _ suggestion: CopilotCompletion,
        lines: [String],
        language: String,
        fileURL: URL,
        currentSuggestionIndex: Int,
        suggestionCount: Int
    ) {
        Task { @MainActor in
            let controller = GraphicalUserInterfaceController.shared.suggestionWidget
            controller.suggestCode(
                suggestion.text,
                language: language,
                startLineIndex: suggestion.position.line,
                fileURL: fileURL,
                currentSuggestionIndex: currentSuggestionIndex,
                suggestionCount: suggestionCount
            )
        }
    }

    func discardSuggestion(fileURL: URL) {
        Task { @MainActor in
            let controller = GraphicalUserInterfaceController.shared.suggestionWidget
            controller.discardSuggestion(fileURL: fileURL)
        }
    }

    func markAsProcessing(_ isProcessing: Bool) {
        Task { @MainActor in
            let controller = GraphicalUserInterfaceController.shared.suggestionWidget
            controller.markAsProcessing(isProcessing)
        }
    }

    func presentError(_ error: Error) {
        if error is CancellationError { return }
        Task { @MainActor in
            let controller = GraphicalUserInterfaceController.shared.suggestionWidget
            controller.presentError(error.localizedDescription)
        }
    }

    func presentErrorMessage(_ message: String) {
        Task { @MainActor in
            let controller = GraphicalUserInterfaceController.shared.suggestionWidget
            controller.presentError(message)
        }
    }

    func closeChatRoom(fileURL: URL) {
        Task { @MainActor in
            let controller = GraphicalUserInterfaceController.shared.suggestionWidget
            controller.closeChatRoom(fileURL: fileURL)
        }
    }

    func presentChatGPTConversation(_ service: ChatGPTService, fileURL: URL) {
        let chatRoom = ChatRoom()
        let chatService = ChatService(chatGPTService: service)
        let cancellable = service.objectWillChange.sink { [weak chatRoom] in
            guard let chatRoom else { return }
            Task { @MainActor in
                chatRoom.history = (await service.history).map { message in
                    .init(
                        id: message.id,
                        isUser: message.role == .user,
                        text: message.summary ?? message.content
                    )
                }
                chatRoom.isReceivingMessage = await service.isReceivingMessage
            }
        }

        chatRoom.onMessageSend = { [cancellable] message in
            _ = cancellable
            Task {
                do {
                    _ = try await chatService.send(content: message)
                } catch {
                    presentError(error)
                }
            }
        }
        chatRoom.onStop = {
            Task {
                await chatService.stopReceivingMessage()
            }
        }

        chatRoom.onClear = {
            Task {
                await chatService.clearHistory()
            }
        }

        chatRoom.onClose = {
            Task {
                await chatService.stopReceivingMessage()
                closeChatRoom(fileURL: fileURL)
            }
        }

        Task { @MainActor in
            let controller = GraphicalUserInterfaceController.shared.suggestionWidget
            controller.presentChatRoom(chatRoom, fileURL: fileURL)
        }
    }
}
