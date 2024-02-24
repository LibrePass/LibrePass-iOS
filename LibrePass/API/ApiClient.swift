import Foundation

class ApiClient {
    var accessToken: String?
    var apiUrl: String
    
    init(apiUrl: String) {
        self.apiUrl = apiUrl
    }
    
    func request(path: String, body: Data?, method: String) throws -> Data {
        let url = URL(string: self.apiUrl + path)!
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let accessToken = self.accessToken {
            request.setValue("Bearer " + accessToken, forHTTPHeaderField: "Authorization")
        }
        
        request.httpMethod = method
        if let body = body {
            request.httpBody = body
        }
        
        var responseBody = Data()
        var errorToReturn: Error?
        let group = DispatchGroup()
        let task = URLSession.shared.dataTask(with: request) {(data, response, error) -> Void in
            defer {group.leave()}
            
            if let error = error {
                errorToReturn = error
            } else if let response = response as? HTTPURLResponse {
                if response.statusCode == 200 {
                    responseBody = data ?? Data()
                } else if response.statusCode < 200 || response.statusCode >= 300 {
                    errorToReturn = ApiClientErrors.StatusCodeNot200(statusCode: response.statusCode)
                }
            } else {
                errorToReturn = ApiClientErrors.UnknownResponse
            }
        }
        
        group.enter()
        task.resume()
        group.wait()
        
        if let errorToReturn = errorToReturn {
            throw errorToReturn
        }
        
        return responseBody
    }
}

enum ApiClientErrors: Error {
    case StatusCodeNot200(statusCode: Int)
    case UnknownResponse
}
