import Foundation

typealias CompletionAPIBuilder = (String, URL, CompletionRequestBody) -> CompletionAPI

protocol CompletionAPI {
    func callAsFunction() async throws -> CompletionResponseBody
}

/// https://platform.openai.com/docs/api-reference/chat/create
struct CompletionResponseBody: Codable, Equatable {
    struct Message: Codable, Equatable {
        var role: ChatMessage.Role
        var content: String
    }
    
    struct Choice: Codable, Equatable {
        var message: Message
        var index: Int
        var finish_reason: String
    }
    
    struct Usage: Codable, Equatable {
        var prompt_tokens: Int
        var completion_tokens: Int
        var total_tokens: Int
    }

    var id: String
    var object: String
    var created: Int
    var model: String
    var usage: Usage
    var choices: [Choice]
}

struct CompletionAPIError: Error, Codable, LocalizedError {
    struct E: Codable {
        var message: String
        var type: String
        var param: String
        var code: String
    }
    var error: E
    
    var errorDescription: String? { error.message }
}

struct OpenAICompletionAPI: CompletionAPI {
    var apiKey: String
    var endpoint: URL
    var requestBody: CompletionRequestBody

    init(apiKey: String, endpoint: URL, requestBody: CompletionRequestBody) {
        self.apiKey = apiKey
        self.endpoint = endpoint
        self.requestBody = requestBody
        self.requestBody.stream = false
    }

    func callAsFunction() async throws -> CompletionResponseBody {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(requestBody)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        let (result, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw ChatGPTServiceError.responseInvalid
        }

        guard response.statusCode == 200 else {
            let error = try? JSONDecoder().decode(CompletionAPIError.self, from: result)
            throw error ?? ChatGPTServiceError.responseInvalid
        }
        
        return try JSONDecoder().decode(CompletionResponseBody.self, from: result)
    }
}
