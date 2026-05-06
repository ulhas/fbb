import Foundation

enum Endpoint {
    case listWeeks
    case weekDetail(weekStartsOn: String)
    case dayDetail(weekStartsOn: String, scheduledOn: String)

    var path: String {
        switch self {
        case .listWeeks:
            return "/training-weeks"
        case .weekDetail(let weekStartsOn):
            return "/training-weeks/\(weekStartsOn)"
        case .dayDetail(let weekStartsOn, let scheduledOn):
            return "/training-weeks/\(weekStartsOn)/days/\(scheduledOn)"
        }
    }
}
