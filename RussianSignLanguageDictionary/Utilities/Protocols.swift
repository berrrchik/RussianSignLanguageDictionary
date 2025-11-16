import Foundation
import Combine

// MARK: - Repository Protocol
protocol Repository {
    associatedtype DataType
    associatedtype ErrorType: Error
}

// MARK: - ViewModel Protocol
protocol ViewModel: ObservableObject {
    associatedtype State
    associatedtype Action
    
    var state: State { get }
    func handle(_ action: Action)
}

// MARK: - UseCase Protocol
protocol UseCase {
    associatedtype Request
    associatedtype Response
    associatedtype ErrorType: Error
    
    func execute(_ request: Request) async -> Result<Response, ErrorType>
}

