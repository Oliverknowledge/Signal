import Foundation

public struct MetricEntry: Codable, Hashable {
  let metricType: String
  let metricValue: Int
}

public enum GoalBuilder {
  public static func goalId(trackId: String, outcomeId: String) -> String {
    "\(trackId)_\(outcomeId)"
  }

  public static func goalDescription(months: Int?, trackName: String, focusArea: String? = nil, outcomeLabel: String, metrics: [MetricEntry]) -> String {
    // Role transition framing: goalDescription represents current_role → target_role intent.
    // Build phrases for up to two metrics in priority order: recallAccuracy, conceptRetention, skillDepth, interviewChallenges, consistency
    let priorityOrder = ["recallAccuracy", "conceptRetention", "skillDepth", "interviewChallenges", "consistency"]
    let ordered = priorityOrder.compactMap { type in metrics.first(where: { $0.metricType == type }) }
    var parts: [String] = []
    for m in ordered.prefix(2) {
      switch m.metricType {
      case "recallAccuracy": parts.append("maintaining \(m.metricValue)% recall accuracy")
      case "conceptRetention": parts.append("retaining \(m.metricValue) concepts")
      case "skillDepth": parts.append("building depth in \(m.metricValue) skill areas")
      case "interviewChallenges": parts.append("passing \(m.metricValue) interview-style challenges")
      case "consistency": parts.append("staying consistent at \(m.metricValue) sessions/week")
      default: break
      }
    }
    let metricsText = parts.isEmpty ? "building consistent weekly momentum" : parts.joined(separator: " and ")
    let monthsText: String
    if let m = months, m > 0 {
      monthsText = "In \(m) months,"
    } else {
      monthsText = "Over the coming months,"
    }
    if let focusArea, !focusArea.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      return "\(monthsText) become \(outcomeLabel.lowercased()) in \(trackName), focused on \(focusArea), by \(metricsText)."
    }
    return "\(monthsText) become \(outcomeLabel.lowercased()) in \(trackName) by \(metricsText)."
  }

  public static func weakSeeds(for trackId: String) -> [String] {
    switch trackId {
    case "software_engineering": return ["RAII","memory safety","big O","hash maps","graphs","dynamic programming","system design","concurrency"]
    case "data_ml": return ["train/test split","overfitting","regularization","gradient descent","loss functions","feature scaling","evaluation metrics"]
    case "product_management": return ["user research","prioritization","metrics","roadmapping","experiments","stakeholder management"]
    case "ui_ux_design": return ["visual hierarchy","typography","layout","accessibility","design systems","interaction design"]
    case "finance_investing": return ["risk vs return","diversification","discounting","inflation","index funds","cash flow"]
    case "entrepreneurship": return ["customer discovery","MVP","positioning","pricing","distribution","unit economics"]
    default: return []
    }
  }
}
