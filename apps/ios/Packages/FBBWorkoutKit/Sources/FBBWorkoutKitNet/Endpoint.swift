import Foundation

public enum Endpoint {
    case listWeeks
    case weekDetail(weekStartsOn: String)
    case dayDetail(weekStartsOn: String, scheduledOn: String)

    case me
    case meTracks
    case followTrack(code: String)
    case unfollowTrack(code: String)

    case postWorkoutSession
    case listWorkoutSessions
    case workoutSessionDetail(id: String)

    public var path: String {
        switch self {
        case .listWeeks:
            return "/training-weeks"
        case .weekDetail(let weekStartsOn):
            return "/training-weeks/\(weekStartsOn)"
        case .dayDetail(let weekStartsOn, let scheduledOn):
            return "/training-weeks/\(weekStartsOn)/days/\(scheduledOn)"
        case .me:
            return "/me"
        case .meTracks:
            return "/me/tracks"
        case .followTrack(let code), .unfollowTrack(let code):
            return "/me/tracks/\(code)/follow"
        case .postWorkoutSession, .listWorkoutSessions:
            return "/workouts/sessions"
        case .workoutSessionDetail(let id):
            return "/workouts/sessions/\(id)"
        }
    }
}
